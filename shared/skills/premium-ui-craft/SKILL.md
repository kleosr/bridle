---
name: premium-ui-craft
description: >-
  Ships Linear/Stripe/Apple-grade UI craft: type hierarchy, color restraint,
  microstates, hairlines, designed motion, empty/error/focus. Use when Mario
  @mentions @Design, when Product Designer runs, or when UI looks generic SaaS,
  cramped, or over-decorated (dashboards, sidebars, shadcn, Tailwind, CSS tokens).
---

# Premium UI craft

Read this **in full** before proposing or shipping UI. Then apply. Do not invent a second aesthetic.

Sources (read when stuck): [sources.md](sources.md)

## Doctrine

Interaction-dense, visually sparse. Color means something (one accent for primary/complete, one for danger). Never a rainbow of card accents.

Never Scandinavian, Nordic, Japandi, or hygge. No parchment, oatmeal, linen, sage-on-cream, pale wood, muted beige fields, or default serif-on-paper titles. This skill is Linear/Stripe/Apple.

Typography is the brand. One UI sans. 4–6 sizes. Tabular nums for counts. No decorative second font unless Mario asks.

Motion: one curve, one duration. Apple-like `300ms` / `cubic-bezier(0.22, 1, 0.36, 1)`. No bounce, no card lift on hover. `prefers-reduced-motion` zeros duration.

## Hierarchy

Every screen: one primary job. Eye hits title, then the action (check, save), then chrome.

- Kickers: 11px, wide tracking, muted, sentence or uppercase meta
- Titles: same sans as body, tight tracking, real copy (names, not ISO dates)
- Body: 15px-ish, muted for secondary
- Hairlines: 1px at low alpha. Not `<hr>` soup

## Chrome

- Desktop: persistent left rail (~220px), active = hairline/marker + text, not a filled gray pill
- Mobile with ≤5 destinations: bottom dock, equal slots, `safe-area-inset-bottom`, content padded so it is not hidden
- Do not wrap a hamburger + Sheet if five tabs already exist
- Do not put `data-bezel` on the full viewport

## Components

Prefer shadcn primitives (Card, Tabs `variant="line"`, Checkbox, Field, Progress, Empty, sonner). Semantic tokens (`bg-background`, `text-muted-foreground`, `bg-primary`). No raw `bg-blue-500`.

Compose pages as **structure** (header + list), not stacked generic cards with badges on every row.

## Microstates (required)

Every control: default, hover, focus (visible ring, designed), active, disabled. Empty and error are designed copy, not "No data".

## Checklist before handoff

- [ ] Primary action obvious without decoration
- [ ] One palette; accent and danger only as meaning
- [ ] No hover translate on surfaces
- [ ] Lists are full-row hit targets
- [ ] Dates/human language, not `YYYY-MM-DD` in heroes
- [ ] Reduced motion respected
