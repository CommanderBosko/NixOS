# Manager Profile

The `manager` agent's model of how this user actually decides, works, and communicates — mined from Claude Code session transcripts across every project with history, and cross-corroborated where the same pattern showed up more than once. Distilled traits only; no raw transcript content or verbatim sensitive/financial/family detail lives here.

**Last refreshed:** 2026-08-30 (initial build — full mining pass across NixOS, bitburner, Codingame/Mad-Pod-Racing, FamDash, farmer, FinanceGuru, home-improvement, home-lab, Legions, MyColony-Rebuild, random-searches, screeps).

## 1. Decision-making style

- **Picks the durable/thorough path when it affects ongoing correctness, reliability, or shared code** — full clean removal over a partial patch, refactoring duplication into a shared module the moment it's spotted, chasing a root cause through every layer instead of stopping at the first plausible fix, building a full simulation/A-B harness before trusting a metric, verifying a game-mechanic assumption against the primary source before building on it.
- **Thoroughness is targeted, not blanket.** Historical/low-stakes data gets left alone rather than backfilled; a hard budget cap wins over squeezing in one more feature; speculative work is skipped until a real trigger arrives. The axis is *"does this affect ongoing correctness or someone's experience going forward,"* not *"is more effort always better."*
- **Sometimes rejects every offered option and reframes the actual constraint free-text** rather than picking from a menu — expects genuine engagement with a question, not just a checkbox answer.
- **Comfortable explicitly deferring** a decision under real uncertainty rather than being rushed into a choice ("stop here, don't decide now" on a disruptive break) — deferring is itself a legitimate decision, not a failure to decide.
- **Chooses the harder-to-build but more honest measurement over a convenient shortcut** (a real comparable baseline over a simple usage flag; a near-certain win threshold over a merely expected-value-positive one when the automation runs unattended).

## 2. Risk tolerance & caution triggers

- **The strongest, most consistent "stop and reconsider" trigger is anything that risks stalling unattended progress or producing a wrong/fabricated number.** Efficiency loses to correctness and continuity every time this trade-off has come up.
- **Never present a fabricated or unverifiable number/claim as fact.** When data couldn't be verified (blocked price-scraping, a mathematically meaningless aggregate, low-quality SEO sources), the answer was to say so plainly — show nothing, or flag the gap — not to synthesize a confident-sounding guess.
- **Caution scales with actual stakes and blast radius, not blanket conservatism.** Full autonomy is granted readily over their own infrastructure; disposable/sandboxed environments get a shrug ("it's a VM"); identity/account separation and cross-repo boundaries (routing a NixOS-level need to the NixOS agent instead of letting a game-project agent touch system config) get real caution.
- **Standing complexity is declined for rare/one-off problems** — but not reflexively; given a concrete cost/benefit (three specific downsides of skipping a fix), a manual workaround is accepted. Recurring automation is welcomed for genuinely recurring needs and declined for transient ones ("I'll just check myself" on a one-off outage).
- **Speculative/preemptive infrastructure is consistently skipped** until a real trigger exists — extra tooling, legal/business setup, multi-version pinning, third-party MCP integrations of unconfirmed value.
- **Money-handling correctness is a hard, non-negotiable bar** wherever it appears: exact-decimal arithmetic end to end, mandatory audit gates before committing anything money- or security-sensitive, precise foreign-key relationships over fragile heuristics once a real collision is found.
- **Tolerates ordinary tooling flakiness calmly** — a stalled background agent gets a retry, not a demand for new monitoring infrastructure.

## 3. Values & priorities

- **Verification before shipping is close to universal and non-negotiable** — config changes gated on a clean dry-run/deep-eval across every affected host, feature work gated on tests + smoke + visual verification, CI watched to actual completion rather than trusted from a local pass, an async code-review gate awaited before a commit ships.
- **Prefers matching existing convention over inventing a new structure** when both are viable options.
- **Keeps standing complexity low even while being rigorous about correctness** — added complexity has to earn its keep with an explicit trade-off, not arrive by default.
- **Wants a durable, file-backed record of decisions and state**, not just chat output — explicit requests to persist memory "so we can pick up exactly where we left off," and a preference for saved reports over ephemeral ones.
- **Single-responsibility discipline in both code and tooling** — skills and roles are scoped to exactly one job, with explicit "this is not X" boundaries, even when blurring the line would be more convenient.
- **Wants a verdict, not a raw list** — even outside code, research is expected to end in an opinionated recommendation, and competing conclusions get reconciled into one source of truth rather than left as parallel documents.
- **Temporary workarounds are fine, but must be labeled and tracked as temporary** — never silently treated as permanent.

## 4. Communication & reporting style

- **Overwhelmingly terse and imperative** — one-line instructions and one-word confirmations ("commit it," "continue," "correct") are the norm once groundwork is laid; the agent is trusted to chain multiple steps from a compact instruction.
- **Explicit standing correction on file**: be vocal about intent *before* acting — one sentence of what's about to happen and why, before edits or sub-agent spawns — not a silent batch of changes followed by a summary.
- **Real decisions are expected to route through structured choices with a clearly marked recommended option** — this is the lived pattern everywhere, not just a stated rule. The recommended option is taken often, but overridden deliberately when their own read is clearer, and sometimes bypassed entirely with a free-text reframe.
- **Wants plain pass/fail over hedged narrative**, and wants gaps, blocked verification, or low-confidence findings stated outright rather than smoothed over or silently dropped.
- **Comfortable with an agent surfacing its own mistake transparently mid-task** rather than quietly fixing it and saying nothing.

## 5. Technical philosophy

- **Root-cause fixes over quick patches is the dominant mode across every project** — bugs get traced through as many layers as it takes; "should be fixed now" isn't accepted until the actual trigger is confirmed gone.
- **Reflexive parallel sub-agent fan-out for independent work is baseline practice**, exercised even in low-stakes or non-code contexts, not an occasional escalation.
- **Skills/reusable workflows are the default over ad hoc steps** — created once a manual loop has genuinely repeated, and deliberately scoped project-local vs. global based on how portable the workflow actually is.
- **New or higher-risk autonomous flows start supervised and graduate to unattended once trust is earned** — an established, reused idiom (training-mode toggles), not invented per-project.
- **Strict about reproducible, declared environments** until the ceremony stops earning its keep, then simplified without sentimentality.

## 6. Standing rules for a delegate acting on this user's behalf

(Highest-confidence section — sourced directly from the session that defined this very agent.)

- Full autonomy is deliberately granted, but paired with hard, non-overridable limits: never spend money or provision billable resources; never touch secrets/credentials; never destroy data or force-push/rewrite history; never push directly to a default branch; never execute privileged/live-system commands directly (propose via PR instead, even where passwordless sudo exists); never make mutating calls through connected MCP servers.
- The verification bar should match each project's own existing method rather than impose one uniform standard everywhere.
- Even under full autonomy, work still lands via branch + PR — human review is never skipped because the agent is "trusted."
- A profile or config artifact like this one requires the user's own read-through and sign-off before its *first* push to a public repo — but not on every later refresh; once vetted, ongoing trust is extended without re-litigating each update.

## 7. Shared-stakes handling (family / household)

- On family-facing or household-shared projects, routine/technical scoping decisions are still made solo, in real time, with no visible in-session consultation.
- But bigger, more disruptive changes that alter what family members actually experience are explicitly deferred to their expressed want, not decided unilaterally.
- Family or household data itself gets elevated protective handling on reflex — gitignored, backed up before anything touches it, called out by name as real family data — even absent any formal secret.
- **Net rule for `manager`**: decide solo on scope and implementation within a family/shared project; surface anything that changes another person's experience or needs their buy-in via `AskUserQuestion` instead of deciding it alone.
