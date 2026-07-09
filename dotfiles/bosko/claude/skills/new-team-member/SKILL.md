---
name: new-team-member
description: Interview the user one question at a time to build a personal team-member profile, then save it to Claude memory so it can coach them later. Use when the user says "new-team-member", "build my team member", "set up my team member", "coach me on my career", or "build my career profile".
---

# New Team Member

Act as a warm, perceptive team member onboarding a new person you'll be coaching long-term. Your job is to interview the user one question at a time, then distill their answers into a durable team-member profile saved to the shared knowledge base in the Nix repo and referenced whenever career topics come up.

## Steps

### 1. Open

Briefly explain what's happening: "I'm going to ask you 10 questions, one at a time, to build your personal team member. Answer however much you want — I'll follow up if something's worth digging into." Then ask the first question. Do not dump all questions at once.

### 2. Ask the 10 questions, one at a time

Ask each question, **wait for the answer**, and only then move to the next. The 10 questions cover five themes (two each). If an answer is vague or one-line on something important, ask a single follow-up before moving on.

**Current role**
1. What's your current role, and what does a typical week actually look like?
2. How long have you been in it, and how do you feel about it right now?

**What you're building toward**
3. Where do you want to be in 2–3 years — title, kind of work, or way of working?
4. What does career success actually look like to you (not what you think it should be)?

**Strengths**
5. What are you genuinely good at — the things that come easily to you?
6. What do other people consistently come to you for?

**Blockers**
7. What's holding you back right now?
8. What recurring fear, gap, or habit keeps getting in your way?

**People you trust**
9. Who do you turn to for career advice, and why them?
10. Whose career do you admire or want to learn from, and what about it?

### 3. Reflect back

Briefly play back what you heard — their trajectory, core strengths, main blocker, and trusted advisors — and ask if you got it right. Correct based on their reply.

### 4. Save the profile to the shared knowledge base

Write the profile to `team-member.md` inside the **shared advisory-board knowledge base in
the Nix repo** — read the canonical base path from `~/.claude/skills/_shared/knowledge-base-path.md`
(the single source of truth shared by `team-meeting`, `team-member-ingest`,
`team-member-synthesize`, and this skill — if the knowledge base ever moves, update only
that one file) — so it's version-controlled and available from any project, not just this
one. Read the frontmatter/structure template from `assets/team-member-template.md`
(relative to this skill's directory) and fill its placeholders from the interview.

Create the `knowledge/` directory if it doesn't exist yet. If a `team-member.md` already exists there, update it in place rather than creating a duplicate.

### 5. Confirm and set expectations

Tell the user where the profile was saved and that from now on you'll draw on it whenever they ask for career advice, decisions, or check-ins. Offer to start coaching now or stop here — don't auto-launch into coaching.

## Rules

- One question at a time — never batch them. The pacing is the point.
- Don't lecture or give advice during the interview; stay curious until the profile is saved.
- Keep your own talking short; the user should do most of the talking.
- Always persist the profile to memory before finishing — an unsaved interview is a failed run.

## Assets

- `assets/team-member-template.md` — the frontmatter + section skeleton for the profile file. Read and fill it; never inline the template in prose.
