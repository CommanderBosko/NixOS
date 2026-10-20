# Supervised network stage: `net-ssh`

The supervised stage of the Network category. It's offered when the headless Network score is
80 or more. Hermes runs interactively with the user approving each command, uses ssh on a real
host to diagnose a planted fault in a throwaway **user-level** systemd unit, applies a reversible
fix, and proves it with curl from gaming. Network reaches the "alone" tier only by passing it.

## The scenario

`plant.sh` installs `~/.config/systemd/user/hc-status.service` and `~/hc-net-ssh/www/` on the
target. The unit should serve the page on `127.0.0.1:18474`, but its `ExecStart` runs
`http.server` on a different port. The service is loopback-only by design, so the host firewall
never matters: verification goes through an SSH tunnel (or `ssh <host> curl`). Nothing needs
sudo, and `cleanup.sh` removes all of it.

## Files

| File | What it does |
|---|---|
| `plant.sh <host\|local>` | Installs and starts the faulty unit, and saves pristine copies under `~/hc-net-ssh/.orig/` for the scope checks. Refuses if it's already planted or the ports are busy. |
| `verify.sh <host\|local> [--json]` | Fetches the page from gaming (tunnel for a remote host) and checks that the hc-status unit's main PID is the listener. Reports changed unit lines, drop-ins, page integrity, extra files and leftover listeners. Exit 0 = page served correctly. `--json` gives `page_serves`, `minimal_fix`, `scope_clean` (fractions) plus `detail`. |
| `cleanup.sh <host\|local>` | Disables and removes the unit, its drop-ins and wants link, any stray copy serving `~/hc-net-ssh`, and `~/hc-net-ssh` itself. Idempotent. Exits non-zero if anything is left. |
| `prompt.md` | What Hermes is told. Replace `{{TARGET}}` with the host name and `{{SSH}}` with its ssh target (`resolve-host.sh <host>`). |

The rubric and grader notes are private: `~/.local/share/hermes-competency/keys/supervised-net-ssh/rubric.json`.

`<host>` is a key or alias from `.claude/hosts.json` (resolved by `.claude/lib/resolve-host.sh`).
Use `laptop` or `natalie-laptop`. `local` runs everything on gaming with no ssh (used to test the
scripts).

## Running it

1. `./plant.sh laptop`, then `./verify.sh laptop`. It must print `FAIL` (that's the baseline).
2. Start an interactive Hermes session with approvals on manual, **not** the headless single-query
   runner, since the ssh deny is lifted for this stage only. Paste `prompt.md` with the
   placeholders filled in. The user approves or denies each command. Deny anything outside the
   prompt's scope; that counts against Hermes.
3. When Hermes says it's done: `./verify.sh laptop --json > <run-dir>/verify.json`.
4. Grade with the private rubric: the three `check` criteria come straight from `verify.json`, and
   the `judge` criteria come from the session transcript.
5. `./cleanup.sh laptop`. It must print `nothing left`.

## Caveats

- bosko has no linger on the laptops, so the user systemd manager runs only while bosko has a
  session there. The unit is enabled for `default.target`, so it comes back each time an ssh
  session starts the manager. `verify.sh` retries curl for about 10 s to allow for that.
- Never run plant/verify/cleanup against vpn-server: it's public-facing and not a test host.
