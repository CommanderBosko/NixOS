#!/usr/bin/env bash
# Tests hermes-memory-check.py. The default run is offline: a credential detector check,
# the credential guard, redaction of forwarded context, and the claude-failure diagnostics,
# all against a stub `claude` on PATH, so the real checker is never called.
# HERMES_MEMORY_CHECK_LIVE=1 also runs the live cases, which call the real Claude checker
# (about $0.01 each). Scratch HERMES_HOME, so the live log and memory are untouched.
# Usage: [HERMES_MEMORY_CHECK_LIVE=1] hermes-memory-check.test.sh [MCP_NIXOS_BIN]
set -u
here=$(cd "$(dirname "$0")" && pwd)
HERMES_HOME=$(mktemp -d); export HERMES_HOME
stub=$(mktemp -d)
trap 'rm -rf "$HERMES_HOME" "$stub"' EXIT
fail=0

expect() { # expect <label> <want> <got>
  if [[ "|$2|" == *"|$3|"* ]]; then echo "ok    $3  $1" | cut -c1-150
  else echo "FAIL  got=$3 want=$2  $1" | cut -c1-150; fail=1; fi
}
ok() { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }

# Stub claude: records each call and the prompt on stdin. Default answer is an error
# result with no structured_output (the failure seen on 2026-10-18). With a stub-fallback
# marker it answers with the verdicts inside `result`, which the hook must parse.
cat >"$stub/claude" <<'EOF'
#!/usr/bin/env bash
echo called >>"$HERMES_HOME/stub-calls"
cat >"$HERMES_HOME/stub-prompt"
if [[ -e $HERMES_HOME/stub-fallback ]]; then
  echo '{"type":"result","subtype":"success","is_error":false,"result":"```json\n{\"verdicts\":[{\"index\":0,\"verdict\":\"reject\",\"reason\":\"stub reject\"}]}\n```"}'
  exit 0
fi
echo '{"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":8,"result":""}'
echo "stub: no structured output" >&2
exit 1
EOF
chmod +x "$stub/claude"

# Offline hook run: the stub comes first on PATH. Prints the hook's stdout.
hook() { hook_as memory "$1"; }
hook_as() { # hook_as <tool_name> <tool_input JSON>
  printf '{"hook_event_name":"pre_tool_call","tool_name":"%s","session_id":"test","tool_input":%s}' "$1" "$2" |
    PATH="$stub:$PATH" python3 "$here/hermes-memory-check.py"
}
action() { python3 -c 'import sys,json; s=sys.stdin.read().strip(); print(json.loads(s)["action"] if s else "allow")'; }

echo "== detector (in-process, no claude)"
if python3 - "$here/hermes-memory-check.py" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("hmc", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
# fake credentials are split so the repo's own secret-scan doesn't flag this file
secret = [
    ("app_password", "Gmail app password is abcd efgh ijkl mnop."),
    ("app_password", "app password abcdefghijklmnop"),
    ("keyword_secret", "password: hunter2"),
    ("keyword_secret", "GITHUB_TOKEN=xq8Lm2Zr9Pw4"),
    ("api_key", "gh token " + "gh" + "p_aB3dE5fG7hJ9kL1mN2pQ4rS6tU8vW0xY2zA4 works"),
    ("api_key", "AK" + "IAIOSFODNN7EXAMPLE"),
    ("api_key", "key AIzaSyD4fG7hJ9kL1mN2pQ4rS6tU8vW0xY2zA"),
    ("private_key", "-----BEGIN OPENSSH " + "PRIVATE KEY-----"),
    ("bearer", "Authorization: Bearer 4f9aK2mQ8xZ1pL7w"),
    ("high_entropy", "seed 9fK2sL7qWx4Zr0Tn8Vb3Mc6Hj1Dg5Psw value"),
]
benign = [
    "mcp__nixos__nix_versions returns version history across all channels; use mcp__nixos__nix with its channel argument.",
    "python3 is 3.14 here but pip is not installed and PEP 668 is enforced; use a venv or uv.",
    "tokenizer: sentencepiece unigram model; bearer authentication is not used here.",
    "store path /nix/store/0r3gq9a1h8k6p2xw5mvd7c4bz0ny8f1s-hello-2.12 is the built package.",
    "commit 3f2a9c1d8e7b6a5f4e3d2c1b0a9f8e7d6c5b4a39 fixed the hook.",
]
bad = 0
for want, text in secret:
    kinds, _ = m.scan(text)
    if want not in kinds: print(f"FAIL  {want} not found in {text[:50]!r} (got {kinds})"); bad = 1
    else: print(f"ok    {want}  {text[:60]}")
for text in benign:
    kinds, _ = m.scan(text)
    if kinds: print(f"FAIL  benign flagged {kinds}: {text[:60]}"); bad = 1
    else: print(f"ok    benign  {text[:60]}")
kinds, red = m.scan("forwarded: my app password is abcd efgh ijkl mnop, thanks")
if "[REDACTED:app_password]" in red and "abcd" not in red: print("ok    redaction  " + red)
else: print("FAIL  redaction " + red); bad = 1
sys.exit(bad)
PY
then ok "detector cases"; else bad "detector cases"; fi

echo "== syntax"
if python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$here/hermes-memory-check.py"
then ok "py compile"; else bad "py compile"; fi

echo "== credential guard (offline, claude must not run)"
rm -f "$HERMES_HOME/stub-calls"
expect "app password, spaced groups" block "$(hook '{"target":"user","action":"add","content":"Gmail app password is abcd efgh ijkl mnop."}' | action)"
expect "password: hunter2" block "$(hook '{"target":"memory","action":"add","content":"Test box login, password: hunter2"}' | action)"
ghtok="gh""p_aB3dE5fG7hJ9kL1mN2pQ4rS6tU8vW0xY2zA4" # split so secret-scan doesn't flag the fake
expect "fake ghp_ token" block "$(hook '{"target":"memory","action":"add","content":"gh token '"$ghtok"' works for gh."}' | action)"
expect "credential in a batch" block "$(hook '{"target":"memory","operations":[{"action":"add","content":"ok fact about nix channels."},{"action":"add","content":"api_key=xq8Lm2Zr9Pw4Tb1"}]}' | action)"
if [[ ! -e $HERMES_HOME/stub-calls ]]; then ok "no claude call for credential entries"
else bad "claude was called for a credential entry"; fi
grep -q 'abcd efgh\|hunter2\|ghp_aB3' "$HERMES_HOME/logs/memory-checker.jsonl" 2>/dev/null &&
  bad "credential value written to the log" || ok "no credential value in the log"

echo "== benign entry, redaction and diagnostics (offline stub)"
python3 -c '
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("CREATE TABLE messages (id INTEGER PRIMARY KEY, session_id TEXT, role TEXT, content TEXT)")
db.execute("INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)",
           ("test", "user", "my gmail app password is abcd efgh ijkl mnop, please remember it"))
db.commit()' "$HERMES_HOME/state.db"
mkdir -p "$HERMES_HOME/memories"
echo "- token: xq8Lm2Zr9Pw4Tb1 was an old note" >"$HERMES_HOME/memories/MEMORY.md"
benign='{"target":"memory","action":"add","content":"mcp__nixos__nix_versions returns version history across all channels; use mcp__nixos__nix with its channel argument."}'
expect "benign entry reaches the stub, fails open" allow "$(hook "$benign" | action)"
if [[ -e $HERMES_HOME/stub-calls ]]; then ok "benign entry was sent to claude"
else bad "benign entry never reached claude"; fi
if grep -q '\[REDACTED:app_password\]' "$HERMES_HOME/stub-prompt" && ! grep -q 'abcd efgh' "$HERMES_HOME/stub-prompt"; then
  ok "forwarded user message redacted"
else bad "forwarded user message not redacted"; fi
if ! grep -q 'xq8Lm2Zr9Pw4Tb1' "$HERMES_HOME/stub-prompt" && grep -q '\[REDACTED:keyword_secret\]' "$HERMES_HOME/stub-prompt"; then
  ok "current memory contents redacted"
else bad "current memory contents not redacted"; fi
python3 - "$HERMES_HOME/logs/memory-checker.jsonl" <<'PY' && ok "diagnostics logged (exit, stdout, stderr, entry)" || bad "diagnostics missing or leaking"
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1])]
r = [x for x in recs if "exit" in x]
assert len(r) == 1, recs
r = r[0]
assert r["exit"] == 1, r
assert "error_max_turns" in r["stdout"] and "stub: no structured output" in r["stderr"], r
assert r["entries"] and "mcp__nixos__nix_versions" in r["entries"][0], r
text = open(sys.argv[1]).read()
assert "abcd efgh" not in text and "xq8Lm2Zr9Pw4Tb1" not in text, "credential leaked"
PY

echo "== fallback: verdicts inside result are parsed"
touch "$HERMES_HOME/stub-fallback"
expect "verdict from result JSON applied" block "$(hook "$benign" | action)"

echo "== mnemosyne writers (same checks, action-less content)"
rm -f "$HERMES_HOME/stub-calls"
for t in mnemosyne_remember mnemosyne_update mnemosyne_shared_remember; do
  expect "$t verdict applied" block "$(hook_as $t '{"content":"mcp__nixos__nix_versions cannot filter by channel."}' | action)"
done
if [[ -e $HERMES_HOME/stub-calls ]]; then ok "mnemosyne entry was sent to claude"
else bad "mnemosyne entry never reached claude"; fi
rm -f "$HERMES_HOME/stub-fallback" "$HERMES_HOME/stub-calls"
expect "mnemosyne credential blocked locally" block "$(hook_as mnemosyne_remember '{"content":"password: hunter2"}' | action)"
expect "mnemosyne recall is not vetted" allow "$(hook_as mnemosyne_recall '{"content":"password: hunter2"}' | action)"
if [[ ! -e $HERMES_HOME/stub-calls ]]; then ok "no claude call for mnemosyne credential or recall"
else bad "claude was called for a mnemosyne credential or recall"; fi

if [[ ${HERMES_MEMORY_CHECK_LIVE:-0} == 1 ]]; then
  MCP=${1:-}
  live_case() { # live_case <expected outcomes, |-separated> <tool_input JSON>
    local want=$1 input=$2 out got
    out=$(printf '{"hook_event_name":"pre_tool_call","tool_name":"memory","session_id":"test","tool_input":%s}' "$input" |
          python3 "$here/hermes-memory-check.py" "$MCP")
    got=$(printf '%s' "$out" | action)
    expect "$input" "$want" "$got"
  }
  echo "== live checker (real claude)"
  # Junk: premature results, task narration.
  live_case block '{"target":"memory","action":"add","content":"MCP servers tested: mcp-nixos (tested list_prompts), mcp-tailscale (tested list_resources). Results reported below."}'
  live_case block '{"target":"user","action":"add","content":"User asked for ripgrep version in nixos-unstable channel using nixos MCP server."}'
  live_case block '{"target":"memory","action":"add","content":"User wants Tailscale offline devices listed: hostname and last-seen timestamp only. Do not modify any device state."}'
  live_case block '{"target":"user","operations":[{"action":"add","content":"User is testing version differences between nixos-unstable and nixos-26.05 channels for ripgrep."}]}'
  # Wrong detail or speculation: fixing or rejecting are both fine.
  live_case 'modify|block' '{"target":"user","action":"add","content":"MCP servers configured: mcp-nixos and mcp-tailscale."}'
  live_case 'modify|block' '{"target":"memory","action":"add","content":"tailscale MCP tools available: list_devices (online/offline status), tailscale_get_device (detailed info), tailscale_status (API health check)"}'
  live_case 'modify|block' '{"target":"user","action":"add","content":"User uses a NixOS flake config with four hosts: gaming, laptop, natalie-laptop, vpn-server. One of them may be offline."}'
  # Valid durable facts: must pass.
  live_case allow '{"target":"memory","action":"add","content":"mcp__nixos__nix_versions returns version history across all channels and cannot filter by channel; use mcp__nixos__nix with its channel argument for a specific channel."}'
  live_case allow '{"target":"memory","action":"add","content":"python3 is 3.14 here but pip is not installed and PEP 668 is enforced; use a venv or uv for Python packages."}'
  # Removal never calls the checker; a mixed batch drops only the junk.
  live_case allow '{"target":"memory","action":"remove","old_text":"anything"}'
  live_case modify '{"target":"memory","operations":[{"action":"add","content":"User asked to list offline tailnet devices just now."},{"action":"add","content":"mcp__nixos__nix_versions cannot filter by channel; use mcp__nixos__nix with its channel argument instead."}]}'
fi

[ -s "$HERMES_HOME/logs/memory-checker.jsonl" ] && echo "--- verdicts:" && python3 -c '
import json, sys
for line in open(sys.argv[1]):
    r = json.loads(line)
    print(str(r.get("verdict") or "ERROR").ljust(7), (r.get("reason") or r.get("error") or "exit=%s" % r.get("exit"))[:110])' "$HERMES_HOME/logs/memory-checker.jsonl"
if [ "$fail" = 0 ]; then echo "RESULT: all offline checks passed"; else echo "RESULT: failures above"; fi
exit $fail
