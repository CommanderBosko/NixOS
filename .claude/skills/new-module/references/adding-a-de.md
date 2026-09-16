# Adding a New Desktop Environment

Load this when the module being scaffolded is `type: desktop-environment`.

Use the `new-module` skill to scaffold `modules/desktop-environments/<name>.nix` and wire it into a host's flake entry. The gotcha: a normal `nh os boot --dry` only exercises whichever DE the target host already has wired in, so it silently verifies nothing about a module not currently imported by any host (true for most of them). Use the `de-smoke-check` skill instead — it deep-evaluates that module's `lib.deSmoke` build graph directly, catching real eval errors a shallow dry-run would miss.
