---
name: workercore
description: Skill for building admin panels with @ouraihub/workercore, a zero-config admin-panel framework for Cloudflare Workers. TRIGGER when generating any workercore page, handler, route, template, or UI, or when working in a repo that imports @ouraihub/workercore — even if the user does not explicitly ask for this skill.
metadata:
  version: 0.1.x
  package: "@ouraihub/workercore"
alwaysApply: false
applyTo: "**/*.{ts,html}"
---

# workercore

workercore (`@ouraihub/workercore`) is a zero-config admin-panel framework for Cloudflare Workers. One `createApp()` call gives you auth, routing, a sidebar shell, 35+ prebuilt UI partials, dark mode, and runtime-switchable themes. Pages are Mustache templates fed by data-only handlers; the framework renders them into a layout.

## When to run this skill

- Trigger when generating or editing any workercore page, page handler, API route, `.html` template, or UI markup.
- Trigger when the repo imports `@ouraihub/workercore` (check `package.json` / imports).
- Trigger when the user mentions: workercore, admin panel, dashboard page, sidebar, `createApp`, page handler, Mustache template, or Cloudflare Workers admin UI.
- Trigger even if the user does not explicitly ask for it.

## The 7 core conventions (hard rules)

These are non-negotiable. Generated code that breaks them is wrong.

1. **TS never contains page HTML structure.** Every page is a Mustache `.html` template. Handlers return data, not markup. (Small inline HTML *fragments* built in TS and injected via `{{{ }}}` — e.g. a table's `rowsHtml` — are allowed, but the page skeleton lives in a template.)
2. **HTML never contains JS.** No `<script>` tags, no `onclick=` / inline event handlers in templates. All client interactivity is pre-written in `src/client/modules/` and bound via `data-*` attributes or CSS `:target`. See "Client interactivity".
3. **A PageHandler only returns data.** Signature: `(ctx: RequestContext) => Promise<object>`. The framework does the rendering. Never build a `Response` in a page handler.
4. **Throw `WorkerError` (or a subclass), never bare `Error`.** The framework maps `WorkerError.status` to the HTTP response. See "Errors".
5. **Log with `logger`, structured.** `logger.info("message", { key: value })`. Never `console.log`.
6. **KV keys are colon-separated namespaces.** `user:admin`, `session:<id>`, `account:<email>`.
7. **UI uses semantic tokens, never raw Tailwind colors.** Use `bg-surface`, `text-fg`, `border-border`, `bg-primary`, `bg-danger-solid`, etc. Never `bg-white`, `text-slate-800`, `bg-red-500`. See "Semantic color tokens".

## Architecture: createApp

The entire app is one `ExportedHandler` produced by `createApp(config)`. This is the Worker's default export.

```ts
import { createApp } from '@ouraihub/workercore'
import dashboardHtml from './templates/dashboard.html'
import { dashboardPage } from './handlers/dashboard'

export default createApp({
  name: 'My Admin',
  templates: {
    dashboard: dashboardHtml,   // template name -> imported .html string
  },
  pages: [
    { path: '/', title: 'Dashboard', icon: 'home', template: 'dashboard', handler: dashboardPage },
  ],
})
```

`AppConfig` fields:
- `name: string` — app name, shown in sidebar/title.
- `templates: Record<string, string>` — map of template name → template HTML string (imported from `.html`, loaded as text via wrangler `rules`).
- `pages: PageConfig[]` — routed pages. Each `{ path, title, icon?, template, handler }`.
- `partials?: Record<string, string>` — extra custom Mustache partials, merged with built-ins.
- `sidebar?: SidebarConfig` — override the auto-generated sidebar.
- `api?: ApiRoute[]` — JSON API routes `{ method, path, handler }`.
- `auth?: AuthProvider` — defaults to `PasswordAuthProvider` (KV-backed sessions).
- `onCallback?`, `scheduled?`, `staticAssets?` — webhook aggregation, cron, and `/static/*` assets.

### Request lifecycle (what createApp routes, in order)
1. `/static/*` → static assets (if configured)
2. `GET /login`, `POST /login`, `POST /callback` → public
3. **auth check** — everything below requires a valid session, else `302 → /login`
4. `/logout`
5. `api[]` routes (matched by method + path, supports `:param` and `*` wildcard)
6. `POST /api/trigger/*`
7. `pages[]` routes (GET only) → run handler, render `templates[page.template]` into the layout
8. fallback → 404 (HTML for browsers, JSON for API callers)

## PageHandler pattern

A handler receives `RequestContext` and returns a plain data object. The keys become the Mustache view for that page's template.

```ts
import type { PageHandler } from '@ouraihub/workercore'

interface RequestContext {
  req: Request
  env: Env                              // Cloudflare bindings: KV, ADMIN_PASSWORD, ...
  params: Record<string, string>        // route params from :id / *
  user: { username: string }            // the authenticated user
}

export const usersPage: PageHandler = async ({ env, params }) => {
  const raw = await env.KV.get('users:all')
  const users = raw ? JSON.parse(raw) : []
  return {
    pageHeader: { title: 'Users' },
    stats: [{ label: 'Total', value: String(users.length) }],
    // ...whatever the template consumes
  }
}
```

Common top-level keys the layout understands: `title`, `breadcrumbs` (`[{ label, href? }]`), `pageHeader`, `stats`. Everything else is template-specific.

`definePage<T>(config)` is a typed identity helper for authoring a `PageConfig` with an inferred data contract.

## API routes (JSON, not pages)

Unlike page handlers, an `ApiHandler` returns a `Response` directly — build it with `json()` / `error()`. Register in `AppConfig.api`. Paths support `:param` and `*` wildcard; `params` carries the matches.

```ts
import { json } from '@ouraihub/workercore'
import type { ApiRoute } from '@ouraihub/workercore'

const api: ApiRoute[] = [
  { method: 'GET', path: '/api/users/:id', handler: async ({ env, params, user }) => {
    const raw = await env.KV.get(`user:${params.id}`)
    if (!raw) throw new NotFoundError('User not found')
    return json(JSON.parse(raw))
  }},
]
// createApp({ ..., api })
```

API routes are behind the same auth gate as pages (`user` is always present in `ctx`).

## Public API (imports from `@ouraihub/workercore`)

- `createApp(config)` — build the Worker handler.
- `definePage(config)` — typed page config helper.
- `html(body, status?)`, `json(data, status?)`, `redirect(url, opts?)`, `error(message, status?, reqOrAccept?)` — response builders (for **API** handlers, not page handlers). `error()` returns HTML for browsers and JSON for fetch callers based on `Accept`.
- `logger`, `setLogLevel(level)`, type `Logger` — structured logging. `logger.child({ requestId })` for context.
- `WorkerError`, `AuthError` (401), `NotFoundError` (404), `ValidationError` (400).
- `PasswordAuthProvider`, `KVSessionStore`, types `SessionStore`, `Session` — auth building blocks.
- `generateCsrfToken(sessionId, secret)`, `verifyCsrfToken(token, sessionId, secret)`.
- `icon(name?)` — returns built-in SVG markup for a name, or `''`.
- `triggerWorkflow(...)` — GitHub workflow dispatch helper.

## Semantic color tokens

Like daisyUI, workercore colors are **semantic tokens driven by CSS variables**, so they adapt to the active theme automatically.

### Rules
1. **Only use semantic token utilities for color.** Never raw Tailwind palette colors (`slate-*`, `red-*`, `bg-white`, `text-black`) for themeable surfaces/text/borders.
2. **Never use `dark:` for color.** Tokens already flip between light/dark and across all themes. Adding `dark:bg-...` is wrong and causes double-theming bugs.
3. `*-foreground` tokens are the readable content color to place *on* the matching background.
4. Raw palette colors are allowed **only** for intentionally theme-independent content: brand logos, data-viz series colors, illustration/preview swatches, code-file glyph colors. Everything structural uses tokens.

### Token reference (utility class → meaning)
Surfaces / backgrounds:
- `bg-surface` — card / panel background (the "white" surface)
- `bg-surface-muted` — subtle raised/hover background
- `bg-surface-strong` — stronger elevated background

Text / foreground:
- `text-fg` — primary text
- `text-fg-muted` — secondary text
- `text-fg-subtle` — tertiary / labels / captions

Borders:
- `border-border` — default border
- `border-border-strong` — emphasized border
- `border-card` — card border (custom utility)
- `divide-table` — table row dividers (custom utility)

Brand / primary:
- `bg-primary`, `text-primary`, `border-primary`
- `bg-primary-hover` (hover state), `bg-primary-light`, `bg-primary-dark`
- `text-primary-foreground` — content on primary

Destructive / danger:
- `bg-danger`, `text-danger`, `border-danger-border`
- `bg-danger-subtle` (soft bg), `bg-danger-solid` / `bg-danger-solid-hover` (solid button), `bg-danger-hover`
- `text-danger-foreground` — content on danger

Other: `bg-tooltip` / `text-tooltip-foreground`.

### Themes
`THEMES` lists the runtime-switchable themes (light, dark, cupcake, corporate, synthwave, dracula, night, … 30+). The layout ships a theme picker. Switching sets `[data-theme]` / `.dark`; token values change, your markup does not.

## Templates & partials (Mustache)

Templates are `.html` files rendered with Mustache. Reference a partial with `{{> partial-name}}`. Use section blocks to render a partial only when data is present:

```html
<div class="space-y-5">
  {{#pageHeader}}{{> page-header}}{{/pageHeader}}

  <div class="grid grid-cols-2 gap-3 xl:grid-cols-4">
    {{#stats}}{{> stats-card}}{{/stats}}
  </div>

  {{#table}}{{> data-table}}{{/table}}
</div>
```

Mustache reminders:
- `{{value}}` HTML-escapes. `{{{value}}}` is raw (use for pre-built HTML fragments like `rowsHtml`, `controlHtml`, `actionsHtml`).
- `{{#key}}...{{/key}}` renders when `key` is truthy / iterates arrays. `{{^key}}...{{/key}}` renders when falsy/empty.
- Inside an array section, `{{field}}` refers to the current item.

### Built-in partial catalog
Layout / chrome (usually automatic): `sidebar`, `sidebar-brand`, `sidebar-workspace`, `sidebar-section`, `sidebar-item`, `sidebar-subitem`, `sidebar-user`, `sidebar-theme`, `navbar`, `breadcrumb`.

Page building blocks (use these in page templates):
- `page-header` — data: `{ title, actionsHtml? }`
- `stats-card` — data (per item in `stats[]`): `{ label, value, icon?, change? }`
- `data-table` — data: `{ columns: [{label}] | columnsHtml, rowsHtml, pagination?, offcanvasHtml? }` (`rowsHtml` is raw `<tr>` markup)
- `filter-bar` — data: `{ tabs: { items: [{label, active?, url?}] }, searchPlaceholder, controlHtml? }`
- `form-field` — data: `{ label, controlHtml, hint?, error?, multiline? }` (`controlHtml` is the raw input)
- `action-bar`, `pagination`, `empty-state`, `overlay` (modal shell: `{ id, title, body, size? }`)
- `profile-header`, `profile-sidebar`, `profile-activity`

Prebuilt modals/offcanvas (reference by id + trigger with `href="#id"`): `chat-*-modal`, `inbox-*-modal`, `files-upload-modal`, `kanban-*-modal`, `todo-task-modal`, `todo-offcanvas`, `dashboard-*-modal`.

To add your own partial, put it in `AppConfig.partials` and reference it the same way.

## Client interactivity (no inline JS)

Interactivity is pre-built in `src/client/modules/` and bundled at build time. Templates opt in declaratively:
- **Modals/overlays:** trigger with `<a href="#modal-id">`; the overlay uses CSS `:target` to show (works without JS). JS module also supports `data-modal-open` / `data-modal-close` / `data-modal-panel` / `data-modal-backdrop`.
- **Dropdowns:** `data-dropdown-trigger` + `data-dropdown-menu`.
- **Repeaters (add/remove rows):** `data-repeater`, `data-repeater-item`, `data-repeater-template`, `data-repeater-add`, `data-repeater-remove`.
- **Offcanvas, mobile sidebar, theme picker, charts, kanban drag:** handled by their modules via markup hooks.

Never write a new `<script>` in a template. If new behavior is needed, add a module under `src/client/modules/` and rebuild the client bundle (`pnpm build:client`) — do not edit the generated `client-bundle.js` directly.

## Errors

```ts
import { WorkerError, ValidationError, NotFoundError } from '@ouraihub/workercore'

if (!id) throw new ValidationError('id is required')        // 400
const row = await env.KV.get(`item:${id}`)
if (!row) throw new NotFoundError('Item not found')          // 404
// custom:
throw new WorkerError('Upstream unavailable', 503, 'UPSTREAM_DOWN')
```

The framework catches these, logs them, and returns the right status (HTML page for browsers, JSON for API callers). Never `throw new Error(...)` — it becomes an opaque 500.

## Recipe: add a page end to end

1. **Template** `src/templates/reports.html` — Mustache, tokens only, partials via `{{> ...}}`, no `<script>`.
2. **Handler** `src/handlers/reports.ts`:
   ```ts
   import type { PageHandler } from '@ouraihub/workercore'
   export const reportsPage: PageHandler = async ({ env }) => ({
     pageHeader: { title: 'Reports' },
     breadcrumbs: [{ label: 'Reports' }],
     stats: [{ label: 'Runs', value: '128' }],
   })
   ```
3. **Register** in `createApp`: add `reports: reportsHtml` to `templates`, and `{ path: '/reports', title: 'Reports', icon: 'layoutDashboard', template: 'reports', handler: reportsPage }` to `pages`. (Icon names are built-in SVG keys — e.g. `home`, `users`, `layoutDashboard`, `settings`, `inbox`, `calendarDays`, `files`, `bell`; unknown names render as-is.)
4. Verify with `pnpm check` (typecheck) and `pnpm test`.

## Setup notes
- Requires Cloudflare Workers + a `KV` namespace binding named `KV`, and an `ADMIN_PASSWORD` var (auto-creates the `admin` user on first login).
- `.html` / `.css` / `client-bundle.js` are loaded as **text modules** via wrangler `rules` — this is required for the imports to work.
- Tailwind CSS is built at package-build time (no runtime CDN). Tokens are defined in `src/templates/tailwind.css` (`@theme` + `:root`/`.dark`/`[data-theme]`).
