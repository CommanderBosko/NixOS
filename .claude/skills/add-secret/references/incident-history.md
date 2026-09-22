# Add-Secret — Incident History

Full postmortem detail behind the condensed Gotchas in SKILL.md. Not needed for normal
operation — read only when investigating a regression that looks similar to one of these.

- **Inline-plaintext-argument / full-plaintext-print bug (pre-v0.3.0).** `modules/sops.nix`'s
  own comment states the convention explicitly ("the secret value itself is added by the user
  directly, never by an agent"). The skill's original implementation violated it in two
  places: `sops-secret.sh set` took the value as an inline argument the agent would run
  directly, and `verify-secret.sh` printed the *entire* decrypted file (every secret in it,
  not just the one being checked) to the transcript. Both were fixed as of v0.3.0
  (2026-09-17, found while adding `jellyfin-api-key` to `secrets/hosts/gaming.yaml`). If a
  future edit reintroduces an inline-value code path or a full-plaintext print, that's a
  regression, not a simplification.

- **YAML-folding / hand-built-JSON encoding bug (pre-2026-09-21).** `sops-secret.sh create`
  printf'd the value into a double-quoted YAML scalar (YAML folds a raw newline into a space,
  so a two-line env-file secret was stored as one line) and `set` built the JSON string by
  hand (breaks on newlines, `"` and `\`). Both now encode via `jq` and pass the value by file
  (`--rawfile` / `sops set --value-file`), never argv. Found because `verify-secret.sh --key
  ... --expect` reported MISMATCH for `tailscale-mcp-env`; always run that masked round-trip
  check after a write.

- **`!`-command transcript-echo incident (Tailscale OAuth secret, 2026-09-21).** The v0.3.0
  flow told the user to capture the value with `! cat > file <<< 'VALUE'`, on the belief that
  `!` commands aren't persisted. They are: the command text (heredoc body included) lands in
  the conversation. Found while rotating `tailscale-mcp-env`, when the new OAuth client
  secret showed up verbatim and had to be regenerated. Value capture now happens in a separate
  terminal with a hidden `read -rs` prompt (Step 3); only file-path-only commands go via `!`.
