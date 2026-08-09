# Warq — design system

Everything here is lifted verbatim from the approved mockups in `design/`.
Nothing is invented: if a value is not in `@warq/tokens`, it is not in the
product.

Run `npm run dev -w @warq/web` and open `/design` to see it rendered.

---

## One source, two targets

```
packages/tokens/src/*.ts        the source of truth
        │
        ├── dist/index.js       objects, imported directly by React Native
        └── dist/tokens.css     custom properties, imported by the web app
```

The web app maps those custom properties into Tailwind's theme with
`@theme inline`, so `bg-accent` resolves to `var(--warq-brand-accent)` rather
than a copied hex. Switching `data-accent` on `<html>` repaints the app without
a rebuild.

Regenerate after changing a token:

```bash
npm run build -w @warq/tokens
```

---

## Colour

Named by role, never by value. A component asks for `border.subtle`; it never
asks for `#F0F0F6`.

### Accent

`#4338CA` indigo by default. The mockups also expose `#0F766E` teal, `#B45309`
amber and `#1E3A5F` navy, applied with `<html data-accent="teal">`.

### Ink, in descending emphasis

| Token        | Value     | Used for                            |
| ------------ | --------- | ----------------------------------- |
| `ink.strong` | `#17173A` | Headings, figures, the dark sidebar |
| `ink.base`   | `#43436B` | Body copy and table cells           |
| `ink.muted`  | `#8A8AA3` | Labels and secondary metadata       |
| `ink.faint`  | `#B0B0C3` | Timestamps and tertiary detail      |

The neutrals are not grey — every one carries a blue-violet bias toward the
accent. That is what makes the palette read as chosen rather than inherited.

### Surfaces and hairlines

`surface.canvas` `#F6F6F9` · `surface.raised` `#FFFFFF` · `surface.sunken`
`#FAFAFC` · `surface.inverse` `#17173A`

`border.base` `#E7E7EF` · `border.input` `#E3E3EC` · `border.subtle` `#F0F0F6` ·
`border.faint` `#F6F6FA`

### Semantic colour

Separate from the accent, and never the only carrier of meaning — a status pill
always shows its word as well as its colour.

| State         | Value     | Also used for     |
| ------------- | --------- | ----------------- |
| Active        | `#16A34A` | Present, A+ and A |
| Pending       | `#D97706` | Late, grade C     |
| Expiring soon | `#EA580C` | Grade D           |
| Expired       | `#DC2626` | Absent, grade F   |
| Suspended     | `#8A8AA3` |                   |
| Info          | `#0E7490` | Grade B           |

### Series

Six rotating colours for class bars: `#4338CA`, `#0E7490`, `#B45309`, `#16A34A`,
`#BE185D`, `#7C3AED`. Assigned by index and stored, so a class keeps the same
colour on both platforms.

---

## Typography

**Sora** 700/800 carries headings, statistics and avatar initials.
**Public Sans** 400–700 carries body copy, labels and table cells.

A monospace stack is reserved for anything that lines up in a column — roll
numbers, marks, identifiers — paired with `tabular-nums`.

The scale, in pixels, exactly as the mockups set it. Half-pixel sizes are
intentional.

| Token  | Size | Used for              |
| ------ | ---- | --------------------- |
| `5xl`  | 26   | Dashboard statistics  |
| `4xl`  | 24   | Page titles           |
| `3xl`  | 22   | Mobile screen titles  |
| `2xl`  | 18   | Drawer titles         |
| `xl`   | 15   | Card titles           |
| `lg`   | 14   | List rows and inputs  |
| `md`   | 13.5 | Body copy and buttons |
| `base` | 12.5 | Table metadata, chips |
| `sm`   | 11.5 | Captions              |
| `xs`   | 11   | Eyebrows, timestamps  |
| `2xs`  | 10   | Tab labels, badges    |

Uppercase eyebrow labels take `0.06em` to `0.09em` of tracking.

> **M0 note.** Sora and Public Sans load from Google Fonts so the preview matches
> the mockups. M2 replaces this with self-hosted `woff2` files.

---

## Shape

Pill-shaped chips, soft 10–14px controls, generously rounded 16–22px cards.

| Token  | Radius | Used for                            |
| ------ | ------ | ----------------------------------- |
| `xs`   | 8      | Status pills and badges             |
| `sm`   | 10     | Row-level action buttons            |
| `md`   | 12     | Inputs, buttons, filter chips       |
| `lg`   | 14     | Search fields, icon tiles           |
| `xl`   | 16     | Mobile list cards                   |
| `2xl`  | 18     | Statistic cards                     |
| `3xl`  | 20     | Content cards and tables            |
| `4xl`  | 24     | Modals and bottom sheets            |
| `full` | 999    | Chips, avatars, the floating button |

Every shadow is tinted with the ink colour, never neutral black — the one
exception is the floating action button, tinted with the accent it sits on.

---

## Motion

180ms scrim fade, 200ms modal and sheet entrance, 220ms drawer and toast. All of
it disabled under `prefers-reduced-motion`.

---

## Components

Built twice — once for the DOM, once for React Native — against one token set.

`StatCard` · `StatusPill` · `Button` · `Chip` · `Card` · `DataTable` and list row
· `Drawer` (web) and `BottomSheet` (native) · `Modal` · `Toast` · `SearchField` ·
`ActivityFeed` · `BarChart` · `ProgressBar` · `SegmentedControl` · the P · A · L
attendance toggle · `EmptyState`.

---

## Rules that are not negotiable

- **State is never carried by colour alone.** A pill shows the word; the attendance toggle shows the letter.
- **Figures use `tabular-nums`** wherever they stack in a column, so digits align.
- **Focus is always visible.** Two pixels of accent, offset by two.
- **Wide content scrolls inside its own container.** The page body never scrolls sideways.
- **A control says what it does; the toast afterwards says it in the past tense.** "Approve" then "Approved". Errors say what went wrong _and_ what to do next.
