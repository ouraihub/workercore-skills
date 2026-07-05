---
name: workercore
description: Skill for building admin panels with @ouraihub/workercore, a zero-config admin-panel framework for Cloudflare Workers. TRIGGER when generating any workercore page, handler, route, template, or UI, or when working in a repo that imports @ouraihub/workercore — even if the user does not explicitly ask for this skill.
metadata:
  version: 0.1.x
  package: "@ouraihub/workercore"
---

# workercore

workercore (`@ouraihub/workercore`) is a zero-config admin-panel framework for Cloudflare Workers. One `createApp()` call gives you auth, routing, a sidebar shell, 35+ prebuilt UI partials, dark mode, and runtime-switchable themes. Pages are Mustache templates fed by data-only handlers; the framework renders them into a layout.

## When to run this skill

- Trigger when generating or editing any workercore page, page handler, API route, `.html` template, or UI markup.
- Trigger when the repo imports `@ouraihub/workercore` (check `package.json` / imports).
- Trigger when the user mentions: workercore, admin panel, dashboard page, sidebar, `createApp`, page handler, Mustache template, or Cloudflare Workers admin UI.
- Trigger even if the user does not explicitly ask for it.

## Mandatory reference

Read the relevant guide before writing code. Do not rely on memory for syntax.

| Task | Guide | Note |
|------|-------|------|
| Core rules | [./conventions/SKILL.md](./conventions/SKILL.md) | MANDATORY. The 7 non-negotiable conventions. Read before writing any workercore code. |
| App structure, handlers, routes, API | [./architecture/SKILL.md](./architecture/SKILL.md) | MANDATORY when adding pages, handlers, API routes, or wiring `createApp`. |
| Colors & theming | [./tokens/SKILL.md](./tokens/SKILL.md) | MANDATORY. Semantic color tokens and the no-`dark:` rule. Read before writing any UI markup. |
| Templates & client interactivity | [./templates/SKILL.md](./templates/SKILL.md) | MANDATORY when writing `.html` templates or adding interactivity. Mustache syntax, partial usage, `data-*` hooks. |
| UI components | [./components/](./components/) | MANDATORY when using a built-in partial. Read the relevant component doc(s). Read multiple candidates before deciding. |

## Built-in components (partials)

Page building blocks — reference in templates with `{{> name}}`:

- [page-header](./components/page-header.md) — title bar with optional actions
- [stats-card](./components/stats-card.md) — metric card (KPI)
- [data-table](./components/data-table.md) — table with header + rows + optional pagination
- [filter-bar](./components/filter-bar.md) — tab/search/control row above a table
- [form-field](./components/form-field.md) — labelled form control row with hint/error
- [overlay](./components/overlay.md) — modal shell (`:target`-driven)
- [breadcrumb](./components/breadcrumb.md) — breadcrumb trail
- [pagination](./components/pagination.md) — page navigation
- [empty-state](./components/empty-state.md) — "no data" placeholder
- [action-bar](./components/action-bar.md) — bulk-action toolbar
- [profile-header / profile-sidebar / profile-activity](./components/profile.md) — profile page pieces
- [sidebar family](./components/sidebar.md) — nav shell (usually automatic)
- [navbar](./components/navbar.md) — top bar (usually automatic)
- [prebuilt modals & offcanvas](./components/modals.md) — chat/inbox/files/kanban/todo/dashboard dialogs

## Component discovery protocol

Before writing UI code, do this in order:

1. Read the request intent, behavior, and shape — not only literal words. Match on meaning.
2. Use the component list above to shortlist the best candidate partials.
3. Read the relevant component doc(s) before deciding. When there is ambiguity, read multiple candidates.
4. Compare each candidate's data contract and rules against the request.
5. Select the best partial (or combination) and apply its data contract exactly.
6. If nothing fits, build markup with semantic tokens directly (see [./tokens/SKILL.md](./tokens/SKILL.md)) — never invent a partial name.

If the user explicitly names a partial and a doc for it exists, read that doc first.
