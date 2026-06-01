# Kanban Board

The Kanban board is the center of gravity of the Korzinka Business admin dashboard. Every order in the system is rendered as a card; every column is an [`OrderStatusEnum`](../src/common/enums/order-status.enum.ts) value. Operators drive orders forward (or back) by dragging cards across columns — each drag is a state transition that the backend gates by role, validates against a transition matrix, and writes to the audit log.

This document explains how the board is wired, what each column means, which endpoints power it, and how state moves between columns.

---

## Columns

The board has one column per `OrderStatusEnum` value. Status transitions are constrained by [`ALLOWED_ORDER_TRANSITIONS`](../src/common/constants/orders.constants.ts).

| Column           | Meaning                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------ |
| `DRAFT`          | Sales manager has captured the order. No `code` assigned yet. Editable.                                |
| `CONFIRMED`      | Order accepted. `code = {YY}{LL}_{NNN}` is generated. May include backordered items.                   |
| `IN_COLLECTION`  | A picker is physically collecting items at the branch.                                                 |
| `PARTIAL`        | One or more items are awaiting backorder fulfillment from the main warehouse (2–3 day lead time).      |
| `READY`          | All items collected; order is staged for handover/delivery. Cash/card payments are marked here.        |
| `COMPLETED`      | Order handed off. `completedAt` stamped. Terminal.                                                     |
| `CANCELLED`      | Order aborted before completion. Terminal.                                                             |

---

## State Machine

```
DRAFT ──┐→ CONFIRMED ──┐→ IN_COLLECTION ⇄┬→ READY ──→ COMPLETED
        ↓              ↓                 ⇅↘ PARTIAL ──→ READY
        CANCELLED ←────┴─────────────────/
```

`READY` can step **back** to `IN_COLLECTION` (no payload, retains the existing picker) or to `PARTIAL` (requires fresh backorder declaration). `PARTIAL` can also step back to `IN_COLLECTION`. Both reverse paths are gated to `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` and exist so operators can recover from a premature READY / PARTIAL mark.

Reverse paths are **blocked for PAID cash/card orders** — unmark-paid first via `POST /orders/:id/unmark-paid` (ADMIN-only), run the reverse, then re-mark via `POST /orders/:id/mark-paid` once back in READY.

### Transition payload requirements

| From → To                   | Roles                                     | Payload                                                                                       |
| --------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| `DRAFT → CONFIRMED`         | `ADMIN`, `SCM`                            | Optional `backorderedItems: [{ itemId, backorderedQuantity }]`; optional `notes`              |
| `DRAFT → CANCELLED`         | `ADMIN`, `SALES_MANAGER`                  | —                                                                                             |
| `CONFIRMED → IN_COLLECTION` | `ADMIN`, `STORE_MANAGER`                  | Required `pickerId` (user must have role `PICKER`)                                            |
| `CONFIRMED → CANCELLED`     | `ADMIN`, `SALES_MANAGER`                  | —                                                                                             |
| `IN_COLLECTION → READY`     | `ADMIN`, `STORE_MANAGER`                  | — (fails if any item still BACKORDERED)                                                       |
| `IN_COLLECTION → PARTIAL`   | `ADMIN`, `STORE_MANAGER`                  | — (allowed only when ≥1 item is currently BACKORDERED; payload is a 400)                      |
| `IN_COLLECTION → CANCELLED` | `ADMIN`, `SALES_MANAGER`                  | —                                                                                             |
| `PARTIAL → READY`           | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | Required `arrivedItemIds: string[]` (each must currently be BACKORDERED on this order)        |
| `PARTIAL → IN_COLLECTION`   | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | Optional `pickerId` to reassign; otherwise picker is retained                                 |
| `PARTIAL → CANCELLED`       | `ADMIN`, `SALES_MANAGER`                  | —                                                                                             |
| `READY → COMPLETED`         | `ADMIN`, `STORE_MANAGER`                  | — (requires `paymentStatus = PAID`; stamps `completedAt = now()`)                             |
| `READY → IN_COLLECTION`     | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | Optional `pickerId` to reassign. Blocked for cash/card PAID orders                            |
| `READY → PARTIAL`           | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | Required `backorderedItems: [{ itemId, backorderedQuantity }]` (≥1). Blocked for cash/card PAID |

Any other `from → to` pair returns 400 (`Transition X → Y is not allowed`). Any allowed transition attempted by a role outside its row returns 403. The role gate for each transition lives in [`ORDER_TRANSITION_ROLES`](../src/common/constants/orders.constants.ts).

---

## Order Code

`code` is generated **on `DRAFT → CONFIRMED`**, not at insert. Format: `{YY}{LL}_{NNN}` (e.g. `26AA_001`).

- `YY` — last 2 digits of the year
- `LL` — letter pair cycling `AA → AB → … → AZ → BA → … → ZZ`
- `NNN` — 3-digit zero-padded counter (001–999), rolls to the next letter pair at 999

Scope is **global per year** (not per branch). Maximum 675,324 codes per year. DRAFT orders carry `code = null` until confirmed; a partial unique index `WHERE "code" IS NOT NULL` enforces uniqueness.

---

## Cards (List Endpoint)

`GET /orders` returns paginated [`OrderListItemDto`](../src/orders/dto/order-list-item.dto.ts) — the trimmed Kanban-card shape:

```
id, code, status, endDate, completedAt, paymentType, notes,
createdAt, updatedAt, totalAmount,
customer: { id, companyName },
branch:   { id, name, code },
contract: { id, contractNumber },
picker:   { id, name } | null,
backorderedItemsCount
```

Filters: `statuses[]`, `branchId`, `customerId`, `salesManagerId`, `paymentStatus`, `paymentType`, `deliveryType`, `from` / `to` (over `completedAt`, inclusive), `search`, `page`, `limit`. Ordered by `updatedAt DESC` — rows surface to the top whenever an order is touched (created, edited, transitioned, item status changed).

`salesManager` is **not** included in the list payload — fetch `GET /orders/:id` for full detail (used by the detail pane).

---

## Endpoints

All endpoints are documented at `/docs` (Swagger). Auth is JWT bearer; roles are enforced by `RolesGuard` per handler.

### Reading the board

| Method | Path                | Auth              | Description                                                                                                                                    |
| ------ | ------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET`  | `/orders`           | any authenticated | Paginated Kanban feed. Filterable by status, branch, customer, payment, delivery, completion date range, and full-text search. Card shape DTO. |
| `GET`  | `/orders/:id`       | any authenticated | Full detail — items (active only), customer, branch, contract, picker, sales manager. Powers the detail pane.                                  |
| `GET`  | `/orders/:id/logs`  | any authenticated | Audit timeline ordered `createdAt DESC`. Powers the status-change log in the detail pane.                                                      |

### Creating and editing an order

| Method   | Path                            | Roles                                                          | Description                                                                                                                                                              |
| -------- | ------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `POST`   | `/orders`                       | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER`, `SCM`, `ACCOUNTANT` | Create an order in `DRAFT`. Validates customer + branch + contract; copies `paymentType` from customer; applies `discountPercent` to each line. Optional `paymentStatus='paid'` is bank-only at create. |
| `PATCH`  | `/orders/:id/details`           | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER`                      | Edit `endDate` only. Allowed in `DRAFT` / `CONFIRMED` / `IN_COLLECTION` / `PARTIAL` / `READY`.                                                                            |
| `POST`   | `/orders/:id/items`             | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER`                      | Add one active item. Blocked while order is PAID — unmark-paid first.                                                                                                    |
| `PATCH`  | `/orders/:id/items/:itemId`     | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER`                      | Edit `quantity` and/or backorder state. Quantity edits blocked while PAID; backorder-only edits (status/quantity/notes) remain open on PAID orders.                      |
| `DELETE` | `/orders/:id/items/:itemId`     | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER`                      | Soft-delete one active item. Blocked while PAID. Cannot delete the last active item.                                                                                     |

### Driving the state machine

| Method | Path                          | Roles                                | Description                                                                                                                                       |
| ------ | ----------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST` | `/orders/:id/transitions`     | varies per transition (see table)    | The Kanban drag. Body: `{ nextStatus, pickerId?, backorderedItems?, arrivedItemIds?, notes? }`. Validated against `ALLOWED_ORDER_TRANSITIONS`.    |
| `POST` | `/orders/:id/mark-paid`       | bank → `ADMIN`/`ACCOUNTANT`; cash/card → all non-`PICKER`/`BASIC` | Flip `paymentStatus` `UNPAID → PAID`. Cash/card gated to `status = READY`; bank accepts any status.                                                |
| `POST` | `/orders/:id/unmark-paid`     | `ADMIN` only                         | Reverse mark-paid so a PAID order can be edited or rolled back from READY. Pings ACCOUNTANT via `payment.unmarked`.                              |

### Backorder queue (`SCM` view)

| Method | Path                                | Roles          | Description                                                                                                            |
| ------ | ----------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `GET`  | `/orders/backorder-items`           | `ADMIN`, `SCM` | Paginated queue grouped by product. Surfaces active BACKORDERED items in CONFIRMED / IN_COLLECTION / PARTIAL orders.   |
| `GET`  | `/orders/backorder-items/export`    | `ADMIN`, `SCM` | XLSX download of the same queue. Required `lang` (`uz` \| `ru`).                                                       |

### Analytics overlays

| Method | Path                                                          | Roles                                  | Description                                                                                                  |
| ------ | ------------------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `GET`  | `/orders/stats/totals`                                        | `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT` | Total orders, average paid amount, items per paid order, average completion seconds.                         |
| `GET`  | `/orders/stats/per-status-durations`                          | `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT` | Average seconds spent in each non-terminal status.                                                           |
| `GET`  | `/orders/stats/late`                                          | `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT` | Counts of late-completed and currently-overdue orders.                                                       |
| `GET`  | `/orders/stats/customer-retention/churned`                    | `ADMIN`, `SALES_MANAGER`, `SCM`        | Customers who ordered last month and not this month (Asia/Tashkent).                                         |
| `GET`  | `/orders/stats/customer-retention/avg-check-decline`          | `ADMIN`, `SALES_MANAGER`, `SCM`        | Customers whose this-month average order value dropped vs last month.                                        |
| `GET`  | `/orders/stats/customer-retention/engagement-ranking`         | `ADMIN`, `SALES_MANAGER`, `SCM`        | Engagement ranking by average days between orders (lowest = most frequent buyer).                            |

All `/orders/stats/*` responses are cached in Redis for 10–60s per query — the dashboard tolerates a brief delay vs. the live SQL.

---

## Detail Pane

Clicking a card opens the detail pane. It is rendered from three calls:

1. `GET /orders/:id` — full order including `items[].product`, `customer`, `branch`, `contract`, `salesManager`, `picker`.
2. `GET /orders/:id/logs` — the [`AuditLog`](../src/audit/entities/audit-log.entity.ts) timeline (`createdAt DESC`). Each `STATUS_CHANGE` row carries `fromState`, `toState`, and a `diff` containing per-item backorder changes when relevant. `UPDATE` rows cover detail edits, item add/update/delete, mark-paid, and unmark-paid. Item rows nest under `items.<id>` with `operation` (`add` / `update` / `delete`) and the product reference.
3. Role-gated action buttons that issue `POST /orders/:id/transitions`, `POST /orders/:id/items`, `PATCH /orders/:id/items/:itemId`, `DELETE /orders/:id/items/:itemId`, `POST /orders/:id/mark-paid`, or `POST /orders/:id/unmark-paid` depending on the order's current status, payment type, and the operator's role.

---

## Realtime Updates

The dashboard maintains **one** Socket.IO connection on namespace `/socket` (websocket-only) carrying a JWT in `handshake.auth.token`. The server emits a single event called `message` with a `{ type, payload, sentAt }` envelope; the client switches on `type`.

### Rooms joined on connect

- `user:<userId>` — always (target for per-user notification pings)
- `role:<role>` — always (reserved for role-targeted broadcasts; `products.imported` already uses it)
- `orders:all` — only when role is **not** `BASIC` (every Kanban operator joins this)

### Order-related event types

| `type`             | Room               | When                                                                                                                          |
| ------------------ | ------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `orders.changed`   | `orders:all`       | Any successful `OrdersService` mutator — `create`, `updateDetails` non-noop, `addItem`, `updateItem` non-noop, `deleteItem`, `transition`, `markPaid`. Carries the trimmed card. |
| `order.changed`    | `orders:<orderId>` | Same triggers — sent additionally to any client that issued `order.watch` on this order (the open detail pane).               |

Both events carry `OrderSocketPayload`:

```
{ action, orderId, branchId, actor, previousStatus?, nextStatus?, card }
```

`action` is one of: `created`, `updated`, `detailsUpdated`, `transitioned`, `paymentMarkedPaid`, `paymentMarkedUnpaid`, `itemAdded`, `itemUpdated`, `itemDeleted`. `card` is the same `OrderListItemDto` returned by `GET /orders`.

### Client-emitted events

| Event           | Body                  | Effect                                                                  |
| --------------- | --------------------- | ----------------------------------------------------------------------- |
| `order.watch`   | `{ orderId: string }` | Joins `orders:<orderId>` to receive `order.changed` for the open card. |
| `order.unwatch` | `{ orderId: string }` | Leaves `orders:<orderId>`.                                              |

### Source of truth

HTTP remains the source of truth — the socket carries hints to refetch. Socket emits happen **after** the DB transaction commits, never inside it. No-op mutators (e.g. `PATCH /orders/:id/details` with same `endDate`) skip the emit entirely. Offline clients catch up via `GET /orders` and `GET /notifications` on next page load; Redis pub/sub does not retain missed events.

---

## Notifications

Every transition and edit writes one or more `Notification` rows + per-user `NotificationRecipient` rows **inside the same transaction** as the state write. After commit, each recipient receives a `notification.created` + `notifications.unread_count_changed` ping on their `user:<id>` room. See [CLAUDE.md](../CLAUDE.md) — section *Notification triggers from `OrdersService`* — for the full mapping of trigger → recipient rule.

---

## Permissions Cheat Sheet

| Role            | Can drag                                                                                                                                                  |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ADMIN`         | Every transition.                                                                                                                                          |
| `SALES_MANAGER` | `DRAFT → CANCELLED`, `CONFIRMED → CANCELLED`, `IN_COLLECTION → CANCELLED`, `PARTIAL → CANCELLED`, all three reverse paths (`READY → IN_COLLECTION`, `READY → PARTIAL`, `PARTIAL → IN_COLLECTION`), `PARTIAL → READY`. |
| `STORE_MANAGER` | `CONFIRMED → IN_COLLECTION`, `IN_COLLECTION → READY`, `IN_COLLECTION → PARTIAL`, `PARTIAL → READY`, `READY → COMPLETED`, all three reverse paths.        |
| `SCM`           | `DRAFT → CONFIRMED` (warehouse confirmation).                                                                                                              |
| `ACCOUNTANT`    | Cannot drag. Can `POST /orders/:id/mark-paid` for bank orders.                                                                                             |
| `PICKER`        | Cannot drag. Receives `order.assigned_to_picker` notifications.                                                                                            |
| `BASIC`         | Cannot read the board. Does not join `orders:all`.                                                                                                         |

Branch-scoped permission checks (`STORE_MANAGER` only for their branch, etc.) are **not yet wired** — `RolesGuard` checks role only. Don't silently broaden existing `@Roles(...)` guards; confirm with the operator before changing a handler's gate.

---

## Auditing

Every `create`, detail/item edit, payment mark, transition, and unmark writes an [`AuditLog`](../src/audit/entities/audit-log.entity.ts) row inside the same `DataSource.transaction` as the state write. Action enum values:

- `CREATE` — new order
- `UPDATE` — detail edit, item add/update/delete, mark-paid, unmark-paid
- `STATUS_CHANGE` — transition (carries `fromState`, `toState`, and per-item diff when items flipped backorder state)
- `DELETE` — reserved for future entities

`actorUserId` is `SET NULL` on user deletion so the timeline survives staff turnover. The Kanban detail-pane timeline calls `GET /orders/:id/logs` and renders rows in `createdAt DESC` order.
