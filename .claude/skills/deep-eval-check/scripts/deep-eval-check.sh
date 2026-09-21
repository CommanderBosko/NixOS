#!/usr/bin/env bash
# Deep-evaluate every flake host's build graph (not just a shallow "is it a
# derivation" check). Thin wrapper over the shared .claude/lib/deep-eval.sh —
# the same script CI runs — which reads the host list live from the flake's
# nixosConfigurations (never hosts.json or a hardcoded copy), keeps going past
# a failing host, prints a per-host verdict, and exits non-zero if any failed.
# Extra args (host names, --list, --flake, --set) pass straight through.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../lib" && pwd)/deep-eval.sh" "$@"
