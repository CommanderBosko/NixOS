# Conventional Commit Format Reference

Subject line format:

```
type(scope): short description in sentence case
```

**Types:** `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `test`, `perf`

**Scope:** use the affected area of the repo — e.g. `gaming`, `laptop`, `security`, `skills`, `vpn`, `memory`, `flake`, `shell`, `users`. Use the most specific scope that fits. If multiple unrelated scopes are touched, pick the dominant one or use no scope.

**Examples from this repo's history:**
- `feat(skills): add new-module skill for NixOS module scaffolding`
- `fix(natalie-laptop): add wg0 DNS for full-tunnel VPN routing`
- `chore(session): end-of-day close 2026-05-18 — WireGuard VPN fully deployed`
- `refactor(vpn): move DNS into shared vpn.nix, apply to all client hosts`
- `chore(memory): update vpn-setup memory with natalie-laptop peer status`

**Rules:**
- Subject line is lowercase after the colon, no trailing period.
- Keep it under 72 characters.
- Focus on *what changed and why*, not *how*.
- If the change is a session close, use `chore(session): end-of-day close YYYY-MM-DD — <brief summary>`.
