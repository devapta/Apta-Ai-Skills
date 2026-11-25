---
name: grill-then-plan
description: Interview the user about a supplied spec in grouped rounds, then write numbered implementation steps with repository paths, focused code snippets, and tests.
---

# Grill then plan

## Interview from the supplied spec

Invoke `grill-with-docs` first, using the user's Markdown file or chat message as the spec. A pasted spec is sufficient. Treat a supplied file as read-only and keep chat requirements in the conversation. On file-based hosts, read the installed skill and follow its `grilling` and `domain-modeling` instructions. If a dependency is unavailable, identify it and pause.

For this workflow, use grouped rounds in place of the single-question cadence in `grilling`. Read the spec and inspect the repo first. Ask about decisions the user owns, with a recommended answer and a short reason for each. Group questions the user can answer independently. Let the topic determine the round size, including ten or more questions when useful. Hold a dependent question until the answer that shapes it is known.

Prefer an interactive question form when available. If a round exceeds the form's capacity, present the complete round as numbered questions in chat so the user can answer together. Use the same chat format on hosts without forms. Wait for the answers, then use them to shape the next round. Carry forward resolved terminology and architectural decisions through the delegated skill. Summarize the agreed scope and explicit deferrals, and proceed when the user confirms.

## Write the index and step files

Use the target repo's existing plan directory and numbering. The default index is **docs/plans/00-README.md**, with one **docs/plans/NN-slug.md** per independently verifiable increment. Preserve existing numbers and links when extending a plan. The planning outputs are the index and steps. Link the supplied spec from the index if it is a file. For a chat spec, carry its requirements directly into the relevant steps. Do not generate or update a product brief or spec file.

Give the index an ordered table with each step's number, relative link and observable result. Identify shared decisions and link relevant glossary entries or ADRs. Each step should leave the project working once its prerequisites have landed.

## Make each step implementable

Write each step so an implementer can start with that file and its linked prerequisites. Include all of the following:

- **Goal and dependencies.** State the outcome, prerequisite step numbers, and where this step ends. Link back to the index.
- **Starting point.** Inspect the actual entry points. Give repo-relative paths and relevant symbols, explain today's behavior, and identify files to create or modify. Mark proposed paths and symbols as new, including anything supplied by a future prerequisite.
- **Design.** Walk through the changes in execution or implementation order. Include a focused, language-tagged code snippet showing the contract or behavior the implementer needs to get right, such as a function signature and its call site, a state transition, or a configuration block. Place the snippet beside the path where it belongs and use the project's real types and conventions.
- **Tests.** Name the test file and the interface or entry point under test. Give the setup, action and expected result for the main behavior and relevant failure or boundary cases. Provide the project's test command. For a manual check, give the exact action and visible result.
- **Done when.** List observable acceptance checks that tie the implementation and tests to the agreed requirement.

Before handoff, trace every in-scope requirement to a step and an acceptance check. Check existing paths and symbols against the repo, resolve relative links, and verify that prerequisites precede their consumers. Return a link to the index.
