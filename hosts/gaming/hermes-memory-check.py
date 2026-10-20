"""Hermes pre_tool_call hook: vet memory saves (the memory tool and Mnemosyne's writers) with the hermes-memory-checker agent.

Hook wire (stdin JSON): {tool_name, tool_input, session_id, cwd, ...}. Each add/patch
entry is judged by `claude -p` running the hermes-memory-checker agent prompt (.claude/agents/ in the
NixOS repo): keep, fix or reject. If every entry is rejected, the call is blocked
and the reasons go back to Hermes. If any entry is fixed or dropped, the call is
modified. Any failure lets the save through: this checks memories, it doesn't
limit them. Verdicts go to $HERMES_HOME/logs/memory-checker.jsonl.

Credentials never reach claude: an entry that looks like one is rejected locally,
and the forwarded context (user message, current memory) is redacted first.

Usage: hermes-memory-check [MCP_NIXOS_BIN]
"""
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

REPO = "/home/bosko/NixOS"
AGENT = Path(REPO) / ".claude/agents/hermes-memory-checker.md"
HERMES_HOME = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes")
LOG = HERMES_HOME / "logs" / "memory-checker.jsonl"
CLAUDE = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
TIMEOUT = 100  # under the hook's 120 s, so a slow check fails open instead of being killed
SECRET_REASON = "entry looks like it contains a credential; never store secrets in memory"
SCHEMA = {
    "type": "object",
    "required": ["verdicts"],
    "properties": {"verdicts": {"type": "array", "items": {
        "type": "object",
        "required": ["index", "verdict", "reason"],
        "properties": {
            "index": {"type": "integer"},
            "verdict": {"type": "string", "enum": ["keep", "fix", "reject"]},
            "content": {"type": "string"},
            "reason": {"type": "string"},
        },
    }}},
}

# Credential shapes, checked in order. Each match becomes [REDACTED:<type>] in any text.
DETECTORS = [
    ("private_key", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    # Google app password: 16 lowercase letters, optionally as 4 groups of 4.
    ("app_password", re.compile(r"\b(?:[a-z]{4} ){3}[a-z]{4}\b|\b[a-z]{16}\b")),
    ("api_key", re.compile(r"\b(?:sk-[A-Za-z0-9_-]{12,}|gh[po]_\w{20,}|github_pat_\w{20,}"
                           r"|xox[bpas]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[\w-]{20,})\b")),
    # Bearer values must contain a digit, so prose like "Bearer authentication" passes.
    ("bearer", re.compile(r"\bBearer\s+(?=\S*\d)[A-Za-z0-9._~+/=-]{16,}")),
    # "password: x", "API_KEY=x", "access_token = x": keyword, separator, then a value.
    ("keyword_secret", re.compile(r"(?i)\b\w*?(?:password|passwd|pwd|secret|token|api[ _-]?key)"
                                  r"[\"']?\s*[:=]\s*[\"']?\S{6,}")),
]
# Long random-looking runs. Hyphens and slashes end a run, so hyphenated names and paths
# split up; the 32-char hash in a /nix/store path is skipped by the lookbehind.
HIGH_ENTROPY = re.compile(r"(?<!/nix/store/)[A-Za-z0-9+_]{32,}")


def log(**record):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as f:
            f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **record}) + "\n")
    except OSError:
        pass


def _random_looking(s):
    """Mixed letters and digits, with Shannon entropy of at least 4 bits per char.
    Hex (max 4.0 bits) such as git and sha256 hashes falls under the bar."""
    if not (re.search(r"\d", s) and re.search(r"[A-Za-z]", s)):
        return False
    n = len(s)
    return -sum(c / n * math.log2(c / n) for c in Counter(s).values()) >= 4.0


def scan(text):
    """(credential types found, text with each match replaced by [REDACTED:<type>]).
    The types are the only output that describes a match; no value leaves this function."""
    found = []

    def redact(kind):
        def repl(m):
            found.append(kind)
            return f"[REDACTED:{kind}]"
        return repl

    def entropy(m):
        if not _random_looking(m.group()):
            return m.group()
        found.append("high_entropy")
        return "[REDACTED:high_entropy]"

    for kind, pat in DETECTORS:
        text = pat.sub(redact(kind), text)
    text = HIGH_ENTROPY.sub(entropy, text)
    return list(dict.fromkeys(found)), text


# Mnemosyne's free-text writers (matched in hosts/gaming/hermes-agent.nix). Each takes a
# single `content` string and has no `action`, so it is one add.
MNEMOSYNE_WRITERS = {"mnemosyne_remember", "mnemosyne_update", "mnemosyne_shared_remember"}


def candidates(args, tool="memory"):
    """Ops in their call form, plus (op index, text field, text) for ops that write text."""
    if tool in MNEMOSYNE_WRITERS:
        return False, [args], [(0, "content", args["content"])] if args.get("content") else []
    batch = isinstance(args.get("operations"), list)
    ops = args["operations"] if batch else [args]
    found = []
    for i, op in enumerate(ops):
        if isinstance(op, dict) and op.get("action") in ("add", "patch"):
            field = "new_text" if op.get("new_text") else "content"
            if op.get(field):
                found.append((i, field, op[field]))
    return batch, ops, found


def last_user_message(session_id):
    try:
        db = sqlite3.connect(f"file:{HERMES_HOME / 'state.db'}?mode=ro", uri=True, timeout=2)
        row = db.execute("SELECT content FROM messages WHERE session_id=? AND role='user' "
                         "ORDER BY id DESC LIMIT 1", (session_id,)).fetchone()
        return (row[0] or "")[:1500] if row else ""
    except sqlite3.Error:
        return ""


class CheckerError(Exception):
    """claude ran but gave no usable verdicts. Carries its output for the log."""

    def __init__(self, out):
        super().__init__("no usable verdicts")
        self.out = out


def _json_object(text):
    """The text from its first '{' to its last '}' parsed as a dict, or None."""
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        return None
    try:
        obj = json.loads(text[start:end + 1])
    except ValueError:
        return None
    return obj if isinstance(obj, dict) else None


def parse_verdicts(out):
    """{index: verdict} from claude's JSON envelope. Its structured_output is missing when the
    run ended in an error result (is_error, subtype such as error_max_turns) or the model
    replied in prose without the output tool. Then fall back to the JSON inside `result`."""
    envelope = _json_object(out.stdout) or {}
    body = envelope.get("structured_output")
    if not isinstance(body, dict):
        result = envelope.get("result")
        body = _json_object(result) if isinstance(result, str) else None
    try:
        return {v["index"]: v for v in (body or {})["verdicts"]}
    except (KeyError, TypeError) as e:
        raise CheckerError(out) from e


def ask_checker(target, user_msg, found, mcp_nixos):
    store = HERMES_HOME / "memories" / ("USER.md" if target == "user" else "MEMORY.md")
    current = scan(store.read_text())[1] if store.exists() else ""
    prompt = json.dumps({
        "target": f"{target} ({'user profile' if target == 'user' else 'agent notes'})",
        "user_latest_message": scan(user_msg)[1] or "(unknown)",
        "current_contents": current or "(empty)",
        "candidates": [{"index": n, "text": text} for n, (_, _, text) in enumerate(found)],
    }, indent=1)
    # The agent file's body as a system prompt, not --agent: --agent drops --json-schema enforcement.
    body = AGENT.read_text().split("---", 2)[2]
    cmd = [CLAUDE, "-p", "--append-system-prompt", body, "--model", "sonnet",
           "--output-format", "json", "--json-schema", json.dumps(SCHEMA),
           "--add-dir", str(HERMES_HOME), "--allowedTools", "Read Grep Glob mcp__nixos__nix",
           "--settings", '{"disableAllHooks": true}', "--no-session-persistence",
           "--strict-mcp-config", "--disallowedTools", "Bash Write Edit NotebookEdit WebFetch WebSearch Agent"]
    if mcp_nixos:
        cmd += ["--mcp-config", json.dumps({"mcpServers": {"nixos": {"command": mcp_nixos}}})]
    # Prompt on stdin: --mcp-config/--disallowedTools are variadic and would swallow a positional.
    out = subprocess.run(cmd, input=prompt, cwd=REPO, capture_output=True, text=True, timeout=TIMEOUT)
    return parse_verdicts(out)


def main():
    payload = json.load(sys.stdin)
    args = payload.get("tool_input") or payload.get("args") or {}
    batch, ops, found = candidates(args, payload.get("tool_name") or "memory")
    if not found:
        return
    target = args.get("target", "memory")  # Mnemosyne calls have none: judged as agent notes
    session = payload.get("session_id")
    entries = [scan(text)[1] for _, _, text in found]  # redacted, for the log and block message
    kinds = {n: scan(text)[0] for n, (_, _, text) in enumerate(found)}
    if any(kinds.values()):
        # Local reject: the whole write is blocked and claude is never called.
        verdicts = {n: {"verdict": "reject", "reason": SECRET_REASON} for n in kinds}
    else:
        try:
            verdicts = ask_checker(target, last_user_message(session or ""), found,
                                   sys.argv[1] if len(sys.argv) > 1 else "")
        except Exception as e:  # fail open: an unchecked save beats a lost one
            if isinstance(e, CheckerError):
                out = e.out
                diag = {"exit": out.returncode, "stdout": scan(out.stdout)[1][:500],
                        "stderr": scan(out.stderr)[1][:500]}
            else:
                diag = {"error": repr(e)[:300]}
            log(session=session, target=target, entries=[t[:500] for t in entries], **diag)
            return

    drop, rejected, changed = set(), [], False
    for n, (i, field, text) in enumerate(found):
        v = verdicts.get(n, {"verdict": "keep", "reason": "no verdict returned"})
        extra = {"credential": kinds[n]} if kinds[n] else {}
        log(session=session, target=target, entry=entries[n], **v, **extra)
        if v["verdict"] == "reject":
            drop.add(i)
            rejected.append(f'"{entries[n][:120]}": {v["reason"]}')
        elif v["verdict"] == "fix" and v.get("content"):
            ops[i] = {**ops[i], field: v["content"]}
            changed = True

    kept = [op for i, op in enumerate(ops) if i not in drop]
    if not kept:
        print(json.dumps({"action": "block", "message":
                          "Memory not saved: the memory checker rejected it. " + " | ".join(rejected)}))
    elif drop or changed:
        print(json.dumps({"action": "modify", "args": {**args, "operations": kept} if batch else kept[0]}))


if __name__ == "__main__":
    main()
