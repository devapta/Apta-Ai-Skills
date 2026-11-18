---
name: apta-superskill
description: Apta's office frontend standard for React + TypeScript apps built with Vite, Tailwind CSS, shadcn/ui, Zustand and an Axios service layer. Use when building, reviewing, scaffolding or refactoring such a frontend, including folder structure, components, state, API integration, theming/styling and responsive layout, even if the user doesn't name the skill. Skip it for backend-only work or for projects on a different frontend stack.
---

# Apta Superskill

The office frontend standard for React TypeScript projects. Treat it as the default whenever the project has no stronger local convention.

## Core Stack

- Build tool: Vite
- Framework: React + TypeScript
- Styling: Tailwind CSS
- Component library: shadcn/ui
- State management: Zustand
- HTTP client: Axios through a typed service layer

## How To Use This Skill

1. Inspect the existing codebase first.
2. Where the project's own conventions are consistent and production-ready, follow them.
3. Where they are weak or inconsistent, apply this standard.
4. Organize features by business domain.
5. Build mobile-first, then check desktop, tablet and mobile layouts.
6. Do not add tests unless the user asks for them.
7. Briefly state any assumptions that affect the implementation.

## Reference Routing

Read only the reference file the task needs:

- Folder structure, feature organization, project workflow → [references/frontend-architecture.md](references/frontend-architecture.md)
- Component design, naming, state placement, TypeScript discipline, accessibility, responsive components → [references/component-patterns.md](references/component-patterns.md)
- Data fetching, Axios setup, typed API functions, hooks, error handling → [references/api-layer.md](references/api-layer.md)
- Typography, colors, shadcn theme, visual direction, spacing, responsive styling → [references/style-guide.md](references/style-guide.md)

## Default Rules

- Use TypeScript. Do not create `.jsx` files.
- Avoid `any` unless there is a strong reason, and narrow the value quickly.
- Use named exports for components.
- Keep one component per file, unless a tiny helper only makes sense inside that file.
- Use semantic HTML for interactive elements.
- Avoid premature abstraction. Promote shared code only once a second real use appears.
- Components that touch data handle loading, error, empty and success states.
- Components and hooks never import Axios directly; they go through the API layer.
- Endpoint strings live in feature API files, not in components.
- Use Tailwind and shadcn theme variables instead of hardcoded visual values in components.
- Use Lucide icons when the project uses shadcn/ui.

## Output Expectations

When implementing frontend work:

- Keep edits scoped to the requested feature.
- List the files you created or changed.
- State assumptions such as route names, endpoint paths or mock data.
- If a dev server is needed, start it and give the local URL.
- If you can't run verification, explain why.
