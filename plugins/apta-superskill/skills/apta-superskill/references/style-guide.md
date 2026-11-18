# Style Guide

Use this guide before styling a component, page, or app shell.

## Visual Direction

Target a modern, elegant, professional, and lightly futuristic interface. It should feel like a serious product from a team that cares about design, not a default shadcn template with colors swapped.

## Typography

Use three fonts with clear roles:

| Font | Role |
| --- | --- |
| Poppins | Headings and display text |
| Plus Jakarta Sans | UI text, body copy, labels, buttons, inputs, tables |
| Lato | Secondary text, captions, metadata, long descriptions, footer text |

Load fonts through `@fontsource` or Google Fonts. Map them into Tailwind font families:

- `font-heading`
- `font-sans`
- `font-secondary`

Keep a disciplined type scale. Avoid one-off font sizes.

## Color System

Use the brand colors as foundation:

```txt
ink:  #171615
mist: #EEF0F2
```

Use a neutral ramp for borders, surfaces, muted text, hover states, disabled states, and dark surfaces:

```txt
neutral-950: #171615
neutral-900: #232220
neutral-700: #4A4846
neutral-500: #726F6C
neutral-300: #A8A5A1
neutral-100: #EEF0F2
neutral-50:  #F8F9FA
```

Use one accent color sparingly:

```txt
accent: #7A1E2B
accent-foreground: #FFFFFF
```

Use accent for primary CTAs, active states, focus rings, and key highlights. Do not scatter it everywhere.

## Semantic Colors

Use standard meanings:

- Success: `#16A34A`
- Warning: `#D97706`
- Error: `#DC2626`
- Info: `#2563EB` or `#EA580C` depending on context

## shadcn Theme

Wire colors into shadcn CSS variables in `index.css`. Do not hardcode hex values throughout components.

Prefer theme variables such as:

- `--background`
- `--foreground`
- `--primary`
- `--primary-foreground`
- `--muted`
- `--muted-foreground`
- `--border`
- `--destructive`
- `--ring`

## Layout And Spacing

- Use generous whitespace without making operational screens sparse.
- Use subtle depth through borders and light shadows.
- Use restrained corner radius for professional B2B interfaces.
- Avoid decorative visuals that do not help the task.
- Keep repeated content scannable.
- Keep dense data screens quiet and functional.

## Motion

Use small, fast transitions for hover, focus, and page changes. Avoid decorative animation unless it improves clarity.

## Icons

Use one icon set consistently. Lucide is the default when using shadcn/ui.

## Responsive Styling

- Design mobile-first.
- Use Tailwind base classes for mobile.
- Add breakpoint overrides for larger screens.
- Avoid desktop-first layouts that are later compressed onto mobile.

## Trend Check

For substantial new projects, consider checking current web UI trends before committing to visual details. Treat trend elements as optional, not mandatory. Use them only when they fit the product and audience.
