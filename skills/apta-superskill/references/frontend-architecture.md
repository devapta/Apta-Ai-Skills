# Frontend Architecture

Use this standard for React TypeScript projects when no stronger local convention exists.

## Feature-Based Folder Structure

Organize by feature or business domain, not by file type.

```txt
src/
├── app/
│   ├── App.tsx
│   ├── router.tsx
│   └── providers.tsx
├── features/
│   └── <feature-name>/
│       ├── components/
│       ├── hooks/
│       ├── api/
│       ├── store/
│       ├── types.ts
│       └── index.ts
├── components/
│   ├── ui/
│   └── shared/
├── stores/
├── lib/
│   ├── api/
│   └── utils.ts
├── hooks/
├── types/
└── styles/
```

## Placement Rules

- Code used by one feature lives inside that feature.
- Promote to `components/shared`, `hooks`, or `stores` only after a second feature needs it.
- Keep app shell concerns in `src/app`.
- Keep shadcn primitives in `src/components/ui`.
- Keep reusable cross-feature UI in `src/components/shared`.
- Keep app-level Zustand stores in `src/stores`.
- Keep feature-level Zustand stores in `src/features/<feature>/store`.

## Responsiveness

Every project and component must work cleanly across desktop, tablet, and mobile.

- Build mobile-first with Tailwind base classes.
- Add `sm`, `md`, `lg`, and `xl` overrides only as needed.
- Convert dense desktop tables into cards or simplified rows on mobile.
- Convert sidebars into drawers on mobile.
- Stack multi-column layouts on smaller screens.
- Avoid desktop-only layout assumptions.

## Workflow

1. Clarify the feature domain.
2. Inspect local conventions before creating files.
3. Scaffold files under the correct feature folder.
4. Build focused components.
5. Add API layer and hooks only when server data is involved.
6. Style using the style guide.
7. Verify responsive behavior.
8. Note assumptions briefly.

## Testing

Testing is out of scope for this skill. Do not generate test files or testing setup unless the user explicitly asks.
