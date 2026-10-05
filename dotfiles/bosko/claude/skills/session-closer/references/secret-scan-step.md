# STEP 5B — secret-scan detail

Load this at STEP 5B. Full present/absent branching for the pre-commit secret pass.

Before staging anything, run a public-safety pass over **every file committed since
session-closer's own last run** — not just the README, and not just this session's own
new commits. STEP 1's baseline (`git log | grep 'chore(session):' | head -1`, or
`--since=midnight` on a first run) is the same scope: if that baseline spans several
unclosed prior sessions, this scan covers all of them too, since nobody secret-scanned
those commits at the time either. Check whether
`<repo-root>/.claude/skills/secret-scan/SKILL.md` exists.

- **If it exists**, **invoke `secret-scan`**. It takes no arguments and unconditionally
  scans the whole working tree plus the full git history — so one invocation already
  covers every commit since the baseline (and everything before it). Don't re-scope it to
  "just the README" or "just the changed files"; that undersells what it actually checks
  and what this gate is for. If it flags something in *any* file this session's commits
  touched (not only README prose), fix it at the source per the skill's own remediation
  guidance — move a leaked secret into sops, encrypt a plaintext `secrets/*.yaml`, or
  rewrite history for something already pushed — rather than just rewording the README
  around it.
- **If it's absent**, use **AskUserQuestion** to offer: **create one now** (runs
  `/create-secret-scan` to generate a project-tuned scan, then use it for this pass —
  recommended) or **skip with a manual pass** (a one-off grep for common secret patterns —
  private key headers, `password`/`token`/`api_key`/`secret` literals — across every file
  changed since the baseline, for this close-out only). Either way, note in the session
  summary which path was taken so the gap doesn't silently repeat next close-out.

Note any finding or redaction in the session summary regardless of which path was taken.
