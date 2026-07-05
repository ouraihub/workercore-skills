---
name: workercore-architecture
description: MANDATORY architecture guide for @ouraihub/workercore — createApp, request lifecycle, PageHandler, ApiHandler, and the public API.
---

# workercore architecture

## createApp

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

Icon names are built-in SVG keys: `home`, `users`, `layoutDashboard`, `settings`, `inbox`, `calendarDays`, `files`, `bell`, `search`, `menu`, `user`, `userRound`, `share`, `helpCircle`, `chevronDown`, `chevronRight`, `checkSquare`. Unknown names render as-is.

## Request lifecycle (what createApp routes, in order)

1. `/static/*` → static assets (if `staticAssets` configured)
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

## ApiHandler pattern (JSON, not pages)

Unlike page handlers, an `ApiHandler` returns a `Response` directly — build it with `json()` / `error()`. Register in `AppConfig.api`. Paths support `:param` and `*` wildcard; `params` carries the matches.

```ts
import { json } from '@ouraihub/workercore'
import { NotFoundError } from '@ouraihub/workercore'
import type { ApiRoute } from '@ouraihub/workercore'

const api: ApiRoute[] = [
  { method: 'GET', path: '/api/users/:id', handler: async ({ env, params }) => {
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
- `logger`, `setLogLevel(level)`, type `Logger` — structured logging.
- `WorkerError`, `AuthError` (401), `NotFoundError` (404), `ValidationError` (400).
- `PasswordAuthProvider`, `KVSessionStore`, types `SessionStore`, `Session` — auth building blocks.
- `generateCsrfToken(sessionId, secret)`, `verifyCsrfToken(token, sessionId, secret)`.
- `icon(name?)` — returns built-in SVG markup for a name, or `''`.
- `triggerWorkflow(...)` — GitHub workflow dispatch helper.

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
3. **Register** in `createApp`: add `reports: reportsHtml` to `templates`, and `{ path: '/reports', title: 'Reports', icon: 'layoutDashboard', template: 'reports', handler: reportsPage }` to `pages`.
4. Verify with `pnpm check` and `pnpm test`.

## Setup notes

- Requires Cloudflare Workers + a `KV` namespace binding named `KV`, and an `ADMIN_PASSWORD` var (auto-creates the `admin` user on first login).
- `.html` / `.css` / `client-bundle.js` are loaded as **text modules** via wrangler `rules` — required for the imports to work.
- Tailwind CSS is built at package-build time (no runtime CDN).
