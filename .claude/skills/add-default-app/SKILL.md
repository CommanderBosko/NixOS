---
name: add-default-app
description: Triggers when user says "set X as the default for Y files", "make X open with Y", "add a default app", or "change the default PDF/archive/image viewer". Adds or changes a declarative default-application (MIME type) association in the shared Home Manager config, verified against the app's real .desktop file rather than guessed.
model: haiku
---

# Add Default App

Add or change a declarative default-application association in `dotfiles/common/configs/home.nix`'s `xdg.mimeApps.defaultApplications`, so double-click / "Open" behavior for a given file type is reproducible across all three desktop hosts (gaming, laptop, natalie-laptop) instead of living as unmanaged live state in `~/.config/mimeapps.list`. (Bucket: Utility)

## Arguments

Parse from the user's request:

- **App** (required) — the application that should become the default, e.g. `zathura`, `xarchiver`, `imv`.
- **File type(s)** (required) — what kind of file(s) should open with it, e.g. "PDFs", "zip files", "images". Can be described loosely; Step 1 resolves it to real MIME types.

## Step 1 — Resolve the app's real .desktop file and MimeTypes — never guess

```bash
nix build --no-link --print-out-paths "nixpkgs#<pkg>"
find <store-path>/share/applications -iname "*.desktop"
grep "^MimeType" <path-to-the-relevant-.desktop-file>
```

Some packages ship multiple `.desktop` files (e.g. zathura ships a base launcher plus one per format backend like `org.pwmt.zathura-pdf-mupdf.desktop`) — pick the one that actually declares the `MimeType=` line for the file type in question, not the bare launcher entry.

If the user's request is extension-based (".rs files", ".nix files") rather than naming a MIME type, cross-check with a live sample:

```bash
echo test > /tmp/sample.<ext> && xdg-mime query filetype /tmp/sample.<ext>; rm /tmp/sample.<ext>
```

## Step 2 — Draft the entries

Add or update lines in `xdg.mimeApps.defaultApplications` in `dotfiles/common/configs/home.nix`, one per MIME type, using the exact `.desktop` filename from Step 1 (e.g. `"application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";`). Add a one-line comment above the block naming the app and noting the mimetypes came from its own `.desktop` file, matching the style of the existing sections in that file.

If this MIME type is already mapped to a different app, show the user the existing line and confirm the change before editing — don't silently overwrite an existing association without saying so.

## Step 3 — Confirm before writing

Show the user the exact new/changed line(s) and confirm via the **AskUserQuestion** tool (`Confirm` / `Cancel`) before editing `home.nix` — matching `add-niri-window-rule`'s and `add-package`'s confirm gate.

## Step 4 — Verify

Run, in order:

1. `nix flake check /home/bosko/NixOS` (or the `flake-check` skill) — shallow eval gate.
2. The `deep-eval-check` skill — forces full evaluation across all 4 hosts.
3. Build and inspect the **actual generated file**, not just eval success (relative to this skill's directory):
   ```bash
   scripts/verify-mimeapps.sh <mimetype>
   ```
   It builds gaming's generated `mimeapps.list` and prints the matching line, or "not found" with a non-zero exit if the mapping isn't there. Confirm the printed line reads exactly what was intended.
4. The `nixos-dry-run` skill for a final gaming-host change-set preview.

## Step 5 — Report and remind

Report the verified result to the user. Remind them a rebuild (`rebuild` + reboot, or a live `nh os switch` if they want to test immediately) is needed to activate it, and offer to run the `git-commit` skill.

## Scripts

- `scripts/verify-mimeapps.sh <mimetype>` — builds gaming's generated `mimeapps.list` and greps it for `<mimetype>`, printing the matching line (exit 0) or "not found" (exit 1). Used in Step 4.3.

## Gotchas

- `xdg.mimeApps` in Home Manager does not force-overwrite `~/.config/mimeapps.list` or `~/.local/share/applications/mimeapps.list` by default. `dotfiles/common/configs/home.nix` already sets `xdg.configFile."mimeapps.list".force = true;` and `xdg.dataFile."applications/mimeapps.list".force = true;` (added 2026-07-17) — if that block is ever removed or this option is reintroduced fresh in a different file, a real pre-existing `mimeapps.list` on a live host will block activation with `Existing file ... would be clobbered` without it.
- Some KDE apps' file-opening/"Open With" behavior depends on `ksycoca` (KDE's service database), which niri never keeps valid since it doesn't run `kded6` — a correct `mimeapps.list` entry can still silently fail to resolve for those apps even though `xdg-open`/`xdg-mime query default` report the correct default. This repo's current default-app stack (Kate, xarchiver, zathura, imv, Thunar, VLC) was deliberately chosen to avoid this class of app — verify a new candidate app doesn't reintroduce a KDE/`ksycoca` dependency before defaulting to it.
