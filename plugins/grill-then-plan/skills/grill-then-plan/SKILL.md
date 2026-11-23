---
name: grill-then-plan
description: Use when the user wants to work through a feature or product idea in an interview and then save an ordered implementation plan in the repository.
---

# Grill then plan

## Run the interview first

Invoke `grill-with-docs` on the user's idea as the first phase. On hosts that load skills by file, read its installed SKILL.md and follow it, including its `grilling` and `domain-modeling` instructions. If a required skill is unavailable, identify the missing dependency and pause. Carry the interview across turns until the decisions that affect scope, dependencies and acceptance checks are settled or explicitly deferred. Use the domain terms and decision records established during the interview.

## Write the plan

Inspect the target repo's existing plans before writing. Follow its established locations when present. The agent-6 layout uses three artifacts:

- **docs/plan.md** describes the agreed product or feature from the user's perspective. Cover who uses it, what they can do, and the constraints that shape it. For an existing product brief, update the relevant section.
- **docs/plans/00-README.md** explains how to implement one step at a time after its prerequisites have landed. Include an ordered table with the step number, a relative link to its file, and the result. Record decisions shared across steps here and link relevant glossary entries or ADRs.
- **docs/plans/NN-slug.md** describes one independently verifiable increment that leaves the project working. Append new steps using the next available number in sequence. Preserve existing step numbers and links.

Start each step with its number, title and a relative link to the index. Use **Goal**, **Depends on**, **Scope**, **Out of scope**, **Domain terms**, **Acceptance checks**, and **Notes for the agent** as the working outline. Name prerequisite steps by number. Describe observable checks that a later implementer can run, including relevant failure cases. Use the notes for concrete repo entry points and decisions the implementer will need.

Before handing off, verify that each agreed outcome has a step and an acceptance check, dependencies point to earlier steps, and relative links resolve. Return links to the brief and index. Implementation is a separate request.
