/**
 * Typed loader for small dotenv-style config files.
 *
 *   const cfg = parseConfig(text, {
 *     host: { type: "string" },
 *     port: { type: "number", default: 8080 },
 *     debug: { type: "boolean", default: false },
 *     tags: { type: "list", default: [] },
 *   });
 *   cfg.port; // typed as number
 *
 * TYPES
 *   ConfigOf<S> is the result type for schema S: an object type with exactly the keys of S, where
 *   a "string" field is string, "number" is number, "boolean" is boolean and "list" is string[].
 *   It has to be precise: reading cfg.port above must give number (not any, not a union), and
 *   reading a key that isn't in the schema must be a type error.
 *
 * INPUT FORMAT
 *   The text is processed line by line (split on "\n"; one trailing "\r" per line is dropped).
 *   Line numbers are 1-based.
 *   - Lines that are empty or only whitespace are ignored, and so are lines whose first
 *     non-whitespace character is "#". There are no inline comments: in "a=b # c" the value is
 *     "b # c".
 *   - Every other line must be KEY=VALUE. KEY is the text before the first "=", trimmed. VALUE is
 *     everything after that first "=", trimmed (so it may itself contain "=").
 *   - If the trimmed VALUE is at least 2 characters long and starts and ends with a double quote,
 *     the two quotes are removed and the inside is kept exactly as written (no trimming, no escape
 *     processing). Otherwise the trimmed VALUE is used as is.
 *
 * CONVERSION (applied to VALUE after quote handling)
 *   string   the value unchanged (may be "")
 *   number   must match /^-?\d+(\.\d+)?$/, then Number(value)
 *   boolean  true for "true", "yes", "on", "1"; false for "false", "no", "off", "0";
 *            case-insensitive
 *   list     split on ",", trim each item, drop empty items ("" gives [])
 *
 * RESULT
 *   A plain object with exactly the schema's keys. A key missing from the text takes its default.
 *   A list default is copied, so mutating the result never changes the schema.
 *
 * ERRORS: throw ConfigError
 *   with line = the line number and key = null:
 *     - a non-comment line with no "=", or with an empty KEY
 *   with line = the line number and key = KEY:
 *     - KEY is not in the schema
 *     - KEY appears a second time (report the line of the repeat)
 *     - VALUE can't be converted to the field's type
 *   with line = null and key = the field name:
 *     - a field without a default is missing from the text; if several are missing, report the
 *       first one in the schema's key order
 *   Problems in the text are found top to bottom and come before missing-field errors. The first
 *   problem found is the one thrown.
 *
 *   ConfigError extends Error. Its name is "ConfigError", it has readonly `line: number | null` and
 *   readonly `key: string | null`, and its constructor is (message, line, key).
 */

export type FieldSpec =
  | { type: "string"; default?: string }
  | { type: "number"; default?: number }
  | { type: "boolean"; default?: boolean }
  | { type: "list"; default?: string[] };

export type Schema = Record<string, FieldSpec>;

// TODO: replace with the precise type described above.
export type ConfigOf<S extends Schema> = any;

export class ConfigError extends Error {
  // TODO
}

export function parseConfig<S extends Schema>(text: string, schema: S): ConfigOf<S> {
  throw new Error("not implemented");
}
