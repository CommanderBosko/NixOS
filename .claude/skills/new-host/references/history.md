# Background for Step 3's substitution rules

Load this only for the why behind two of Step 3's placeholder rules. The rules themselves are inline in SKILL.md.

## `<current-nixos-release>` must be substituted

This is a real, live-caught gap: Step 1 gathers the value but nothing wired it into the substitution list before — following the template literally would write `system.stateVersion = "<current-nixos-release>";` into the new host's config instead of the real version.

## `<pihole-ip>` is read live, never hardcoded

hosts.json's own notes flag this address as drift-prone (it already changed once, in an early-Aug 2026 outage), so re-read it at fill time rather than trusting a remembered value.
