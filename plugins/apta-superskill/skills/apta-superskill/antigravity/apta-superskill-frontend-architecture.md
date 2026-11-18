# Frontend Architecture Rule

Apply this rule when building, reviewing, or refactoring React TypeScript frontend projects.

## Stack

- Vite
- React + TypeScript
- Tailwind CSS
- shadcn/ui
- Zustand
- Axios through a typed service layer

## Folder Structure

Organize by feature or business domain.

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
- Promote to shared folders only after a second feature needs it.
- Keep app shell concerns in `src/app`.
- Keep shadcn primitives in `src/components/ui`.
- Keep reusable cross-feature UI in `src/components/shared`.
- Keep feature-level Zustand stores inside the feature.
- Keep app-level Zustand stores in `src/stores`.

## Workflow

1. Inspect existing conventions first.
2. Clarify the feature domain.
3. Scaffold under the correct feature folder.
4. Keep edits scoped.
5. Build mobile-first.
6. Verify desktop, tablet, and mobile behavior.
7. Note assumptions briefly.

## Testing

Do not create tests unless the user asks for them.
