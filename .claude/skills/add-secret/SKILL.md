---
name: add-secret
description: Triggers when the user says "add a secret", "add a sops secret", "edit a secret", "rotate a secret", "new secret", "encrypt a secret", or "change a password hash". Adds, edits, or rotates a sops-nix-managed secret in this repo and reminds the user to wire it up and rebuild.
version: 0.2.0
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
- **Value & operation** — the plaintext value, or "edit"/"rotate" an existing key.

## Repo layout (read this first)

- **`.sops.yaml`** — recipient map. `keys:` lists age public keys (admin + one per host,
  each derived from that host's SSH ed25519 host key). `creation_rules:` say which
  recipients each file is encrypted to, matched by `path_regex`.
- **`secrets/common.yaml`** — shared secrets, encrypted to **admin + all hosts**.
  Currently: `bosko-hashedPassword`, `natty-hashedPassword`.
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
3. **Value** — the plaintext value, or "edit the existing one" / "rotate it".
4. **New or existing?** Adding a key, or changing an existing one. Present this as a
   pick-one (new key / edit existing) via the **AskUserQuestion tool** if unclear.

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

All three modes below share the same `SOPS_AGE_KEY_FILE` export and `nix shell` wrapping —
run via `sops-secret.sh` (repo-root-relative — a bare `scripts/...` path 404s from the actual
Bash-tool cwd) rather than typing sops/nix-shell invocations by hand:

**Add or update a single key in an existing file** (no plaintext touches disk):

```bash
.claude/skills/add-secret/scripts/sops-secret.sh set /home/bosko/NixOS/secrets/common.yaml new-key-name "the-secret-value"
```

sops decrypts in memory, sets the key, re-encrypts in place.

**Interactive edit / rotate** (let the user change it in `$EDITOR`):

```bash
.claude/skills/add-secret/scripts/sops-secret.sh edit /home/bosko/NixOS/secrets/common.yaml
```

**Create a brand-new file** — writes the plaintext YAML under `umask 077`, then encrypts in
place:

```bash
.claude/skills/add-secret/scripts/sops-secret.sh create /home/bosko/NixOS/secrets/hosts/<host>.yaml my-key "the-value"
```

When a secret value is sensitive and must not appear in the transcript (e.g. a key read
over SSH), capture it into a temp file with `umask 077` and feed it from there rather than
echoing it — `sops-secret.sh` takes the value as an argument, so pull from that temp file
rather than pasting the value into the command yourself.

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

Run the verify script — it exports the admin age key, confirms the file decrypts, and
confirms the values are encrypted on disk (`ENC[`):

```bash
/home/bosko/NixOS/.claude/skills/add-secret/scripts/verify-secret.sh secrets/<file>.yaml [host]
```

A non-zero exit means the file failed to decrypt or is not encrypted — investigate before
staging anything.

If you changed nix wiring, evaluate before rebuilding:
`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath --raw >/dev/null && echo OK`

## Step 6 — Stage and remind to rebuild

```bash
git -C /home/bosko/NixOS add .sops.yaml secrets/
```

Then tell the user which hosts need a rebuild for the change to take effect (a secret in
`common.yaml` affects all hosts; a per-host file affects just that host). Decryption
happens at **activation**, so a rebuild — not just an eval — is required on each affected
host. Do not commit on the user's behalf unless asked; the `git-commit`/`git-push` skills handle that.

## Scripts

- `.claude/skills/add-secret/scripts/verify-secret.sh <secret-file> [host]` — decrypts the
  file with the admin age key and confirms it's encrypted on disk (Step 5).
- `.claude/skills/add-secret/scripts/host-age-key.sh <host>` — derives a host's age public
  key from its SSH ed25519 host key, for adding a new anchor to `.sops.yaml` (Step 2).
- `.claude/skills/add-secret/scripts/sops-secret.sh {set|edit|create} <file> [key] [value]` —
  the three everyday sops write operations (Step 3), sharing one `SOPS_AGE_KEY_FILE` export
  and `nix shell` wrapping instead of three separately-typed command blocks.

## Gotchas

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
