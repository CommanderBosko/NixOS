---
name: pihole-api
description: Authenticate to the pi-hole host's local REST API (session-based auth via the CLI password file) and run one or more follow-up calls against it. Use when the user says "pi-hole api", "call the pihole api", "add a blocklist to pi-hole", "query pi-hole lists", or "trigger pihole gravity rebuild".
---

# Pi-hole API

Run authenticated calls against the pi-hole host's local REST API (`http://127.0.0.1/api/...`, reachable only from the pi-hole host itself) without hand-rolling the curl/SID dance each time. (Bucket: Utility)

## How auth works

Pi-hole v6's API is session-based: you POST the CLI password (readable only via `sudo`) to `/api/auth` to mint a session ID (SID), then send that SID as a `sid:` header on every subsequent call. `scripts/pihole-api.sh` does this whole dance in one SSH round-trip per invocation — call it fresh each time rather than trying to cache a SID between calls.

## Steps

1. **Figure out which call the user wants.** Match their request to one of the common calls below. If it's a call not listed here (a path this skill hasn't seen before), you can still use the script — pass whatever `/api/...` path, method, and JSON body the task needs.

2. **Run the call via the script:**
   ```bash
   bash /home/bosko/NixOS/.claude/skills/pihole-api/scripts/pihole-api.sh <METHOD> <path-with-query> [json-body]
   ```
   The script resolves the `pi-hole` host from `.claude/hosts.json` itself (same convention as `ssh-host`/`journal`/`verify-service` — never hardcode the SSH target here), reads the CLI password via `sudo -n cat /etc/pihole/cli_pw`, mints a SID against `/api/auth`, makes the requested call, and prints the raw JSON response.

   **List block lists (adlists):**
   ```bash
   bash scripts/pihole-api.sh GET "/api/lists?type=block"
   ```
   Response is `{"lists":[{...,"address":...,"comment":...,"enabled":...,"id":...}, ...]}` — read `.lists[]` for the current adlist set.

   **Add a block list:**
   ```bash
   bash scripts/pihole-api.sh POST "/api/lists?type=block" '{"address":"<url>","comment":"<text>","groups":[0],"enabled":true}'
   ```
   **Gotcha (hit live, don't repeat it):** `type` is a **query param** (`?type=block`), never a JSON body field — `{"type":"block",...}` in the body fails with `{"error":{"key":"bad_request","message":"Invalid request: Specify type parameter..."}}`.

   **Disable (or otherwise update) a list**, addressed by its URL-encoded address as the path segment:
   ```bash
   bash scripts/pihole-api.sh PUT "/api/lists/<url-encoded-address>?type=block" '{"enabled":false}'
   ```
   URL-encode the address yourself (e.g. `https://example.com/list.txt` → `https%3A%2F%2Fexample.com%2Flist.txt`) before building the path.

   **Delete a list:**
   ```bash
   bash scripts/pihole-api.sh DELETE "/api/lists/<url-encoded-address>?type=block"
   ```

   **Trigger a gravity rebuild — do NOT route this through the API.** The real session that produced this skill never used a REST endpoint for it; gravity was rebuilt with a plain CLI command over the same SSH connection:
   ```bash
   ssh $(bash /home/bosko/NixOS/.claude/lib/resolve-host.sh pi-hole) "sudo -n pihole -g"
   ```
   Run this directly (not via `pihole-api.sh`) after any add/disable/delete calls that need gravity re-processed to take effect. Tail the output for `[✓] Building gravity tree` and the final domain-count line to confirm it parsed cleanly; a stray list URL that fails to download shows up here as a warning rather than an error, so skim the whole tail, not just the exit code.

3. **Interpret the response** and report back in plain terms — e.g. "added, list now has N entries", "disabled", "deleted", or the specific `error.message` if the call failed. If a `bad_request`/`401`/`404` comes back, don't guess a fix blind: re-check the path/query-vs-body placement against the gotcha above, or fall back to `GET /api/lists?type=block` to see current state before retrying a PUT/DELETE with the wrong address encoding.

## Scripts

- `.claude/skills/pihole-api/scripts/pihole-api.sh <METHOD> <path-with-query> [json-body]` — resolves the pi-hole host, does the `sudo -n cat cli_pw` → `POST /api/auth` → SID dance over one SSH connection, runs the requested call with the SID header, and prints the raw response (Step 2). Values are base64-encoded across the SSH boundary so JSON bodies and query strings survive intact instead of being re-tokenized by the remote shell.

## Gotchas

- **A body-less call (GET/DELETE) used to print a stray `bash: line 4: $3: unbound variable`.** SSH flattens the remote command's argv into one string for the remote shell to re-split; an empty `BODY_B64` token vanishes in that re-split, so the remote heredoc's direct `"$3"` reference was genuinely unset. Fixed by using `"${3:-}"` there too (mirroring the already-safe top-level `BODY="${3:-}"`). Caught live via `ship-skill`'s smoke test (2026-08-25, a `GET /api/lists` call) — the call still returned correct data despite the error (no `set -e` in the script), but the noise is now gone.
- `type` (`block`/`allow`) belongs in the **query string**, not the JSON body, for every `/api/lists` call — see Step 2.
- Gravity rebuilds go through the CLI (`sudo -n pihole -g` over SSH), not the REST API — there's no `/api/action/gravity`-style endpoint used in practice here.
- List PUT/DELETE addresses must be URL-encoded as the path segment. If a call 404s, double-check the encoding rather than assuming the list doesn't exist — `GET /api/lists?type=block` first to confirm the exact stored `address` string.
