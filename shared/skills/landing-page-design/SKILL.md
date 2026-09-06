---
name: landing-page-design
description: >
  Marketing, landing, and campaign pages (Elaya). Product apps use
  premium-ui-craft instead.
---

# Landing page design (Elaya)

MIT. Upstream URLs in [SOURCE.md](SOURCE.md). Palette ban: `premium-ui-craft`.

**Product / in-app:** no island nav, 700ms springs, Phosphor-only, or no-serif. Use `premium-ui-craft`. Keep copy rules (no lorem, no Elevate/Seamless, real CTAs, full states).

## Strategy

One offer → one audience → one primary action. Hero, benefits, how it works, proof, FAQ, final CTA. No competing CTAs above the fold. Real names and numbers or omit them.

## Visual (marketing only)

- Fonts: Geist, Manrope, Geist Mono, Poppins. Never Inter, Roboto, Arial, Open Sans, Helvetica. No italics. No 900. One typeface. Tailwind scale only.
- Spacing: 0, 2, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96px. Nested radius: inner = outer − gap when gap < 32 and result > 2.
- Dark: `#000000` `#181818` `#1F1F1F` `#272727` `#313131` `#131209`. No background gradients. Hero heading may gradient white→gray.
- Icons: Phosphor, Solar, Iconamoon. Motion: `duration-700 ease-[cubic-bezier(0.32,0.72,0,1)]`. Scroll via IntersectionObserver. `prefers-reduced-motion` zeros duration.
- States: hover, active, focus, loading, empty, error. No `#` dead links. No lorem, Acme, fake %, AI cliches.

Companion: `redesign-existing-projects`.
