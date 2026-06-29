---
name: ask-team
description: Pose a question to the user's advisory board — each team member answers in their own voice from their synthesized profile, then flag where they agree and disagree and synthesize what the user should actually do. Use when the user says "ask-team", "ask my team", "ask the board", "what would my advisors say", or "convene the team on [question]".
---

# Ask Team

Put a question to the user's advisory board and let each member weigh in **in their own voice**, then cut through to a recommendation. The board is the set of synthesized advisor profiles in the shared knowledge base in the Nix repo:

```
/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/<person-slug>/team-member.md
```

(The top-level `knowledge/team-member.md` is the **user's own** profile — context about who's asking, not a board member.)

## Arguments

Parse from the user's request:

- **`<question>`** (optional in the trigger) — the question or topic to put to the board, e.g. *"ask the team whether I should niche down"*. It's often embedded in the invocation phrase; if it's absent, ask for it conversationally (see Step 1) rather than guessing.

## Steps

### 1. Get the question

If the user didn't include a question in the invocation, prompt: **"What do you want to put to the team?"** Wait for it.

### 2. Load the board

- List the advisor profiles: every `knowledge/<person-slug>/team-member.md` (each subdirectory is one advisor). Read each one — core ideas, vocabulary, stances, recurring stories.
- Also read the user's own profile at `knowledge/team-member.md` for context on their situation (role, goals, blockers), so the answers and synthesis stay specific to them.
- If **no advisor profiles** exist yet, say so and point the user to `team-meeting` (to pick advisors) and `team-member-ingest` (to build each advisor's profile) first. Don't invent a board.

### 3. Each member gives their take

For **each** advisor, write a short section headed with their name. Answer the user's question **as that person would** — channel their core ideas, reach for their signature vocabulary, take the stances their profile records, and lean on their recurring stories/examples where they'd naturally apply. Keep each take tight and distinct; don't let everyone blur into the same generic advice.

- Stay true to the profile. If the question falls outside what their material covers, say what they'd *likely* say and flag it as extrapolation rather than fabricating a confident position.

### 4. Flag agreement and disagreement

After the individual takes, add a short **"Where they line up / where they split"** section:

- **Agree:** the points of genuine consensus across the board.
- **Disagree:** the real tensions — who's pulling which way and *why*, rooted in their differing frameworks.

### 5. Synthesize what to actually do

Close with **"What I'd actually do"** — a decisive, concrete recommendation for *this user's* situation (using their own profile). Don't just average the advisors; weigh the disagreements, say which view you find most applicable here and why, and give a clear next step or two.

## Rules

- Use only the advisors whose profiles exist in the repo — don't add famous names who aren't on the board.
- Each voice must be distinct and faithful to its profile; flag extrapolation rather than inventing positions.
- The final synthesis is your own judgment for the user's situation — take a position, don't hedge into a bland summary.
- Keep it readable: one clear section per advisor, then the agree/disagree, then the recommendation.
