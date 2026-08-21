---
name: ux-web-research
description: >-
  Live UX/UI research via Exa before inventing layouts. Use when Product Designer
  or @Design starts a visual pass, dashboard/sidebar/nav work, or the user asks
  how current products ship chrome. Prefer Exa MCP over guessing HIG or 2026 patterns.
---

# UX web research

Before a visual overhaul or new chrome (sidebar, dock, dashboard shell):

1. `GetMcpTools` on `plugin-exa-exa` (need `web_search_exa`, `web_fetch_exa`).
2. Search for the **specific problem** (e.g. "persistent dashboard sidebar vs bottom tab bar five destinations Apple HIG 2026"), not generic "best UI".
3. `web_fetch_exa` the 1–2 URLs that actually describe layout/craft.
4. Apply findings through **premium-ui-craft**. Do not paste a SaaS template.

If Exa is down, use Apple HIG + shadcn docs URLs and say the search was skipped.

Also Read `~/.cursor/skills/premium-ui-craft/SKILL.md` in the same turn.
