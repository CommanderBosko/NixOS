---
name: research
description: Web-search a topic, fan out parallel sub-agents to review the top results in depth, and report back a synthesized consensus with source citations. Use when the user says "research X", "/research X", "deep research on X", "look into X thoroughly", or "get me a consensus on X".
---

# Research

Runs a web search on a topic, spawns parallel sub-agents to each review one top result in detail, and synthesizes their findings into a consensus report. (Bucket: Data Enrichment)

## Steps

1. **Parse arguments.** The invocation is `<topic>` or `<topic> <n>`, where `<n>` is an optional result count. Default `n` to 10 if omitted. If no topic is given, ask the user for one.

2. **Search.** Run `WebSearch` on the topic. Collect up to `n` distinct, relevant result URLs from the results. If the search returns fewer than `n` usable results, proceed with what's available and note the shortfall in the final report — don't pad with irrelevant links.

3. **Spawn review agents in parallel.** In a single message, call the `Agent` tool `n` times (one per URL), each with `subagent_type: "general-purpose"` (fresh agent — no shared context needed). Brief each agent with:
   - The research topic/question.
   - The single URL it's responsible for.
   - Instructions to fetch the page (`WebFetch`), read it in full, and extract: the key claims/findings relevant to the topic, the source's overall stance or conclusion, and any notable caveats or evidence quality issues.
   - Instructions to report back concisely (a few sentences of findings + one-line stance), not the raw page content.
   - Instructions that if the page is inaccessible (paywall, login wall, PDF that won't parse, JS-heavy page with no readable content), report that explicitly as "inaccessible: <reason>" rather than guessing or fabricating findings from the URL/title alone.

4. **Collect results.** Wait for all sub-agents to report back. Tally how many of the `n` sources were actually usable vs. inaccessible.

5. **Synthesize a consensus report** and post it directly in chat (no artifact) with:
   - A short overall verdict / majority position on the topic.
   - Notable dissent or minority views, if any, and why they diverge (e.g. different assumptions, outdated info, niche context).
   - A source list: one line per source with its takeaway and a link.
   - A note on coverage, e.g. "8/10 sources reviewed successfully; 2 inaccessible (paywalled)."

6. **Edge cases:**
   - If every source is inaccessible, say so plainly instead of producing a synthesized verdict from nothing.
   - If sources genuinely conflict (not just differ in emphasis), state the conflict directly rather than forcing a false consensus.
