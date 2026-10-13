# rollback gotchas — history

Background for the rules in SKILL.md's Key constraints and Gotchas.

- **Why this skill stays on the `nixos-rebuild`-direct flow.** No dry-run mode for this flow — rollback either happens or it doesn't. (`nh os rollback` does have a `--dry` flag, but this skill deliberately stays on the `nixos-rebuild`-direct flow that's been proven across 9+ past sessions.)
- **The NOPASSWD failure is long-standing.** Running `sudo nixos-rebuild switch --rollback` directly via the Bash tool failing with "a terminal is required to read the password" was observed across 9+ past sessions before the hand-off rule was written down.
- **This skill's "`nh` has no rollback subcommand" claim was wrong and has been removed** (corrected 2026-08-09 skill-audit sweep). `nh os rollback --to <gen>` genuinely exists (`nh 4.4.1`, confirmed via `nh os rollback --help`) and maps directly onto this skill's own generation-target argument. It's not adopted here only because the `nixos-rebuild`-direct flow above is the one actually proven across 9+ past sessions on this host — not because `nh` doesn't work. Same NOPASSWD hand-off constraint applies to either command. (Step 3 now uses `nh os rollback --to <N>` for the explicit-target case only; the default one-step rollback is still `nixos-rebuild switch --rollback`.)
