---
name: new-module
description: Use this skill when the user wants to "create a new NixOS module", "add a module", "scaffold a module", "write a new nix module", or "add a desktop environment". It generates a well-formed module file in the correct location following the repo's conventions.
model: haiku
version: 0.2.0
---

# New NixOS Module Scaffolder

Interactively gather the information needed, then write a correctly-structured NixOS module file into the right location in this repo. Follow all conventions exactly as described below — do not deviate from them.

## Arguments

Parse from the user's request before asking anything:

- **module name** — a short, lowercase, hyphenated name taken from the phrasing (e.g. "add a `bluetooth` module" → `bluetooth`). Becomes the filename `<name>.nix`. If absent, ask in Step 1.
- **type** — `system` or `desktop-environment`, inferred from phrasing ("add a desktop environment" → `desktop-environment`; "scaffold a module" → `system`). Decides the target directory. If not clearly implied, present the pick in Step 1.
- **purpose** — a one-sentence description of what the module configures, taken from the phrasing if given. Used as the file's top comment. If absent, ask in Step 1.

## Step 1 — Gather information

Ask the user the following questions (you may batch them into a single message). Do not proceed to Step 2 until you have answers to all required questions.

**Required:**

1. **Module name** — A short, lowercase, hyphenated name (e.g. `bluetooth`, `printing`, `cosmic`). This becomes the filename: `<name>.nix`.

2. **Module type** — One of:
   - `system` — A general system-level module. Goes in `modules/`.
   - `desktop-environment` — A desktop environment or compositor module. Goes in `modules/desktop-environments/`.

   If the type was not already clear from the user's phrasing (see Arguments), present this pick via the **AskUserQuestion tool** with one option per type (`system`, `desktop-environment`) rather than free-form prose. Skip the question if the type is already known.

3. **Purpose** — One sentence describing what this module configures. Used as the top comment in the file.

4. **Hosts** — Which hosts will import this module? Present this pick via the **AskUserQuestion tool** (allow multi-select) rather than free-form prose, with one option per `.flakeHosts` entry in `.claude/hosts.json` — enumerate live, don't hardcode: `jq -r '.flakeHosts[]' /home/bosko/NixOS/.claude/hosts.json` — plus an `all desktop hosts` option (the `"desktop": true` hosts) and an `all hosts` option. This is informational — it determines where the import line goes in `flake.nix`. Skip the question if the user already named the host(s).

**Optional (ask only if relevant):**

5. **Options to expose** — Should this module expose any `options` (e.g. an `enable` toggle, configurable values)? Most simple modules in this repo do NOT expose options — they are always-on when imported. Present this as a pick-one via the **AskUserQuestion tool** (`Yes, expose options` / `No, always-on`) rather than free-form prose, defaulting the recommended option to "No, always-on" since that's this repo's dominant pattern. Skip the question if the user already said.

6. **Packages needed** — Any `pkgs.*` packages to add to `environment.systemPackages`? List them.

7. **Services needed** — Any `services.*` or `programs.*` to enable? List them.

8. **Home Manager config** — Does this module need to configure anything via `home-manager.users.<name>`? Present this as a pick-one via the **AskUserQuestion tool** (`Yes` / `No`) rather than free-form prose; if yes, ask which user(s) in the same follow-up. Skip the question if the user already said.

9. **Flake inputs needed** — Does this module need access to a flake input (e.g. `inputs.dms`, `inputs.nix-flatpak`)? Present this as a pick-one via the **AskUserQuestion tool** (`Yes` / `No`) rather than free-form prose; if yes, ask which input in the same follow-up. Skip the question if the user already said.

## Step 2 — Determine the correct file path

Based on module type:

- `system` → `/home/bosko/NixOS/modules/<name>.nix`
- `desktop-environment` → `/home/bosko/NixOS/modules/desktop-environments/<name>.nix`

## Step 3 — Generate the module

Choose the matching template under `assets/`, read it, and fill in the `<placeholders>` precisely. Do not add unnecessary abstractions — match the style of existing modules.

---

### Template A: Simple always-on module (no options, most common) — `assets/module-simple.nix.tmpl`

Use this when the module is unconditionally active whenever imported. This is the default pattern for `audio.nix`, `gaming.nix`, `virtualisation.nix`, etc.

Function signature rules:
- Include `config` only if the module references `config.*` internally (e.g. `config.networking.hostName`, `config.services.displayManager.sddm.enable`).
- Include `lib` only if the module calls `lib.*` functions (`lib.mkForce`, `lib.mkIf`, `lib.mkDefault`).
- Include `pkgs` only if the module references `pkgs.*`.
- Include `inputs` only if the module uses a flake input.
- Use `{ ... }:` (ellipsis-only) when none of the above apply (e.g. `audio.nix`).

---

### Template B: Module with options (conditional/configurable) — `assets/module-options.nix.tmpl`

Use this only when the user explicitly asked for options. Mirrors the standard NixOS module pattern. The template's trailing comment shows how to add extra `lib.mkOption` options beyond `enable`.

---

### Template C: Desktop environment module — `assets/module-de.nix.tmpl`

Use this for `desktop-environment` type modules. Mirrors `plasma.nix`, `niri.nix`, `cosmic.nix`. The template's trailing comment shows the Home Manager variant.

Key characteristics:
- Enables the compositor or DE via `services.desktopManager.<de>.enable` or `programs.<compositor>.enable`.
- Usually enables `services.xserver.enable = true` (required even on Wayland for many DEs).
- May add Wayland utilities to `environment.systemPackages`.
- May configure Home Manager for `bosko` if the DE uses HM-side programs (like `niri.nix` does with DMS) — use the commented HM variant in the template.
- Never exposes `options` — always-on when imported.

---

## Step 4 — Write the file

Write the complete generated module to the determined path using the Write tool. Show the user the full file content before writing so they can confirm.

## Step 5 — Git add

After writing the file, run:

```bash
git -C /home/bosko/NixOS add <path-to-new-file>
```

This is mandatory. NixOS flake evaluation will not see the file unless it is tracked by git (even uncommitted). Remind the user of this if they ask why.

## Step 6 — Tell the user where to import it

Based on the host(s) the user named in Step 1, tell them exactly where to add the import in `flake.nix`. The import string format is always:

```nix
"${self}/modules/<name>.nix"
# or for desktop-environment modules:
"${self}/modules/desktop-environments/<name>.nix"
```

Identify the correct host block(s) in `/home/bosko/NixOS/flake.nix` and show the user the line to add and where it goes (which list: `commonModules`, `desktopModules`, or the host-specific module list). Do NOT edit `flake.nix` automatically — show the user what to add and where, then let them do it or ask you to do it.

Note: modules that should apply to all desktop hosts belong in the `desktopModules` list. Modules that apply to all hosts belong in `commonModules`. Host-specific modules go in the host's own entry in the `nixosConfigurations` attrset.

## Step 7 — Suggest a dry-run

After the import is added (or shown), remind the user to test with:

```
nh os boot /home/bosko/NixOS --dry
```

or the `nixos-dry-run` skill, before doing a full rebuild.

---

## Key conventions to preserve

- 2-space indentation throughout.
- Opening brace on the same line as the attribute name (`services = {`, not `services =\n{`).
- `with pkgs;` inside list expressions, not at the top level.
- Comments use `#` with a space, written in sentence case.
- No trailing commas on single-item lists; use multi-line with trailing commas when there are multiple items.
- `lib.mkForce` and `lib.mkDefault` are used sparingly and only when needed to resolve merge conflicts or set explicit precedence. Never add them just for clarity.
- `security.nix` already handles AppArmor, audit, PAM wheel, ASLR, and kexec — do not re-add any of those in a new module.
- `audio.nix` already handles PipeWire — do not add PipeWire config to other modules.
- Never add `services.dbus` configuration in a new module without checking `security.nix` first.

## Assets

- `assets/module-simple.nix.tmpl` — Template A: simple always-on module.
- `assets/module-options.nix.tmpl` — Template B: module with `options` (includes commented `lib.mkOption` example).
- `assets/module-de.nix.tmpl` — Template C: desktop-environment module (includes commented Home Manager variant).
