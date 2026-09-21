---
name: add-secret
description: Triggers when the user says "add a secret", "add a sops secret", "edit a secret", "rotate a secret", "new secret", "encrypt a secret", or "change a password hash". Adds, edits, or rotates a sops-nix-managed secret in this repo and reminds the user to wire it up and rebuild.
version: 0.3.0
---

# Add / Edit a sops Secret

This repo manages secrets with **sops-nix** (adopted 2026-06-15). Secrets are committed
**encrypted**; plaintext must never land in the repo or the Nix store. This skill handles
the everyday operations: add a new secret, edit/rotate an existing one, or create a new
per-host secret file.

## Arguments

Invocation inputs (gather any the user didn't already give in Step 1):

- **Secret key name** — the short kebab/snake key (e.g. `restic-password`, `bosko-hashedPassword`).
- **Scope / target file** — `secrets/common.yaml` (all hosts), `secrets/hosts/<host>.yaml`
  (one host), or a new file (new grouping).
- **Operation** — new key, or edit/rotate an existing one. The plaintext value itself is
  never gathered as a chat input — see Step 1.

## Repo layout (read this first)

- **`.sops.yaml`** — recipient map. `keys:` lists age public keys (admin + one per host,
  each derived from that host's SSH ed25519 host key). `creation_rules:` say which
  recipients each file is encrypted to, matched by `path_regex`.
- **`secrets/common.yaml`** — shared secrets, encrypted to **admin + all hosts**. The key
  list changes over time (already has entries beyond the original three) — always check
  the file live (`grep -o '^[a-zA-Z0-9_-]*:' secrets/common.yaml`) rather than trusting an
  inline enumeration here, same as the per-host guidance below.
- **`secrets/desktop.yaml`** — secrets only the desktop hosts need (currently the bosko-owned
  Claude tooling secrets), encrypted to **admin + gaming, laptop, natalie-laptop** but NOT
  vpn-server. Declare these in a desktop-only module (`modules/claude-mcp.nix` is the
  example) — declaring one in a `commonModules` file would make vpn-server try to decrypt a
  file it can't read and fail activation.
- **`secrets/hosts/<host>.yaml`** — per-host secrets, encrypted to **admin + that host
  only**. Every host holds `wg-private-key` (its WireGuard key); `gaming.yaml` additionally
  holds `pinchflat-env`. Don't assume "each holds exactly one key" — check the file live
  (`grep -o '^[a-zA-Z0-9_-]*:' secrets/hosts/<host>.yaml`) rather than trusting this list, it
  will keep growing per-host over time.
- **Admin key**: `~/.config/sops/age/keys.txt` (NOT in repo). Required for all edits.
  Export it for every sops command: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`.
- Tooling isn't installed system-wide — run sops via `nix shell nixpkgs#sops --command …`.

## Step 1 — Gather what's needed

Ask, in one message:

1. **What is the secret?** A short key name (kebab or snake, e.g. `tailscale-authkey`,
   `restic-password`). For a password hash, expect a `$6$…`/`$y$…` string.
2. **Scope** — who needs to decrypt it? Present this as a pick-one via the
   **AskUserQuestion tool** (skip if the user already specified scope):
   - **All hosts** → `secrets/common.yaml`.
   - **One specific host** → `secrets/hosts/<host>.yaml`.
   - **A new grouping** → a new file; you'll add a `creation_rule` for it (Step 2).
3. **New or existing?** Adding a key, or changing an existing one. Present this as a
   pick-one (new key / edit existing) via the **AskUserQuestion tool** if unclear.

**Do not ask the user to state the plaintext value in chat.** A value typed into a normal
message persists in the session transcript indefinitely — exactly what this skill exists to
avoid. The key name and scope are all that's needed here; the actual value is captured later
(Step 3) into a scratchpad file the user writes from a **separate terminal** with a hidden
prompt — never through a `!` command (see Step 3: `!` commands are echoed into the session).

If the user is generating a **password hash**, the canonical way is
`mkpasswd -m sha-512` (`nix shell nixpkgs#mkpasswd --command mkpasswd -m sha-512`).

## Step 2 — Make sure `.sops.yaml` covers the target file

- Editing `secrets/common.yaml` or an existing `secrets/hosts/<host>.yaml` → already
  covered, skip ahead.
- Targeting a **new file** → add a `creation_rule` with a `path_regex` matching it and the
  intended recipients (always include `*admin`). If it's per-host, include that host's
  anchor. If the host has no anchor yet, derive it first:
  ```bash
  /home/bosko/NixOS/.claude/skills/add-secret/scripts/host-age-key.sh <host>
  ```
  Add it under `keys:` as `- &<host> age1...`, then reference it in the rule.

## Step 3 — Write the secret

**The agent must never run `sops-secret.sh set|create|edit` itself.** All three modes touch
the plaintext value (or, for `edit`, need a real interactive terminal the agent's Bash tool
doesn't have) — always construct the exact command below and have the **user** run it
themselves.

**A `!` command is NOT private.** Its text is echoed into the conversation — into the model's
context and the local session log — so a value inside a `!` command (a heredoc body, a
`<<< 'value'`, an inline argument) is exposed exactly like a chat message. Confirmed
2026-09-21: a `!`-captured Tailscale OAuth secret appeared verbatim in the transcript and had
to be regenerated. Never give the user a `!` command that contains the value. Only commands
that pass a **file path** (the write step below) are safe to run via `!`.

**First, have the user capture the value into a scratchpad file from a SEPARATE terminal**
(a normal terminal window, not this session), using a hidden prompt so the value is neither
echoed on screen nor saved to shell history. In zsh:

```
umask 077
read -rs "V?Secret value: "; echo
printf '%s\n' "$V" > <scratchpad>/secret_value; unset V
```

For a multi-line/KEY=VALUE secret, prompt for each part and `printf` them into the file the
same way (no heredoc containing values). `<scratchpad>` is this session's scratchpad
directory — see the system prompt's "Scratchpad Directory" note.

**Then hand the user the matching write command — this one is safe via `!`, since it only
references the file path:**

Add or update a single key in an existing file:

```
! .claude/skills/add-secret/scripts/sops-secret.sh set /home/bosko/NixOS/secrets/common.yaml new-key-name <scratchpad>/secret_value
```

Create a brand-new file:

```
! .claude/skills/add-secret/scripts/sops-secret.sh create /home/bosko/NixOS/secrets/hosts/<host>.yaml my-key <scratchpad>/secret_value
```

Interactive edit/rotate (opens `$EDITOR`) — run this in a **normal terminal window, not
via `!`**: it needs a real TTY, and the secret you type into the editor is then never
anywhere near the session:

```
.claude/skills/add-secret/scripts/sops-secret.sh edit /home/bosko/NixOS/secrets/common.yaml
```

`sops-secret.sh`'s `set`/`create` modes take the value as a **file path**, not an inline
argument, so the write command itself never contains the plaintext — which is what makes it
safe to run via `!`. That only holds if the value file was written from a separate terminal
(see above); a `!` command that writes the value is itself echoed into the transcript. Wait
for the user to confirm the command ran before moving to Step 5.

## Step 4 — Wire it into NixOS

A secret in the file does nothing until it's declared and referenced. Remind the user (or
do it if they ask):

```nix
# declare it (in sops.nix for shared, or the relevant host module for per-host)
sops.secrets."new-key-name" = {
  sopsFile = ../../../secrets/common.yaml;   # adjust relative path to the file
  # neededForUsers = true;                    # only for user password hashes
  # owner = "someservice"; mode = "0400";     # if a service must read it
};

# reference it by its runtime path
services.foo.passwordFile = config.sops.secrets."new-key-name".path;
```

`config.sops.secrets."<name>".path` resolves to `/run/secrets/<name>`
(or `/run/secrets-for-users/<name>` when `neededForUsers = true`).

## Step 5 — Verify

The agent runs this directly — it's safe, since it only ever prints a masked comparison or
an OK/FAILED status, never plaintext.

**General file health** (always run this after any write):

```bash
/home/bosko/NixOS/.claude/skills/add-secret/scripts/verify-secret.sh secrets/<file>.yaml [host]
```

Confirms the file decrypts and the values are encrypted on disk (`ENC[`) — never prints
decrypted content.

**Confirm a specific key round-tripped correctly** (after a `set`/`create`, while the
scratchpad value-file from Step 3 still exists):

```bash
/home/bosko/NixOS/.claude/skills/add-secret/scripts/verify-secret.sh secrets/<file>.yaml --key '["new-key-name"]' --expect <scratchpad>/secret_value
```

Prints only a masked match/mismatch (`MATCH — round-trips correctly (ab12...ef90)`), never
the full value. A non-zero exit on either check means investigate before staging anything.

If you changed nix wiring, evaluate before rebuilding:
`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath --raw >/dev/null && echo OK`

## Step 6 — Clean up, stage, and remind to rebuild

Delete the scratchpad plaintext file now that Step 5 has confirmed the encrypted copy is
correct:

```bash
rm -f <scratchpad>/secret_value
```

Then stage:

```bash
git -C /home/bosko/NixOS add .sops.yaml secrets/
```

Tell the user which hosts need a rebuild for the change to take effect (a secret in
`common.yaml` affects all hosts; a per-host file affects just that host). Decryption
happens at **activation**, so a rebuild — not just an eval — is required on each affected
host. Do not commit on the user's behalf unless asked; the `git-commit`/`git-push` skills handle that.

## Scripts

- `.claude/skills/add-secret/scripts/verify-secret.sh <secret-file> [host]` — decrypts the
  file with the admin age key and confirms it's encrypted on disk, printing only OK/FAILED
  (Step 5). With `--key <sops-path> --expect <value-file>` instead, confirms one specific key
  matches an expected value via masked comparison — never prints the full value.
- `.claude/skills/add-secret/scripts/host-age-key.sh <host>` — derives a host's age public
  key from its SSH ed25519 host key, for adding a new anchor to `.sops.yaml` (Step 2).
- `.claude/skills/add-secret/scripts/sops-secret.sh {set|edit|create} <file> [key] [value-file]` —
  the three everyday sops write operations (Step 3), sharing one `SOPS_AGE_KEY_FILE` export
  and `nix shell` wrapping. `set`/`create` take the value as a **file path**, never inline —
  see Step 3 for why. **The agent must never invoke this script itself** — only the user, via
  a `!` command.

## Gotchas

- **The agent must never run `sops-secret.sh set|create|edit`, and must never ask the user to
  type a plaintext value into a normal chat message.** `modules/sops.nix`'s own comment states
  this convention explicitly ("the secret value itself is added by the user directly, never
  by an agent"). The skill's original implementation (pre-v0.3.0) violated it in two places:
  `sops-secret.sh set` took the value as an inline argument the agent would run directly, and
  `verify-secret.sh` printed the *entire* decrypted file (every secret in it, not just the one
  being checked) to the transcript. Both are fixed as of v0.3.0 (2026-09-17, found while
  adding `jellyfin-api-key` to `secrets/hosts/gaming.yaml`). If a future edit reintroduces an
  inline-value code path or a full-plaintext print, that's a regression, not a simplification.
- **Multi-line and special-character values need real encoding.** Before 2026-09-21,
  `sops-secret.sh create` printf'd the value into a double-quoted YAML scalar (YAML folds a raw
  newline into a space, so a two-line env-file secret was stored as one line) and `set` built
  the JSON string by hand (breaks on newlines, `"` and `\`). Both now encode via `jq` and pass
  the value by file (`--rawfile` / `sops set --value-file`), never argv. Found because
  `verify-secret.sh --key ... --expect` reported MISMATCH for `tailscale-mcp-env`; always run
  that masked round-trip check after a write.
- **`!` commands are echoed into the transcript — never put a value in one.** The v0.3.0 flow
  told the user to capture the value with `! cat > file <<< 'VALUE'`, on the belief that `!`
  commands aren't persisted. They are: the command text (heredoc body included) lands in the
  conversation. Found 2026-09-21 rotating `tailscale-mcp-env`, when the new OAuth client secret
  showed up verbatim and had to be regenerated. Value capture now happens in a separate
  terminal with a hidden `read -rs` prompt (Step 3); only file-path-only commands go via `!`.
- **Never `git add` a plaintext secret.** Encrypt in place first; verify with the `ENC[`
  check above before staging.
- A secret added to `common.yaml` is decryptable by **every** host. For least privilege,
  put host-specific secrets in `secrets/hosts/<host>.yaml` instead.
- Adding a recipient to `.sops.yaml` does **not** retroactively re-encrypt existing files —
  run `sops updatekeys <file>` to apply new recipients.
- Editing on a machine without the admin key at `~/.config/sops/age/keys.txt` will fail to
  decrypt. That key is the recovery path — keep it backed up.
- **`openssl` isn't on PATH either** (found generating a random `SECRET_KEY_BASE` for
  Pinchflat, 2026-08-03: `openssl rand -hex 64` → `command not found`). For a random
  token/hex value, use `nix shell nixpkgs#openssl --command openssl rand -hex <N>` — same
  `nix shell nixpkgs#<pkg> --command` pattern as the `mkpasswd` guidance in Step 1.
