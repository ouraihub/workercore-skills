### prebuilt modals & offcanvas
Ready-made dialogs for specific pages. Reference the partial by name and open it with `<a href="#its-id">`. Most are built on the [overlay](./overlay.md) shell.

#### Available partials
- **Chat:** `chat-compose-modal`, `chat-tags-modal`, `chat-create-tag-modal`, `chat-archive-modal`, `chat-destructive-modal`
- **Inbox:** `inbox-compose-modal`, `inbox-archive-modal`, `inbox-label-modal`, `inbox-destructive-modal`
- **Files:** `files-upload-modal`
- **Kanban:** `kanban-new-project-modal`, `kanban-card-modal`
- **Todo:** `todo-task-modal`, `todo-offcanvas`
- **Dashboard:** `dashboard-import-contacts-modal`, `dashboard-export-contacts-modal`, `dashboard-add-project-modal`

#### Rules
- Include a modal partial once in the page, then trigger it from anywhere with `<a href="#modal-id">` (the id matches the partial's overlay id).
- `*-destructive-modal` variants are confirmation dialogs styled with danger tokens — use them for delete/archive confirmations.
- Offcanvas (`todo-offcanvas`) slides in from the side via its client module's `data-*` hooks.
- To build a custom dialog instead, use the [overlay](./overlay.md) partial directly.
