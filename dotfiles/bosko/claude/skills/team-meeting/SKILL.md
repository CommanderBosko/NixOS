---
name: team-meeting
description: Recommend 2 experts who'd make a phenomenal advisory board for the user's specific situation, biased toward YouTube, with why each fits and their 5 best pieces of content to ingest. Use when the user says "team-meeting", "convene my advisory board", "who should advise me", "recommend advisors", or "hold a team meeting".
---

# Team Meeting

Convene the user's personal advisory board. Based on everything you know about them — especially their saved team-member profile — recommend **exactly 2 real, living-or-famous experts** who would make a phenomenal advisory board for their specific situation, and give them a concrete plan for learning from each.

## Steps

### 1. Ground yourself in who the user is

Read the user's profile from the shared advisory-board knowledge base in the Nix repo — `/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/team-member.md`. Note their current role, what they're building toward, strengths, blockers, and trusted advisors.

- If that file doesn't exist, say so and suggest running the `new-team-member` skill first — then offer to proceed using whatever you already know about them from the conversation and memory.
- If any advisor profiles already exist under `knowledge/<person-slug>/team-member.md`, factor in who's already on the board so you don't just repeat them.
- Weave in anything else you know about the user (memories, the work in this repo, things they've told you).

### 2. Pick exactly 2 experts

Choose 2 experts whose expertise maps directly onto **this user's specific situation** — their goals and blockers, not generic advice. Favor variety: don't pick two people who'd give the same advice.

- **Bias toward experts with a strong YouTube presence**, so the user can actually ingest their thinking for free. Prefer someone with talks, interviews, a channel, or a rich back-catalogue of video over someone who only writes.
- They must be real and identifiable by name. No composites, no "a generic mentor figure."

### 3. Present the advisory board

For **each** of the 2 experts, give:

1. **Who they are** — name and a one-line identity (what they're known for).
2. **Why they fit** — 2–4 sentences tying their expertise explicitly to *this user's* role, goals, or blockers. Reference specifics from the profile.
3. **Their 5 best pieces of content to ingest** — a numbered list of 5 specific, high-signal items, biased toward YouTube (talks, interviews, channel series). For each item give the title and the format/platform, and one short clause on what the user will get from it. Prefer concrete, findable titles over vague "watch their channel."

Keep it focused and skimmable — two clear sections, one per advisor.

### 4. Close

Briefly invite the user to react: do these two resonate, or should you swap one for a different angle? Offer to go deeper on either advisor's material if they want.

## Rules

- Exactly 2 experts — not 1, not 3.
- Tie every recommendation to the user's actual situation; never give a generic "great people to follow" list.
- Bias hard toward YouTube-available content so the user can start today for free.
- Be honest about uncertainty: if you're not sure a specific video title exists, describe the content precisely rather than inventing an exact title you can't stand behind.
- Don't fabricate facts about the user — if the profile is thin, say what you're inferring.
