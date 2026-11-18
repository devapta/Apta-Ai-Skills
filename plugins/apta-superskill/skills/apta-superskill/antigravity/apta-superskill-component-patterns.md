# Component Patterns Rule

Apply this rule when creating or refactoring React components.

## Naming

- One component per file.
- Component files use PascalCase, for example `ProductCard.tsx`.
- Use named exports.
- Avoid default exports for components.
- Hooks are prefixed with `use`.
- Props interfaces are named `<ComponentName>Props`.

```tsx
interface ProductCardProps {
  product: Product;
  onSelect?: (id: string) => void;
}

export function ProductCard({ product, onSelect }: ProductCardProps) {
  return <button onClick={() => onSelect?.(product.id)}>{product.name}</button>;
}
```

## Component Shape

- Use functional components with hooks.
- Do not use class components.
- Keep data ownership and presentational rendering separate when practical.
- Extract repeated JSX into smaller components.
- Extract complex state or data logic into custom hooks.

Feature components that fetch data must handle:

- Loading state
- Error state
- Empty state
- Success state

## State Placement

Choose the smallest useful state scope:

1. Local state with `useState`.
2. Lifted state in a shared parent.
3. Feature-scoped Zustand store.
4. App-level Zustand store.

Use Zustand selectors:

```tsx
const filters = useProductStore((state) => state.filters);
```

Avoid reading the whole store unless needed.

## TypeScript

- Avoid `any`.
- Use `unknown` and narrow it when needed.
- Derive types from one source of truth where possible.
- Prefer `interface` for props and object shapes.
- Prefer `type` for unions and utility compositions.

## Performance

Do not add `React.memo`, `useMemo`, or `useCallback` by default. Use them only for measured or obvious performance needs.

## Accessibility

- Use semantic HTML.
- Use `<button>` for clickable actions.
- Do not use `<div onClick>` for controls.
- Preserve focus states.
- Label form controls.
- Prefer shadcn primitives for accessible behavior.

## Responsiveness

Every layout-bearing component must work on mobile, tablet, and desktop.
