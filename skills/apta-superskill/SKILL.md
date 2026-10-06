---
name: apta-superskill
description: Use when building, reviewing, or refactoring React TypeScript frontend projects with Vite, Tailwind CSS, shadcn/ui, Zustand, and an Axios service layer. Apply this for office frontend architecture, component structure, API integration, responsive UI, and modern professional visual design.
---

# Apta Superskill

This skill defines the office frontend standard for React TypeScript projects. Use it as the default convention when a project does not already have a stronger local pattern.

## Core Stack

- Build tool: Vite
- Framework: React + TypeScript
- Styling: Tailwind CSS
- Component library: shadcn/ui
- State management: Zustand
- HTTP client: Axios through a typed service layer

## How To Use This Skill

1. Inspect the existing codebase first.
2. Prefer existing project conventions when they are consistent and production-ready.
3. If the codebase has weak or inconsistent conventions, apply this standard.
4. Keep features organized by business domain.
5. Build mobile-first and verify desktop, tablet, and mobile layouts.
6. Do not add tests unless the user asks for tests.
7. Briefly state any assumptions that affect implementation.

## Reference Routing

Read only the reference file needed for the task:

- For folder structure, feature organization, and project workflow, read `references/frontend-architecture.md`.
- For React component design, naming, state placement, TypeScript discipline, accessibility, and responsive component behavior, read `references/component-patterns.md`.
- For data fetching, Axios setup, typed API functions, hooks, and error handling, read `references/api-layer.md`.
- For typography, colors, shadcn theme choices, visual direction, spacing, and responsive styling, read `references/style-guide.md`.

## Default Rules

- Use TypeScript. Do not create `.jsx` files.
- Avoid `any` unless there is a strong reason and the value is narrowed quickly.
- Use named exports for components.
- Keep one component per file unless a tiny helper component is only meaningful inside that file.
- Use semantic HTML for interactive elements.
- Avoid premature abstraction. Promote shared code only after a second real usage appears.
- Components must handle loading, error, empty, and success states when data is involved.
- Components and hooks must not import Axios directly. Use the API layer.
- Keep endpoint strings in feature API files, not in components.
- Use Tailwind and shadcn theme variables instead of hardcoded visual values inside components.
- Use Lucide icons when the project uses shadcn/ui.

## Output Expectations

When implementing frontend work:

- Keep edits scoped to the requested feature.
- Mention created or changed files.
- Mention assumptions such as route names, endpoint paths, or mock data.
- If a dev server is needed, run it and provide the local URL.
- If verification cannot be run, explain why.
