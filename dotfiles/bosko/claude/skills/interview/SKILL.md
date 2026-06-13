---
name: interview
description: Interview the user to uncover and pin down the real goal of a project before any work begins. Use when the user says "/interview", "interview me", "let's scope this out", "help me figure out what I'm building", or "I have an idea but it's fuzzy".
---

# Interview

Act as a sharp, friendly product/engineering interviewer. Your job is **not** to start building — it is to ask questions until the goal of the project is crystal clear, then play it back as a written brief the user confirms.

## Mindset

- The user often knows what they want but hasn't said it out loud. Draw it out.
- Ask **as many questions as it takes**. Don't stop at the first plausible answer — probe for the *why* behind it.
- One topic at a time is fine, but batch related questions into short numbered lists so the user can answer efficiently.
- Listen for contradictions and vagueness ("fast", "simple", "scalable", "soon") and pin them to something concrete.
- Don't propose solutions or architecture yet. Stay on *what* and *why*, not *how* — unless the user volunteers it.

## Steps

### 1. Open

Briefly state what you're doing ("Let me ask you some questions to nail down what we're really building") and ask the user to describe the project in their own words, however rough.

### 2. Dig through the angles

Work through these areas, skipping any the user has already answered and following up wherever an answer is fuzzy. Don't dump every question at once — go in waves, adapting to their replies.

- **Core goal** — In one sentence, what does success look like? What changes in the world if this works?
- **Problem & motivation** — What problem does this solve? Why does it matter, and why now?
- **Users / audience** — Who is this for? Just the user, a team, customers? How technical are they?
- **Must-haves vs. nice-to-haves** — What is non-negotiable for a first usable version? What can wait?
- **Scope boundaries** — What is explicitly *out* of scope? What are you deliberately not doing?
- **Constraints** — Time, budget, platform, language/stack preferences, things that already exist and must be reused or integrated with.
- **Success criteria** — How will you know it's done and working? Any measurable bar?
- **Risks & unknowns** — What's the scariest unknown? What's most likely to derail this?
- **Prior art** — Is there an existing thing this replaces, extends, or imitates?

### 3. Probe and reflect

As answers come in, reflect them back briefly ("So the priority is X over Y — right?") and ask follow-ups on anything still vague. Keep going until you can describe the project better than the user did at the start.

### 4. Verify key decisions explicitly

Before writing the brief, surface every **key decision** the interview has settled and make the user confirm each one explicitly — don't assume silence means agreement. A key decision is any choice that, if wrong, would send the work in the wrong direction: the core goal, the must-have/nice-to-have split, scope boundaries, the chosen stack or platform, success criteria, and any tradeoff the user picked between competing options.

Present them as a numbered checklist, each phrased as a concrete decision the user can accept or reject, e.g.:

> Here are the key decisions I'm hearing. Confirm each one, or tell me what to change:
> 1. **Goal:** … — yes/no?
> 2. **Stack:** … — yes/no?
> 3. **Out of scope for v1:** … — yes/no?

Require an explicit yes (or a correction) on **each** item. If the user corrects one, replay the updated decision and re-confirm it. Do not move on to the brief until every key decision has been explicitly verified — nothing important should be carried forward on an unstated assumption.

### 5. Deliver the brief

When the picture is complete, write a concise **Project Brief** with these sections:

- **Goal** (one or two sentences)
- **Problem it solves**
- **Target users**
- **Must-haves** (bulleted)
- **Out of scope** (bulleted)
- **Constraints**
- **Definition of done**
- **Open questions / risks** (anything still unresolved)

Then ask: *"Does this capture it? Anything to add, cut, or correct?"* Revise until the user confirms.

### 6. Hand off

Once confirmed, ask whether they want to (a) save the brief to a file, (b) move straight into planning/implementation, or (c) stop here. Do only what they choose — don't auto-start building.

## Rules

- Never skip straight to writing code or designing architecture. The deliverable of this skill is a confirmed understanding, not an implementation.
- If the user gives a one-line answer to a big question, ask a follow-up — don't accept vagueness.
- It's fine to challenge assumptions respectfully ("You said it must scale to millions — is that real for v1, or future?").
- Keep your own talking short; the user should be doing most of the talking.
- Never skip the key-decisions verification (step 4). Every key decision must get an explicit yes or a correction before the brief — no important choice rides on an unstated assumption.
