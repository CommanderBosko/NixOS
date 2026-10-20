import { test } from "node:test";
import assert from "node:assert/strict";
import { parseConfig, ConfigError, type Schema } from "./config.ts";

const schema = {
  host: { type: "string" },
  port: { type: "number", default: 8080 },
  debug: { type: "boolean", default: false },
} satisfies Schema;

test("parses known keys and fills defaults", () => {
  const cfg = parseConfig("host = example.com\ndebug=yes\n", schema);
  assert.deepEqual(cfg, { host: "example.com", port: 8080, debug: true });
});

test("unknown key is a ConfigError with its line number", () => {
  assert.throws(
    () => parseConfig("host=a\n\ncolour=red\n", schema),
    (e: unknown) => e instanceof ConfigError && e.line === 3 && e.key === "colour",
  );
});
