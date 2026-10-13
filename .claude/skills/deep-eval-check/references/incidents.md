# Deep Eval Check — Incidents

Background for why this skill exists.

## 2026-07-02: shallow `flake-check` passed, real rebuilds failed

`nix flake check` only verifies each host's toplevel attribute resolves to a derivation — it
does not force full evaluation. A host can pass `flake-check` and still fail every real
`nh os boot`. This happened 2026-07-02 with a pnpm/vesktop insecure-package regression (see
memory `project_pnpm_insecure_waiver.md`): a broken package deep in
`environment.systemPackages` (one newly marked insecure) passed the check but failed every
real rebuild. This skill closes that gap by forcing each host's
`config.system.build.toplevel.drvPath`.
