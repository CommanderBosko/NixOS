---
name: add-package
description: Triggers when user says "add a package", "install a package", "add X to my system", "add X to gaming/laptop/server", "add package", or "install X". Interactively adds a package to the correct location in the repo — either a host's system packages or a user's Home Manager packages — then reminds the user to dry-run and commit.
version: 0.1.0
---

# Add Package Workflow

Add a package to the correct location in this NixOS repo. Follow every step in order. Do not make any edits until Step 4.

## Step 1 — Gather information

Ask the user the following questions. You may batch them into a single message. Do not proceed to Step 2 until you have answers to all three.

**Required:**

1. **Package name** — The `pkgs.*` attribute name (e.g. `ripgrep`, `kdePackages.kcalc`). If the user gave a plain English name, confirm the nixpkgs attribute before proceeding — you can reason from your knowledge of nixpkgs or ask the user to verify with `nix search nixpkgs <name>`.

2. **Which host(s)** — One or more of: `gaming`, `laptop`, `natalie-laptop`, `server`, `vpn-server`, or `all` (meaning every host). If the user said "my system" or gave no host, assume their current machine context if obvious; otherwise ask.

3. **System-level or user-level** — One of:
   - **System** — goes in `environment.systemPackages` in the host's `environment.nix`. Available to all users on that host.
   - **User (bosko)** — goes in `users.users.bosko.packages` in `dotfiles/common/modules/users.nix`. Personal package for bosko only, applies on all hosts.
   - **Home Manager (shared)** — goes in `home.packages` in `dotfiles/common/configs/home.nix`. Managed by HM; applies to both `bosko` and `natty` on all desktop hosts.

   Note: `server` and `vpn-server` do not run Home Manager — only the **system** option applies to those hosts.

## Step 2 — Determine the correct file and list

Based on the answers from Step 1, resolve the exact file path and the list to modify:

| Destination | File |
|---|---|
| System packages — gaming | `hosts/gaming/environment.nix` → `environment.systemPackages` |
| System packages — laptop | `hosts/laptop/environment.nix` → `environment.systemPackages` |
| System packages — natalie-laptop | `hosts/natalie-laptop/environment.nix` → `environment.systemPackages` |
| System packages — server | `hosts/server/environment.nix` → `environment.systemPackages` |
| System packages — vpn-server | `hosts/vpn-server/configuration.nix` → `environment.systemPackages` |
| User packages — bosko | `dotfiles/common/modules/users.nix` → `users.users.bosko.packages` |
| HM packages — shared | `dotfiles/common/configs/home.nix` → `home.packages` |

If the user said "all hosts", the package must be added to each host's `environment.nix` (and `vpn-server/configuration.nix`) individually. Consider whether a shared location would be more appropriate and mention it.

All paths above are relative to `/home/bosko/NixOS`.

## Step 3 — Show the current list and proposed addition

Read the target file(s). Show the user:

1. The current `with pkgs;` list (just the list, not the entire file).
2. The same list with the new package inserted in **alphabetical order**.

State clearly where the package will be inserted. Do not write anything yet — wait for the user to confirm.

If the `home.nix` file does not yet have a `home.packages` block, show the block that will be added.

## Step 4 — Make the edit

After the user confirms, use the Edit tool to insert the package in the correct location. Follow these rules precisely:

- Packages within a `with pkgs;` list must be kept in **alphabetical order**. Insert the new entry in the correct sorted position.
- Packages with namespace prefixes sort on the full string (e.g. `kdePackages.kate` sorts as `k`; compare the full attribute path character-by-character).
- Use **2-space indentation** matching the surrounding code.
- Do not remove or reorder any existing packages.
- Do not add comments unless the existing list uses inline comments consistently.
- Do not change anything else in the file.

If adding to multiple hosts, edit each file in sequence, confirming each looks correct before moving to the next.

## Step 5 — Remind the user to test and commit

After all edits are made, output exactly this reminder (substituting the real host name(s) if known):

```
Changes written. Next steps:

1. Dry-run to check for evaluation errors:
   /nixos-dry-run

2. If the dry-run looks good, commit:
   /commit
```

Do not rebuild. Do not stage files. Leave both of those to the user's own workflow.

---

## Key constraints

- Never use `git add` — leave staging entirely to the `/commit` skill.
- Never run `nh os boot` or `nixos-rebuild` — leave that to the user.
- `server` and `vpn-server` are headless; never suggest HM or user packages for them.
- The `vpn-server` host uses `aarch64-linux` — only offer packages that are likely available for that architecture.
- `natty` has no wheel access and no personal user packages — the only shared user destination for `natty` is the HM shared list (`home.nix`).
- If the package name is ambiguous (e.g. `discord` vs `vesktop`), note the distinction briefly.
- If the package may require `nixpkgs.config.allowUnfree = true` (already enabled globally in this repo via `nix.nix`), no action is needed — just proceed.
