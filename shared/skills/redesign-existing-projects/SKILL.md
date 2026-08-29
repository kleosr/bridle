---
name: redesign-existing-projects
description: >-
  Elaya audit for existing sites/apps that look generic, cheap, or AI-made.
  Diagnose first, then fix in place (fonts, color, states, layout, motion).
  Use when Mario says polish, audit, upgrade, or it looks horrible. Product apps
  apply diagnosis through premium-ui-craft values, not Elaya black/Geist/700ms.
  Upstream https://github.com/elayadesign/redesign-skill
---

# Redesign existing projects (Elaya)

MIT. Upstream (reference only, do not fetch at runtime): [elayadesign/redesign-skill](https://github.com/elayadesign/redesign-skill). This file is the law.

Report diagnosis before fixing. Do not rewrite the stack.

**Product apps:** keep the audit checklist. Replace values using `premium-ui-craft` (semantic tokens, 300ms Apple curve, lucide/shadcn, rail+dock). Do not force floating island nav or Phosphor on an existing shadcn app unless Mario asks for a marketing site. Never Scandinavian/Nordic/Japandi palettes.

## Diagnose (must list before edits)

- Generic cards, equal three columns, purple AI gradients
- Inter/Roboto/Open Sans, missing type scale
- Missing hover/focus/active, dead `#` links
- No empty/error/loading, lorem or fake stats
- Hover lift on cards, rainbow accents

## Order of fixes

1. Font and type scale
2. Color and surfaces (kill background gradients)
3. Hover / focus / active
4. Layout, spacing, nested radius
5. Motion (custom curve, no scroll listeners)
6. Generic components
7. Loading / empty / error
8. Copy
9. Type polish

Work in the current stack. Do not break behavior. Ask before inventing a token not in the active design system.
