# Style Guide Rule

Apply this rule when styling a React TypeScript app with Tailwind and shadcn/ui.

## Visual Direction

Target a modern, elegant, professional, and lightly futuristic interface. Avoid default template visuals.

## Typography

Use fonts with clear roles:

| Font | Role |
| --- | --- |
| Poppins | Headings and display text |
| Plus Jakarta Sans | UI text, body copy, labels, buttons, inputs, tables |
| Lato | Secondary text, captions, metadata, long descriptions, footer text |

Map fonts into Tailwind:

- `font-heading`
- `font-sans`
- `font-secondary`

Use a disciplined type scale. Avoid one-off font sizes.

## Color System

Brand foundation:

```txt
ink:  #171615
mist: #EEF0F2
```

Neutral ramp:

```txt
neutral-950: #171615
neutral-900: #232220
neutral-700: #4A4846
neutral-500: #726F6C
neutral-300: #A8A5A1
neutral-100: #EEF0F2
neutral-50:  #F8F9FA
```

Accent:

```txt
accent: #7A1E2B
accent-foreground: #FFFFFF
```

Use accent sparingly for primary CTAs, active states, focus rings, and key highlights.

## Semantic Colors

- Success: `#16A34A`
- Warning: `#D97706`
- Error: `#DC2626`
- Info: `#2563EB` or `#EA580C`

## shadcn Theme

Wire colors into shadcn CSS variables in `index.css`. Do not hardcode hex values across components.

## Layout

- Use generous whitespace.
- Keep operational screens dense enough for real work.
- Use subtle borders and shadows.
- Use restrained corner radius.
- Keep repeated content scannable.
- Avoid decorative visuals that do not help the task.

## Motion And Icons

- Use small, fast transitions for hover and focus.
- Avoid decorative animation unless it improves clarity.
- Use one icon set consistently. Lucide is the default with shadcn/ui.

## Responsiveness

Design mobile-first. Use Tailwind base classes for mobile, then add breakpoint overrides.
