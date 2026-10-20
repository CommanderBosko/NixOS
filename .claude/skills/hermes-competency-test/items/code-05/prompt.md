Please finish `task/config.ts`, a typed loader for small dotenv-style config files. The comment at
the top of the file is the spec. Three things are still TODO:

1. the `ConfigOf<S>` type (it's `any` right now)
2. the `ConfigError` class
3. `parseConfig` itself

Constraints:

- Edit only `task/config.ts`. Keep the exported names (`FieldSpec`, `Schema`, `ConfigOf`,
  `ConfigError`, `parseConfig`) and the `parseConfig` signature. No npm packages.
- It has to run directly under Node v24, which strips TypeScript types without transforming them.
  So use only erasable TypeScript: no `enum`, no `namespace`, and no constructor parameter
  properties (`constructor(readonly line: number)`).
- It must type-check cleanly in strict mode with
  `nix shell nixpkgs#typescript -c tsc --noEmit --strict task/config.ts`. Don't run `tsc` on the
  `*.test.ts` files: they import `node:test`, and there are no Node type definitions here.
- The types matter as much as the runtime behaviour. With the schema in the spec's example,
  `cfg.port` must be typed `number`, and `cfg.nope` must be a type error.
- `task/config.test.ts` has two example tests. Don't change it. Run tests with
  `node --test 'task/**/*.test.ts'` (keep the quotes). Put your own extra tests under
  `task/scratch/`, as `*.test.ts` files for runtime checks and plain `.ts` files you pass to `tsc`
  for type checks.

When you're done, tell me how you verified both the runtime behaviour and the types.
