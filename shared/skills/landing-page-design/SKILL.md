---
name: landing-page-design
description: >
  Marketing, landing, and campaign pages (Elaya). Product apps use
  premium-ui-craft instead.
---

# Landing page design (Elaya)

MIT. Upstream URLs only in [SOURCE.md](SOURCE.md) (do not fetch at runtime). This file is the law. Mario ban wins: never Scandinavian, Nordic, Japandi, or hygge (parchment, oatmeal, linen, sage-on-cream, pale wood).

**Product / in-app UX:** do not apply island nav, 700ms springs, Phosphor-only, or no-serif. Use `premium-ui-craft`. Keep copy rules (no lorem, no Elevate/Seamless, real CTAs, full states).

## Strategy

One offer → one audience → one primary action. Intake in one batch. Build: hero, benefits, how it works, proof, FAQ, final CTA. No competing CTAs above the fold. Real names and numbers or omit them.

## Visual (marketing only)

- Fonts: Geist, Manrope, Geist Mono, Poppins. Never Inter, Roboto, Arial, Open Sans, Helvetica. No italics. No 900 weights. One typeface. Tailwind type scale only.
- Spacing: 0, 2, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96px.
- Nested radius: inner = outer − gap when gap < 32px and result > 2.
- Dark surfaces: `#000000` `#181818` `#1F1F1F` `#272727` `#313131` `#131209`. No background gradients. Hero heading text may gradient white→gray.
- Icons: Phosphor, Solar, Iconamoon. Not Material.
- Motion: `duration-700 ease-[cubic-bezier(0.32,0.72,0,1)]`. Scroll via IntersectionObserver. No `window` scroll listeners. `prefers-reduced-motion` zeros duration.
- States: hover, active, focus, loading skeleton, empty, error. No `#` dead links.
- Copy: no lorem, no Acme, no round fake %, sentence case, no AI cliches.

Companion audit: `redesign-existing-projects`.
