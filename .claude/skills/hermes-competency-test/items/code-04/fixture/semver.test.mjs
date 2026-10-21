import { test } from "node:test";
import assert from "node:assert/strict";
import { satisfies } from "./semver.mjs";

test("minor versions compare numerically (bug report #1)", () => {
  assert.equal(satisfies("1.10.0", ">=1.9.0"), true);
});

test("caret on a 0.x version stays within the minor (bug report #2)", () => {
  assert.equal(satisfies("0.9.0", "^0.2.3"), false);
});

test("x-range", () => {
  assert.equal(satisfies("1.4.2", "1.x"), true);
  assert.equal(satisfies("2.0.0", "1.x"), false);
});
