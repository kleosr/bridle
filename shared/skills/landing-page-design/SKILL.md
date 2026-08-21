---
name: landing-page-design
description: >-
  Elaya landing-page system: one offer, conversion structure, type scale, spacing
  tokens, nested radius, no Inter/lorem, Phosphor icons, 700ms motion. Use for
  marketing sites, landing pages, campaign pages. Product apps defer to
  premium-ui-craft. Upstream https://github.com/elayadesign/ai-design-skills
---

# Landing page design (Elaya)

MIT. Upstream: [elayadesign/ai-design-skills](https://github.com/elayadesign/ai-design-skills). Full text: [SKILL.md](https://raw.githubusercontent.com/elayadesign/ai-design-skills/main/skills/landing-page-design/SKILL.md).

**This turn:** WebFetch that raw URL and follow it verbatim for marketing/landing work. If fetch fails, use the rules below.

**Product / in-app UX (shadcn dashboards, couple apps):** do **not** apply island nav, 700ms springs, Phosphor-only, or no-serif. Use `premium-ui-craft` instead. Keep Elaya copy rules (no lorem, no Elevate/Seamless, real CTAs, full states).

## Strategy

One offer → one audience → one primary action. Intake in one batch. Layout A/B/C/D. Build: hero, benefits, how it works, proof, FAQ, final CTA. No competing CTAs above the fold.

## Visual (marketing only)

- Fonts: Geist, Manrope, Geist Mono, Poppins. Never Inter, Roboto, Arial, Open Sans, Helvetica. No italics. No 900 weights. One typeface. Tailwind type scale only.
- Spacing: 0, 2, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96px.
- Nested radius: inner = outer − gap when gap < 32px and result > 2.
- Dark surfaces: `#000000` `#181818` `#1F1F1F` `#272727` `#313131` `#131209`. No background gradients. Hero heading text may gradient white→gray.
- Icons: Phosphor, Solar, Iconamoon. Not Material.
- Motion: `duration-700 ease-[cubic-bezier(0.32,0.72,0,1)]`. Scroll via IntersectionObserver. No `window` scroll listeners.
- States: hover, active, focus, loading skeleton, empty, error. No `#` dead links.
- Copy: no lorem, no Acme, no round fake %, sentence case, no AI cliches.

Companion audit: `redesign-existing-projects`.
