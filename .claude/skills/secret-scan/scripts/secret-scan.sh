#!/usr/bin/env bash
# secret-scan.sh — read-only scan for leaked secrets in the working tree and git history.
# Tuned for this repo: secrets/ holds sops-ENCRYPTED files (expected), .claude/skills/
# holds documentation that mentions secret patterns (excluded to avoid self-matches).
# Intentional non-secrets (endpoint IP, SSH/WG *public* keys) are NOT flagged.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

# Pathspecs excluded from plaintext-pattern scans:
#   secrets/        — sops-encrypted on purpose
#   .claude/skills/ — skill docs legitimately contain example secret patterns
EXCLUDE=(':!secrets/' ':!.claude/skills/')

# High-signal patterns (tight enough that doc placeholders like "$6$…" don't match).
PRIV_BLOCK='-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
AGE_SECRET='AGE-SECRET-KEY-1[0-9A-Z]{50,}'
PW_HASH='\$6\$[A-Za-z0-9./]{6,}\$[A-Za-z0-9./]{20,}'
WG_INLINE='privateKey[[:space:]]*=[[:space:]]*"[A-Za-z0-9+/]{43}='
GH_TOKEN='ghp_[A-Za-z0-9]{30,}'
AWS_KEY='AKIA[0-9A-Z]{16}'

findings=0
hit() { findings=$((findings+1)); printf '  [!] %s\n' "$1"; }

echo "==> Secret scan — $(git rev-parse --short HEAD) ($(date '+%H:%M:%S'))"

echo
echo "-- 1. Working tree (tracked files, excluding secrets/ and .claude/skills/) --"
for desc_pat in \
  "private key block::$PRIV_BLOCK" \
  "age secret key::$AGE_SECRET" \
  "unix password hash::$PW_HASH" \
  "inline WireGuard private key::$WG_INLINE" \
  "GitHub token::$GH_TOKEN" \
  "AWS access key::$AWS_KEY"; do
  desc=${desc_pat%%::*}; pat=${desc_pat#*::}
  out=$(git grep -nIE "$pat" -- "${EXCLUDE[@]}" 2>/dev/null)
  if [ -n "$out" ]; then hit "$desc:"; echo "$out" | sed 's/^/      /'; fi
done
[ "$findings" -eq 0 ] && echo "  clean"

echo
echo "-- 2. sops file integrity (every secrets/*.yaml must be encrypted) --"
intacterr=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -q 'ENC\[' "$f" && grep -q '^sops:' "$f"; then
    echo "  ok   $f"
  else
    hit "UNENCRYPTED secret file: $f"; intacterr=1
  fi
done < <(git ls-files 'secrets/*.yaml' 2>/dev/null)
[ "$intacterr" -eq 0 ] && echo "  all encrypted"

echo
echo "-- 3. Git history (all commits, excluding secrets/ and .claude/skills/) --"
echo "     (scanning $(git rev-list --all --count) commits; this can take a moment)"
allrev=$(git rev-list --all)
histhit=0
for desc_pat in \
  "private key block::$PRIV_BLOCK" \
  "age secret key::$AGE_SECRET" \
  "unix password hash::$PW_HASH" \
  "inline WireGuard private key::$WG_INLINE"; do
  desc=${desc_pat%%::*}; pat=${desc_pat#*::}
  # shellcheck disable=SC2086
  out=$(git grep -lIE "$pat" $allrev -- "${EXCLUDE[@]}" 2>/dev/null | head -20)
  if [ -n "$out" ]; then
    hit "$desc found in history (commit:path):"; echo "$out" | sed 's/^/      /'; histhit=1
  fi
done
[ "$histhit" -eq 0 ] && echo "  clean"

echo
echo "-- 4. .gitignore coverage (informational) --"
for p in '*.key' '*.pem' '*.age' '.env'; do
  if grep -qF "$p" .gitignore 2>/dev/null; then echo "  ok   ignores $p"; else echo "  note missing $p in .gitignore"; fi
done

echo
if [ "$findings" -eq 0 ]; then
  echo "==> RESULT: clean — no plaintext secrets found in tree or history."
else
  echo "==> RESULT: $findings finding(s) — review above before pushing / publishing."
fi
