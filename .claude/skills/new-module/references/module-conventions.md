# Already handled by shared modules — don't re-add

Shared by the `new-module` and `new-host` skills (new-host cites this file by its repo path, `.claude/skills/new-module/references/module-conventions.md`). Load it before writing a new module or a new host's files.

These shared modules already cover the settings below for every host that imports them. A new module or a new host's files must not re-declare them. The modules themselves are the source of truth; if this list and the module disagree, trust the module.

- `modules/security.nix` (in `commonModules`, so every host) already handles AppArmor, audit, PAM wheel, ASLR, and kexec — do not re-add any of those in a new module or in host files.
- Never add `services.dbus` configuration in a new module without checking `security.nix` first. It sets D-Bus AppArmor mediation and selects `dbus-broker` as the implementation.
- `modules/audio.nix` (in `desktopModules`, so desktop hosts only) already handles PipeWire — do not add PipeWire config to other modules or to host files.
- `modules/sops.nix` (in `commonModules`) imports sops-nix, sets each host's age identity, and supplies the shared login-password secrets to every host. Don't re-import sops-nix or redeclare those secrets. A module that needs its own secret declares only its own `sops.secrets.<name>` (as `modules/claude-mcp.nix` does). A new host's scaffolded files add no `sops.*` config; instead the host must be registered as a sops recipient (new-host Step 8) or it cannot decrypt the shared secrets.
