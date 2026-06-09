---
name: vpn-server-rebuild-workflow
description: Correct workflow for rebuilding the vpn-server (aarch64) from an x86_64 machine with a private GitHub repo
metadata:
  type: feedback
---

`nixos-rebuild --target-host` fails with a platform mismatch when targeting vpn-server from x86_64: it tries to build the `nixos-rebuild` tool for aarch64 locally, which is not possible without binfmt/qemu configured.

The correct workflow is:
1. `rsync` the flake to `/root/NixOS` on the remote (exclude `.git` and `.claude`; fix ownership with `chown -R root:root`).
2. `git init && git add -A && git commit` on the remote so Nix treats it as a valid flake.
3. SSH in and run `nixos-rebuild switch --flake /root/NixOS#vpn-server` directly on the remote.

The logind warning (`Did not receive a reply`) during remote `nixos-rebuild switch` is harmless — it fires because there's no interactive systemd session over SSH. The generation is still activated correctly.

**Why:** The repo is private on GitHub (unauthenticated fetch returns 404). Local machine has no aarch64 binfmt emulation and no remote builders configured. Building natively on the remote is the simplest path.

**How to apply:** Whenever rebuilding vpn-server, use the rsync+remote-run approach above rather than `nixos-rebuild --target-host`. The remote-rebuild skill's documented `--target-host` method does not work for this host.
