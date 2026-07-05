---
name: workercore-conventions
description: MANDATORY core conventions for @ouraihub/workercore. The 7 non-negotiable rules.
---

# workercore core conventions

These are non-negotiable. Generated code that breaks them is wrong.

1. **TS never contains page HTML structure.** Every page is a Mustache `.html` template. Handlers return data, not markup. (Small inline HTML *fragments* built in TS and injected via `{{{ }}}` — e.g. a table's `rowsHtml` — are allowed, but the page skeleton lives in a template.)

2. **HTML never contains JS.** No `<script>` tags, no `onclick=` / inline event handlers in templates. All client interactivity is pre-written in `src/client/modules/` and bound via `data-*` attributes or CSS `:target`. See [../templates/SKILL.md](../templates/SKILL.md).

3. **A PageHandler only returns data.** Signature: `(ctx: RequestContext) => Promise<object>`. The framework does the rendering. Never build a `Response` in a page handler. See [../architecture/SKILL.md](../architecture/SKILL.md).

4. **Throw `WorkerError` (or a subclass), never bare `Error`.** The framework maps `WorkerError.status` to the HTTP response.
   ```ts
   import { ValidationError, NotFoundError, WorkerError } from '@ouraihub/workercore'
   if (!id) throw new ValidationError('id is required')     // 400
   if (!row) throw new NotFoundError('Item not found')       // 404
   throw new WorkerError('Upstream unavailable', 503, 'UPSTREAM_DOWN')
   ```
   `throw new Error(...)` becomes an opaque 500 — do not use it.

5. **Log with `logger`, structured.** `logger.info("message", { key: value })`. Never `console.log`. Use `logger.child({ requestId })` for request-scoped context.

6. **KV keys are colon-separated namespaces.** `user:admin`, `session:<id>`, `account:<email>`.

7. **UI uses semantic tokens, never raw Tailwind colors.** Use `bg-surface`, `text-fg`, `border-border`, `bg-primary`, `bg-danger-solid`, etc. Never `bg-white`, `text-slate-800`, `bg-red-500`, and never `dark:` for color. See [../tokens/SKILL.md](../tokens/SKILL.md).

## Verify before done

After any change, run `pnpm check` (typecheck: 4 tsconfigs) and `pnpm test` (vitest: unit + Miniflare integration). Both must pass.
