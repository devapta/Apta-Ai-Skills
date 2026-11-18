# Component Patterns

Use this guide before generating or refactoring React components.

## File And Naming Conventions

- One component per file.
- Component file names use PascalCase, for example `ProductCard.tsx`.
- Use named exports, for example `export function ProductCard()`.
- Avoid default exports for components.
- Hooks are prefixed with `use`, for example `useProductFilters.ts`.
- Props interfaces are named `<ComponentName>Props` and placed directly above the component.

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

Use functional components with hooks. Do not use class components.

A component should either own data or render UI from props. Avoid mixing data fetching, deep rendering logic, and business logic in one large file.

- Extract repeated JSX into smaller components.
- Extract complex state or data logic into custom hooks.

Preferred feature component shape:

```tsx
export function ProductList() {
  const { data, isLoading, error } = useProductList();

  if (isLoading) return <ProductListSkeleton />;
  if (error) return <ErrorState message="Failed to load products" />;
  if (!data?.length) return <EmptyState message="No products yet" />;

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {data.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
```

Loading, error, empty, and success states are part of the component contract.

## Composition

Prefer composition over many boolean props.

- Good: smaller components composed together.
- Good: compound components similar to shadcn primitives.
- Avoid: one large component with many toggles like `showHeader`, `showFooter`, `isCompact`, and `variant`.

## State Placement

Choose the smallest useful state scope:

1. Local state with `useState`.
2. Lifted state in a shared parent.
3. Feature-scoped Zustand store.
4. App-level Zustand store.

Use Zustand only for state that is genuinely shared across a feature or the app.

When reading from Zustand, use selectors:

```tsx
const filters = useProductStore((state) => state.filters);
```

Avoid reading the full store unless the component truly needs it.

## TypeScript Discipline

- Avoid `any`.
- Use `unknown` and narrow it when the shape is not known.
- Derive types from a single source of truth where possible.
- Prefer `interface` for props and object shapes.
- Prefer `type` for unions and utility compositions.
- Keep style consistent within a feature.

## Performance

Do not add `React.memo`, `useMemo`, or `useCallback` by default.

Use them only when there is a real performance reason, such as large lists, expensive computation, or measured re-render problems.

## Accessibility

- Use semantic HTML.
- Use `<button>` for clickable actions.
- Do not use `<div onClick>` for controls.
- Preserve focus states.
- Add labels for form controls.
- Use shadcn behavior instead of rebuilding accessible primitives manually.

## Responsiveness

Before finishing a component, check mobile, tablet, and desktop behavior. Layout-heavy components should have stable responsive constraints, not accidental wrapping.
