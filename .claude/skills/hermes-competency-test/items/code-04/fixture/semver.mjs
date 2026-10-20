/**
 * Tiny semver range matcher used by our release tooling.
 *
 * satisfies(version, range) -> boolean
 *
 * VERSION
 *   "MAJOR.MINOR.PATCH": exactly three non-negative decimal integers separated by dots, without
 *   leading zeros ("0" on its own is fine). No surrounding whitespace, no pre-release or build tags
 *   ("1.2.3-beta" and "1.2.3+build" are invalid). An invalid version argument throws TypeError.
 *   Versions compare numerically, part by part: 1.10.0 > 1.9.0.
 *
 * RANGE
 *   range := set ( "||" set )*     true if ANY set matches
 *   set   := term ( " "+ term )*   true if ALL terms in the set match
 *   Whitespace around "||" and at either end of the range is ignored. Terms within a set are
 *   separated by one or more spaces. A set must contain at least one term.
 *
 *   Terms:
 *     *  x  X           any version
 *     OPVERSION         OP is one of >=  <=  >  <  =  written directly before a full VERSION,
 *                       e.g. ">=1.2.3". No space between OP and VERSION.
 *     VERSION           same as =VERSION
 *     ^VERSION          caret: at least VERSION, below the next bump of its left-most non-zero part
 *                         ^1.2.3 := >=1.2.3 <2.0.0
 *                         ^0.2.3 := >=0.2.3 <0.3.0
 *                         ^0.0.3 := >=0.0.3 <0.0.4
 *     ~VERSION          tilde: at least VERSION, below the next minor
 *                         ~1.2.3 := >=1.2.3 <1.3.0
 *     MAJOR.x           x-range (x, X or * as the wildcard): 1.x := >=1.0.0 <2.0.0
 *     MAJOR.MINOR.x     x-range: 1.2.x := >=1.2.0 <1.3.0
 *
 *   Anything else throws TypeError: an empty range, an empty set ("1.0.0 ||"), an unknown
 *   operator, a partial version outside the x-range forms ("1.2", "^1.2", "~1.x"), a space between
 *   an operator and its version (">= 1.2.3"), or an invalid VERSION inside a term.
 */

function parseVersion(v) {
  const parts = v.split(".");
  if (parts.length !== 3) {
    throw new TypeError(`invalid version: ${v}`);
  }
  return parts;
}

function compare(a, b) {
  for (let i = 0; i < 3; i++) {
    if (a[i] > b[i]) return 1;
    if (a[i] < b[i]) return -1;
  }
  return 0;
}

const OPS = {
  ">=": (c) => c >= 0,
  "<=": (c) => c <= 0,
  ">": (c) => c > 0,
  "<": (c) => c < 0,
  "=": (c) => c === 0,
};

// Turn one term into a list of [op, version] comparators that must all hold.
function termToComparators(term) {
  if (term === "*" || term === "x" || term === "X") return [];

  if (term.startsWith("^")) {
    const [maj, min, pat] = parseVersion(term.slice(1)).map(Number);
    return [[">=", [maj, min, pat]], ["<", [maj + 1, 0, 0]]];
  }

  if (term.startsWith("~")) {
    const [maj, min, pat] = parseVersion(term.slice(1)).map(Number);
    return [[">=", [maj, min, pat]], ["<", [maj + 1, 0, 0]]];
  }

  const xr = term.match(/^(\d+)\.(?:[xX*]|(\d+)\.[xX*])$/);
  if (xr) {
    const maj = Number(xr[1]);
    if (xr[2] === undefined) return [[">=", [maj, 0, 0]], ["<", [maj + 1, 0, 0]]];
    const min = Number(xr[2]);
    return [[">=", [maj, min, 0]], ["<", [maj, min + 1, 0]]];
  }

  const m = term.match(/^(<|>|<=|>=|=)?(.*)$/);
  const op = m[1] || "=";
  return [[op, parseVersion(m[2])]];
}

export function satisfies(version, range) {
  const v = parseVersion(version);
  return range.split("||").some((set) => {
    const terms = set.split(" ").filter((t) => t !== "");
    return terms.every((term) =>
      termToComparators(term).every(([op, bound]) => OPS[op](compare(v, bound))),
    );
  });
}
