"""Hermes pre_tool_call hook: vet memory saves with the hermes-memory-checker agent.

Hook wire (stdin JSON): {tool_name, tool_input, session_id, cwd, ...}. Each add/patch
entry is judged by `claude -p` running the hermes-memory-checker agent prompt (.claude/agents/ in the
NixOS repo): keep, fix or reject. If every entry is rejected, the call is blocked
and the reasons go back to Hermes. If any entry is fixed or dropped, the call is
modified. Any failure lets the save through: this checks memories, it doesn't
limit them. Verdicts go to $HERMES_HOME/logs/memory-checker.jsonl.

Usage: hermes-memory-check [MCP_NIXOS_BIN]
"""
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

REPO = "/home/bosko/NixOS"
AGENT = Path(REPO) / ".claude/agents/hermes-memory-checker.md"
HERMES_HOME = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes")
LOG = HERMES_HOME / "logs" / "memory-checker.jsonl"
CLAUDE = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
TIMEOUT = 100  # under the hook's 120 s, so a slow check fails open instead of being killed
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


def log(**record):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as f:
            f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **record}) + "\n")
    except OSError:
        pass


def candidates(args):
    """Ops in their call form, plus (op index, text field, text) for ops that write text."""
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


def ask_checker(target, user_msg, found, mcp_nixos):
    store = HERMES_HOME / "memories" / ("USER.md" if target == "user" else "MEMORY.md")
    current = store.read_text() if store.exists() else ""
    prompt = json.dumps({
        "target": f"{target} ({'user profile' if target == 'user' else 'agent notes'})",
        "user_latest_message": user_msg or "(unknown)",
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
    return json.loads(out.stdout)["structured_output"]["verdicts"]


def main():
    payload = json.load(sys.stdin)
    args = payload.get("tool_input") or payload.get("args") or {}
    batch, ops, found = candidates(args)
    if not found:
        return
    target = args.get("target", "memory")
    user_msg = last_user_message(payload.get("session_id", ""))
    try:
        verdicts = {v["index"]: v for v in ask_checker(target, user_msg, found,
                                                       sys.argv[1] if len(sys.argv) > 1 else "")}
    except Exception as e:  # fail open: an unchecked save beats a lost one
        log(session=payload.get("session_id"), target=target, error=repr(e)[:300])
        return

    drop, rejected, changed = set(), [], False
    for n, (i, field, text) in enumerate(found):
        v = verdicts.get(n, {"verdict": "keep", "reason": "no verdict returned"})
        log(session=payload.get("session_id"), target=target, entry=text, **v)
        if v["verdict"] == "reject":
            drop.add(i)
            rejected.append(f'"{text[:120]}": {v["reason"]}')
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
