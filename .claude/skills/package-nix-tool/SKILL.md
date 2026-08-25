---
name: package-nix-tool
description: Package a new external tool (a GitHub repo or an npm package) as a flake-managed Nix derivation, following this repo's established declarative pattern for custom tools. Use when the user says "package this as a nix derivation", "add a custom package from github", "package X for the flake", "add a buildNpmPackage tool", or "turn this repo into a nix package".
---

# Package a Nix Tool

Turns an external tool that isn't in nixpkgs into a proper flake-managed package, following the
exact pattern this repo already established with `pkgs/tailscale-mcp.nix`. (Bucket: Orchestration
— it chains bespoke packaging work with existing verification skills: `add-secret`,
`deep-eval-check`, `nixos-dry-run`.)

## Arguments

Gather up front (ask only for what's missing):

1. **What's the tool, and where does it live?** — a GitHub `owner/repo` (+ tag/ref) or an npm
   package name.
2. **What should the resulting Nix package attribute be called?** — short kebab-case name,
   becomes `pkgs/<name>.nix` and the `pkgs.<name>` attribute.
3. **Is this a Claude-ecosystem tool** (an MCP server, or something that plugs into Claude Code
   itself)? Determines whether Step 6 applies. If unclear from the request, ask via
   **AskUserQuestion**.

## Step 1 — Check it isn't already in nixpkgs

Before writing anything, confirm the tool genuinely needs a from-scratch package — don't
duplicate something upstream already ships. Use the `search-pkg` skill (backed by the `nixos`
MCP server) to search nixpkgs by name and by likely alternate names. If it's already packaged,
stop here and just add the existing attribute instead of this whole workflow. If not found, note
the search you ran and what you checked (e.g. "checked via mcp-nixos search, <date>") — this
repo's convention is to record that check as a comment at the top of the new `pkgs/<name>.nix`
(see `pkgs/tailscale-mcp.nix`'s opening comment for the exact style).

## Step 2 — Inspect the upstream repo to pick the builder

Fetch the repo (WebFetch the GitHub repo page, or `gh repo view`/`gh api` for file contents) and
determine which Nix builder fits, based on what the repo actually ships:

| Repo has… | Builder | Extra hash field |
|---|---|---|
| `package.json` | `buildNpmPackage` | `npmDepsHash` |
| `go.mod` | `buildGoModule` | `vendorHash` |
| `Cargo.toml` | `rustPlatform.buildRustPackage` | `cargoHash` |
| none of the above / plain Makefile or script | `stdenv.mkDerivation` | (none) |

Also check, while you're in there, for anything that shaped `tailscale-mcp.nix`'s extra bits:
- Does the built output shell out to another CLI at runtime? → needs `makeWrapper` +
  `wrapProgram ... --prefix PATH : ${lib.makeBinPath [ ... ]}` in `postFixup`.
- Does the package tree ship no runtime `dependencies` (a bundler like esbuild inlines
  everything)? → the default `buildNpmPackage` install phase needs no further pruning; note this
  in a comment if so, since it's the kind of thing that looks like an oversight otherwise.
- License, for `meta.license = lib.licenses.<x>;`.
- The `bin` entry name, for `meta.mainProgram`.

## Step 3 — Write `pkgs/<name>.nix`

Model the file directly on `pkgs/tailscale-mcp.nix`'s structure:

- Opening comment block: why this needs to be packaged from scratch (the nixpkgs check from
  Step 1), why this tool/fork was chosen if there were alternatives, and any non-obvious build
  behavior found in Step 2 (bundling, runtime CLI dependency, etc.).
- Function args: only the builder + fetcher + whatever's actually used (`lib`, `buildNpmPackage`,
  `fetchFromGitHub`, `makeWrapper`, and any runtime-dependency package like `tailscale` was).
- `pname`/`version` as a `rec` attrset field, `src` via `fetchFromGitHub` (or `fetchFromGitLab`/
  `fetchurl` as applicable) pinned to a `tag` or `rev`, hash fields left as
  `lib.fakeHash` placeholders for now (resolved in Step 4).
- `meta` block: `description`, `homepage`, `license`, `mainProgram`, `platforms`.

Use `lib.fakeHash` (`"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="`) for `src.hash` and
any deps-hash field to start — don't guess a real value.

## Step 4 — Resolve the real hashes

Run the resolver script once per hash field, **outermost first** (`src.hash` before
`npmDepsHash`/`vendorHash`/`cargoHash` — a src mismatch is reported before Nix evaluates far
enough to hit a deps-hash mismatch):

```bash
.claude/skills/package-nix-tool/scripts/resolve-nix-hash.sh pkgs/<name>.nix
```

It prints the real hash on success (exit 0) — paste it into the field, replacing the
`lib.fakeHash` placeholder, then re-run the script to resolve the next field. Exit 2 means the
build already succeeded (nothing left to resolve); exit 1 means a real build error — read the
tail of output the script prints to stderr and fix the derivation before continuing.

## Step 5 — Wire it into the flake

Add one line to the overlay in `modules/nix.nix` (it already has one entry, `tailscale-mcp` —
follow that exact shape):

```nix
nixpkgs.overlays = [
  (final: _prev: {
    tailscale-mcp = final.callPackage "${self}/pkgs/tailscale-mcp.nix" { };
    <name> = final.callPackage "${self}/pkgs/<name>.nix" { };
  })
];
```

Then add the package to wherever it should actually be installed — ask via **AskUserQuestion**
if not already clear:
- A specific user's packages (`modules/users.nix`, mirroring the `tailscale-mcp # MCP server
  backing...` comment style — say what it's for and point back at its `pkgs/` file and overlay).
- A specific host's `environment.systemPackages` (that host's `environment.nix`).
- Shared Home Manager packages (`dotfiles/common/` or `dotfiles/bosko/`), if it's a per-user tool
  both `bosko` and `natty` should get.

## Step 6 — Wire it into Claude Code (conditional — Claude-ecosystem tools only)

Skip this step entirely for a tool that isn't part of the Claude Code ecosystem. If it is an MCP
server, mirror `tailscale-mcp`'s registration in `dotfiles/bosko/bosko-claude.nix`'s
`home.activation.claudeMcpServers` block: add a `desired<Name>` attrset (`type = "stdio"`,
`command`, `args`, `env`) to the `let`, and a `<name> = desired<Name>;` entry in `servers`. If the
server needs credentials, route them through a sops secret the way `tailscale-mcp` does — a
`bash -c 'set -a; source <secret path>; set +a; exec <bin>'` command — never place a raw
credential in the `env` object (that would land in plaintext in `~/.claude.json`). If it's a
skill or agent file instead of an MCP server, wire it the same way any global skill is wired (see
this repo's `new-skill` skill, "Global, in a Home-Manager-managed repo" case) rather than an MCP
entry.

## Step 7 — Add a secret, if the tool needs one

If Step 2 or Step 6 surfaced a required credential (API key, OAuth client, token), invoke the
`add-secret` skill to add it to sops rather than hand-rolling the sops commands here.

## Step 8 — Stage and verify

```bash
git -C /home/bosko/NixOS add pkgs/<name>.nix modules/nix.nix
# plus modules/users.nix / environment.nix / dotfiles/bosko/bosko-claude.nix / secrets/,
# whichever of those you actually touched
```

Flake evaluation only sees tracked files, so this is mandatory before verifying — not optional
cleanup. Then run, in this order:

1. `deep-eval-check` skill — forces a real per-host build-graph evaluation so the new overlay
   attribute and its build graph are actually exercised, not just shallow-checked.
2. `nixos-dry-run` skill — previews what a rebuild on the affected host(s) would change.

## Step 9 — Report back

Tell the user: the new file(s) written, the overlay line added, where the package got installed
(host/user), whether Claude Code wiring and/or a secret were involved, and the verification
results from Step 8. Remind them a rebuild (`nh os boot /home/bosko/NixOS` or a host-specific
rebuild) is still needed to actually activate the package — dry-run/deep-eval only prove it
evaluates.

## Scripts

- `.claude/skills/package-nix-tool/scripts/resolve-nix-hash.sh <pkgs-file> [system]` — runs the
  fake-hash-then-build trick against the flake's own nixpkgs input and prints the real hash from
  a fixed-output-hash mismatch (Step 4). Defaults `system` to `x86_64-linux`.

## Gotchas

- Resolve hash fields **one at a time, outermost first**. Setting both `src.hash` and
  `npmDepsHash` to `lib.fakeHash` at once only ever surfaces the `src.hash` mismatch — Nix can't
  evaluate far enough to hit the deps-hash mismatch until the src hash is already correct.
- Don't skip Step 1. Packaging something that already has a nixpkgs attribute means carrying a
  maintenance burden (rebuilds, security patches) this repo doesn't need to own.
