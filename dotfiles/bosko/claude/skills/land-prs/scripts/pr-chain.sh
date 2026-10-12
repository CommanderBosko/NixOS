#!/usr/bin/env bash
# Discover the current repo's open PRs and order them into stacked chains, bottom-up.
# A PR whose base branch is another open PR's head branch is stacked on that PR.
# Read-only: never merges, edits, or deletes anything.
# Usage:
#   pr-chain.sh            — every open PR, grouped into chains
#   pr-chain.sh N [N...]   — only the chain(s) containing these PR numbers ("#N" also accepted)
# Prints one block per chain in merge order (root first): number, head -> base, mergeable,
# DRAFT marker, title. A "FORK:" line means two or more PRs stack on the same parent.
# Exit: 0 ok (including "no open PRs"); 1 a requested PR isn't open; 2 usage error.
set -euo pipefail

for n in "$@"; do
  [[ "$n" =~ ^#?[0-9]+$ ]] || { echo "usage: pr-chain.sh [PR-number ...]" >&2; exit 2; }
done
want="$(printf '%s\n' "$@" | tr -d '#' | jq -Rsc 'split("\n") | map(select(length > 0) | tonumber)')"

prs="$(gh pr list --state open --limit 100 --json number,title,headRefName,baseRefName,mergeable,isDraft)"

missing="$(jq -r --argjson want "$want" '
  [.[].number] as $open
  | $want[] | . as $n | select(any($open[]; . == $n) | not)
  | "#\($n): not an open PR (already merged or closed, or not in this repo)"' <<<"$prs")"

if [[ "$(jq 'length' <<<"$prs")" == 0 ]]; then
  echo "no open PRs"
else
  jq -r --argjson want "$want" '
    . as $all
    | def kids($h): [$all[] | select(.baseRefName == $h)] | sort_by(.number);
      def ind($d): [range($d)] | map("   ") | add // "";
      def walk($p; $d): {p: $p, d: $d, forks: (kids($p.headRefName) | length)},
                        (kids($p.headRefName)[] | walk(.; $d + 1));
      [ $all[] | .baseRefName as $b | select(any($all[]; .headRefName == $b) | not) ]
      | sort_by(.number)
      | map([walk(.; 0)])
      | map(select($want == [] or any(.[]; .p.number as $n | any($want[]; . == $n))))
      | to_entries[]
      | .key as $i | .value as $chain
      | "chain \($i + 1) (lands on: \($chain[0].p.baseRefName))",
        ( $chain | to_entries[] | .key as $k | .value
          | "  \($k + 1). \(ind(.d))#\(.p.number)  \(.p.headRefName) -> \(.p.baseRefName)  \(.p.mergeable)\(if .p.isDraft then "  DRAFT" else "" end)  \(.p.title)" ),
        ( $chain[] | select(.forks > 1)
          | "  FORK: \(.forks) PRs stack on #\(.p.number) (\(.p.headRefName)); their order needs a decision" ),
        ""' <<<"$prs"
fi

if [[ -n "$missing" ]]; then
  echo "$missing"
  exit 1
fi
