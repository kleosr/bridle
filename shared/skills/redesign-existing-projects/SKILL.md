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

MIT. Upstream: [elayadesign/redesign-skill](https://github.com/elayadesign/redesign-skill). Full text: [SKILL.md](https://raw.githubusercontent.com/elayadesign/redesign-skill/main/skills/redesign-existing-projects/SKILL.md).

**This turn:** WebFetch that raw URL. Report diagnosis before fixing. Do not rewrite the stack.

**Product apps:** keep the audit checklist (generic cards, missing states, Inter/Roboto, purple AI gradients, equal three columns, dead links). Replace values using `premium-ui-craft` (semantic tokens, 300ms Apple curve, lucide/shadcn, rail+dock). Do not force floating island nav or Phosphor on an existing shadcn app unless Mario asks for a marketing site. Never Scandinavian/Nordic/Japandi palettes.

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

## Always

Work in the current stack. Do not break behavior. Ask before inventing a token not in the active design system.
