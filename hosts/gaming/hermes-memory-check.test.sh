#!/usr/bin/env bash
# Runs real memory saves Hermes made (junk and valid) through hermes-memory-check.py
# and checks each outcome. It calls the Claude checker (about $0.01 per case) and uses a
# scratch HERMES_HOME, so the live log and memory are untouched.
# Usage: hermes-memory-check.test.sh [MCP_NIXOS_BIN]
set -u
here=$(cd "$(dirname "$0")" && pwd)
HERMES_HOME=$(mktemp -d); export HERMES_HOME; trap 'rm -rf "$HERMES_HOME"' EXIT
fail=0

# case <expected outcomes, |-separated: allow|modify|block> <tool_input JSON>
case_() {
  local want=$1 input=$2 out got
  out=$(printf '{"hook_event_name":"pre_tool_call","tool_name":"memory","session_id":"test","tool_input":%s}' "$input" |
        python3 "$here/hermes-memory-check.py" "${MCP:-}")
  got=$(printf '%s' "$out" | python3 -c 'import sys,json; s=sys.stdin.read().strip(); print(json.loads(s)["action"] if s else "allow")')
  if [[ "|$want|" == *"|$got|"* ]]; then echo "ok    $got  $input" | cut -c1-150
  else echo "FAIL  got=$got want=$want  $input" | cut -c1-150; fail=1; fi
}
MCP=${1:-}

# Junk: premature results, task narration.
case_ block '{"target":"memory","action":"add","content":"MCP servers tested: mcp-nixos (tested list_prompts), mcp-tailscale (tested list_resources). Results reported below."}'
case_ block '{"target":"user","action":"add","content":"User asked for ripgrep version in nixos-unstable channel using nixos MCP server."}'
case_ block '{"target":"memory","action":"add","content":"User wants Tailscale offline devices listed: hostname and last-seen timestamp only. Do not modify any device state."}'
case_ block '{"target":"user","operations":[{"action":"add","content":"User is testing version differences between nixos-unstable and nixos-26.05 channels for ripgrep."}]}'
# Wrong detail or speculation: fixing or rejecting are both fine.
case_ 'modify|block' '{"target":"user","action":"add","content":"MCP servers configured: mcp-nixos and mcp-tailscale."}'
case_ 'modify|block' '{"target":"memory","action":"add","content":"tailscale MCP tools available: list_devices (online/offline status), tailscale_get_device (detailed info), tailscale_status (API health check)"}'
case_ 'modify|block' '{"target":"user","action":"add","content":"User uses a NixOS flake config with four hosts: gaming, laptop, natalie-laptop, vpn-server. One of them may be offline."}'
# Valid durable facts: must pass.
case_ allow '{"target":"memory","action":"add","content":"mcp__nixos__nix_versions returns version history across all channels and cannot filter by channel; use mcp__nixos__nix with its channel argument for a specific channel."}'
case_ allow '{"target":"memory","action":"add","content":"python3 is 3.14 here but pip is not installed and PEP 668 is enforced; use a venv or uv for Python packages."}'
# Removal never calls the checker; a mixed batch drops only the junk.
case_ allow '{"target":"memory","action":"remove","old_text":"anything"}'
case_ modify '{"target":"memory","operations":[{"action":"add","content":"User asked to list offline tailnet devices just now."},{"action":"add","content":"mcp__nixos__nix_versions cannot filter by channel; use mcp__nixos__nix with its channel argument instead."}]}'

[ -s "$HERMES_HOME/logs/memory-checker.jsonl" ] && echo "--- verdicts:" && python3 -c '
import json, sys
for line in open(sys.argv[1]):
    r = json.loads(line)
    print(r.get("verdict", "ERROR").ljust(7), (r.get("reason") or r.get("error", ""))[:110])' "$HERMES_HOME/logs/memory-checker.jsonl"
exit $fail
