Our release tooling uses `satisfies(version, range)` from `task/semver.mjs`, and people keep
hitting wrong answers. Two reports so far:

1. `satisfies("1.10.0", ">=1.9.0")` returns `false`.
2. `satisfies("0.9.0", "^0.2.3")` returns `true`.

I doubt those are the only bugs. The comment block at the top of `task/semver.mjs` is the spec.
Please make the implementation match it completely, not just for these two reports.

- Edit only the code in `task/semver.mjs`. Keep the spec comment and the exported
  `satisfies(version, range)` API. No npm packages; Node's standard library only.
- `task/semver.test.mjs` has a few example tests. Don't change it. Node v24 is installed. Run the
  tests with `node --test 'task/**/*.test.mjs'`; keep the quotes so Node expands the glob, and note
  that `node --test task/` doesn't work. Add your own `*.test.mjs` files under `task/scratch/` for
  the rest of the spec, including the cases that must throw.

When you're done, list each bug you found and fixed, and tell me how you verified the fix.
