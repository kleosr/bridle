---
name: premium-ui-craft
description: >
  Linear/Stripe/Apple-grade UI craft. Use for Product Designer / @Design,
  dashboards, shadcn, or generic SaaS UI.
---

# Premium UI craft

Law for product UI. Do not invent a second aesthetic. Sources when stuck: [SOURCE.md](SOURCE.md).

## Doctrine

Interaction-dense, visually sparse. One accent for primary/complete, one for danger. Never a rainbow of card accents.

## Palette ban

Never Scandinavian, Nordic, Japandi, or hygge. No parchment, oatmeal, linen, sage-on-cream, pale wood, muted beige, or serif-on-paper titles. Linear/Stripe/Apple.

Typography is the brand. One UI sans. 4–6 sizes. Tabular nums. No decorative second font unless the user explicitly asks.

Motion: one curve, one duration. `300ms` / `cubic-bezier(0.22, 1, 0.36, 1)`. No bounce, no card lift. `prefers-reduced-motion` zeros duration.

## Hierarchy

One primary job per screen. Title → action → chrome. Kickers 11px muted. Titles same sans, real copy. Hairlines 1px low alpha.

## Chrome

Desktop: left rail ~220px; active = marker + text, not a gray pill. Mobile ≤5 destinations: bottom dock, `safe-area-inset-bottom`. No hamburger+Sheet if five tabs exist. No framed-device viewport wrappers.

## Components

shadcn primitives. Semantic tokens. No raw `bg-blue-500`. Pages are structure (header + list), not stacked generic cards.

Every control: default, hover, focus ring, active, disabled. Empty/error are designed copy. Keyboard: every action without a pointer. Touch targets ≥44px. Contrast must read as primary.

## Research (optional)

New chrome: `web_search` / `web_fetch` the specific layout, or HIG + shadcn and say skipped. Apply here.
