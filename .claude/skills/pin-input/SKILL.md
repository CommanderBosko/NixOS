---
name: pin-input
description: Triggers when user says "pin input", "pin nixpkgs", "hold back an input", "lock input to a revision", "pin flake input", "freeze input", or "pin X to a commit". Pins a specific flake input to a particular git revision or tag, useful when upstream breaks something and you need to hold back one input while letting others update freely.
version: 0.1.0
---

# Flake Input Pinning Workflow

Pin a single flake input for `/home/bosko/NixOS` to a specific revision, tag, or branch. Always show the user what will be locked before making any change, and explain which pin method they chose and its durability.

## Current inputs in this repo

Never trust a hardcoded roster — it rots. Enumerate the inputs **live**:

```bash
nix flake metadata /home/bosko/NixOS --json | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)['locks']['nodes']['root']['inputs'].keys()))"
```

Some inputs declare `inputs.nixpkgs.follows = "nixpkgs"` (read `flake.nix` to see which — e.g. `home-manager`, `disko`), so pinning `nixpkgs` also moves the nixpkgs revision those inputs see. Always mention this when the user is pinning `nixpkgs`.

---

## Step 1 — Show current state

Read both files to build the display table:

```bash
grep -E '"rev"' /home/bosko/NixOS/flake.lock | head -20
```

Then read `flake.nix` for the current URLs and `flake.lock` for the locked revisions. Present a table like:

```
Input          URL (flake.nix)                                    Locked rev
-----------    ------------------------------------------------   ----------
<input>        <url from flake.nix>                               <rev from flake.lock>
…              (one row per input from the live list enumerated above)
```

To get each input's locked rev from `flake.lock`, read the file and extract the `"rev"` field from each input's node. The nodes for inputs with `follows` may reference another node — follow the reference to find the actual rev.

---

## Step 2 — Ask which input and what to pin it to

Ask:

> Which input would you like to pin? (pick from the live input list enumerated above)
> What would you like to pin it to? Options:
>   - A full commit rev (40-char SHA), e.g. `abc123def456...`
>   - A short rev (Nix will resolve it), e.g. `abc123d`
>   - A branch or tag name, e.g. `nixos-25.05` or `release-24.11`
>   - A full GitHub URL, e.g. `github:nixos/nixpkgs/abc123def456`

If the user already provided both in their prompt (e.g. "pin nixpkgs to abc123"), use those directly and skip asking.

Construct the target URL:
- If the user gave a full GitHub URL, use it as-is.
- If they gave just a rev or branch for a known input, construct the URL from the input's owner/repo: e.g. `nixpkgs` → `github:nixos/nixpkgs/<rev>`.

---

## Step 3 — Ask which pin method

Present the two options clearly:

> **Temporary pin** (lock file only):
> Updates only `flake.lock` to point to the pinned rev. The `flake.nix` URL is unchanged.
> Survives until the next `nix flake update`, which will un-pin it.
>
> **Permanent pin** (edit `flake.nix`):
> Changes the `url =` line in `flake.nix` to include the specific rev or tag.
> Survives `nix flake update` — Nix will refuse to move past the pinned URL.
> To un-pin later, manually restore the original URL in `flake.nix`.

If the user already specified a preference in their prompt, use it and explain which they chose.

---

## Step 4 — Preview before acting

Before making any change, show the user exactly what will happen:

> I will pin **nixpkgs** to `abc123def456...` (github:nixos/nixpkgs/abc123def456).
> Method: **temporary** — only `flake.lock` will be modified; `nix flake update` will un-pin it.
>
> [For nixpkgs] Note: `home-manager` and `disko` both follow `nixpkgs`, so they will also see this pinned revision.
>
> Proceed? (yes/no)

Do not run any command until the user confirms.

---

## Step 5 — Execute the pin

### Temporary pin (lock file only)

```bash
nix flake lock \
  --update-input <name> \
  --override-input <name> <pinned-url> \
  --flake /home/bosko/NixOS
```

Example for nixpkgs pinned to a rev:
```bash
nix flake lock \
  --update-input nixpkgs \
  --override-input nixpkgs github:nixos/nixpkgs/abc123def456 \
  --flake /home/bosko/NixOS
```

### Permanent pin (edit flake.nix + sync lock)

1. Edit the `url =` line for the input in `/home/bosko/NixOS/flake.nix`:

   Before: `nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";`
   After:  `nixpkgs.url = "github:nixos/nixpkgs/abc123def456";`

   For inputs with a comment in `flake.nix`, preserve the comment.

2. Sync the lock file to match:

```bash
nix flake lock \
  --update-input <name> \
  --flake /home/bosko/NixOS
```

---

## Step 6 — Show the diff

After the command completes, display the `flake.lock` diff:

```bash
git -C /home/bosko/NixOS diff flake.lock
```

Present a focused summary:

```
Pinned: nixpkgs
  Old rev: a1b2c3d4...
  New rev: abc123de...  (github:nixos/nixpkgs/abc123def456)
```

If the diff is empty (the input was already at that rev), tell the user:

> nixpkgs was already locked to that revision — flake.lock was not modified.

---

## Step 7 — Remind the user of durability and next steps

Close with a reminder matching the method chosen:

**Temporary pin:**
> This pin lives in `flake.lock` only. Running `nix flake update` (or `/update`) will remove it and re-resolve the latest rev from the original URL.
> To make it permanent, run `/pin-input` again and choose the permanent method.

**Permanent pin:**
> This pin is now in `flake.nix`. Running `nix flake update` will NOT move past it.
> To un-pin later, restore the original URL in `flake.nix` (`github:nixos/nixpkgs/nixos-unstable`) and run `nix flake lock --update-input nixpkgs --flake /home/bosko/NixOS`.

Then suggest:

> When you are ready:
> - Run `/nixos-dry-run` to preview what this pinned revision would change in your system build.
> - Run `/commit` to commit the updated `flake.lock` (and `flake.nix` if permanently pinned).

Do not run either of those automatically.

---

## Key constraints

- Always use `--flake /home/bosko/NixOS` — do not rely on cwd.
- Never modify `flake.nix` for a temporary pin — only `flake.lock` changes.
- Never make any change without the user's explicit confirmation in Step 4.
- Do not auto-commit or auto-rebuild — suggest it, do not invoke it.
- If the `nix flake lock` command fails (bad rev, network error, evaluation error), show the full error and do not proceed.
- When pinning `nixpkgs`, always note the `home-manager` and `disko` follows dependency.
