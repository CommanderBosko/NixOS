Please implement the Nix function in `task/hosts.nix`. It's meant to render an `/etc/hosts`
fragment from an attrset of hosts. Right now the body is just a `throw`. The comment at the top of
the file is the spec: argument shapes, the exact output format and sort order, and which inputs
must be rejected and how.

- Edit only `task/hosts.nix`. Keep the `{ hosts, domain ? null }:` argument list.
- Use Nix builtins only: no `<nixpkgs>`, no `lib`, no `import` of anything else. The file has to
  evaluate on its own with an empty `NIX_PATH`.
- You can evaluate it with `nix-instantiate --eval --strict --json` (or `nix eval --expr ...`), for
  example by passing an `-E` expression that imports `./task/hosts.nix` with test arguments. Use
  `builtins.tryEval` to confirm that the inputs which should be rejected really fail through `throw`.
  Keep any test files you write under `task/scratch/`.

When you're done, tell me how you tested it and the results.
