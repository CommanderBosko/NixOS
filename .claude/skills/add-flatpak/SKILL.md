---
name: add-flatpak
description: Triggers when user says "add a flatpak", "install a flatpak", "add flatpak app", "add X as a flatpak", or "add X to flatpaks". Interactively adds a Flatpak app to a host's declarative Flatpak list in its environment.nix, following the nix-flatpak module format used in this repo.
version: 0.2.0
---

# Add Flatpak App

Interactively add a Flatpak app to a desktop host's declarative Flatpak list in `environment.nix`. Follow all steps exactly — do not skip ahead.

## Arguments

Parse from the user's request:

- **`<app-id>`** (required) — the Flathub app ID in reverse-domain style, e.g. `com.spotify.Client`. If the user gave only a friendly name, the app ID still has to be resolved before proceeding (see Step 1).
- **`<host>`** (optional) — one of the **desktop hosts** (the hosts with `"desktop": true` in `.claude/hosts.json` — currently `gaming`, `laptop`, `natalie-laptop`). If omitted, ask in Step 1.

## Step 1 — Gather information

Ask the user the following (batch into one message if both are unknown). Do not proceed until you have both answers.

1. **App** — The app name or Flathub app ID (e.g. `com.spotify.Client`). If the user gave a name but no app ID, note that the Flathub app ID is required and suggest they check [flathub.org](https://flathub.org) to find it. The format is always `com.Publisher.AppName` or similar reverse-domain style.

2. **Host(s)** — Which host(s) to add it to. Valid desktop hosts are those with `"desktop": true` in `.claude/hosts.json` (currently `gaming`, `laptop`, `natalie-laptop`). If the user did not already name a host in their request, present this pick via the **AskUserQuestion tool** with one option per desktop host rather than asking in free-form prose. If the user already supplied the host, skip the question. If the user names a non-desktop host (`vpn-server`), stop and explain that headless hosts do not support Flatpak — do not proceed for those hosts.

## Step 2 — Read the current Flatpak list

Read the target host's config file — its `envFile` in `.claude/hosts.json` (relative to the repo
root `/home/bosko/NixOS`). For the desktop hosts this resolves to `hosts/<host>/environment.nix`.

Show the user the current `services.flatpak.packages` list and the proposed new entry so they can confirm before any edit is made.

## Step 3 — Confirm the addition

Present the exact line that will be added:

```
"com.Publisher.AppName" # App Name
```

Ask the user to confirm before writing. If they gave only a bare app ID with no friendly name, use a shortened version of the app ID as the comment (e.g. `# AppName` from the last segment).

## Step 4 — Edit the file

Add the new entry to `services.flatpak.packages` in the target `environment.nix`.

**Format rules (match exactly what is already in the file):**
- Entries are plain strings: `"com.Publisher.AppName"` — NOT attrsets with `appId`/`origin` fields.
- Each entry is followed by a `#` comment with the friendly app name.
- 4-space indentation inside the list (2 for the outer block, 2 more for the list items — matching repo style).
- Insert alphabetically by app ID where possible. If alphabetical order would look out of place, append at the end.
- Do not add a trailing comma after the last entry — Nix list syntax does not use commas.

**Example of correct format (from gaming/environment.nix):**

```nix
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
    "dev.aunetx.deezer" # Deezer
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
```

Use the Edit tool to insert the new line in the correct position. Do not rewrite the whole file — make a minimal, targeted edit.

## Step 5 — Remind the user of next steps

After the edit is written, tell the user:

1. Run `/nixos-dry-run` to preview the change before applying.
2. Run `/commit` to commit the change.

Do not stage or commit — that is handled by the `/git-commit` skill.

---

## Key constraints

- Only the `"desktop": true` hosts in `.claude/hosts.json` (currently `gaming`, `laptop`, `natalie-laptop`) support Flatpak. Warn and stop if the user requests a headless host (`vpn-server`).
- The entry format is a bare string with an inline comment — never an attrset.
- 2-space indentation throughout the file (4 spaces total inside the list, matching the surrounding file style).
- Do not stage or commit changes — leave that to `/commit`.
- Do not add `origin = "flathub";` or any other attributes — the nix-flatpak module in this repo resolves origin from the plain string format automatically.
- If the user wants to add the same app to multiple hosts, process each host's file in sequence, confirming each edit.
