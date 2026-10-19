#!/usr/bin/env bash
# Deep-evaluate unwired desktop-environment modules via lib.deSmoke.
# A thin wrapper over .claude/lib/deep-eval.sh --set lib.deSmoke, the same
# command CI's weekly de-smoke job runs. With no argument, lists the available
# lib.deSmoke member names (deep-eval.sh --list) instead of evaluating.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SKILL_DIR/../../.." && pwd)"

ARGS=(--set lib.deSmoke)
[ $# -eq 0 ] && ARGS+=(--list)

exec bash "$REPO/.claude/lib/deep-eval.sh" "${ARGS[@]}" "$@"
