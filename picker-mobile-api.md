# Picker API Guide (Mobile App)

Everything the picker mobile app needs: what a `picker` is allowed to do, which endpoints to call, exact payloads, error messages, and realtime events. All routes mount at the root (no global prefix). Interactive API docs live at `/docs` (Swagger, bearer auth).

**On-the-wire enum values are lowercase strings**: order statuses are `draft | confirmed | in_collection | partial | ready | out_for_delivery | completed | cancelled`; item statuses are `available | backordered`; the role is `picker`.

---

## 1. Who is a picker

A picker is a single-branch warehouse worker who physically collects items for an order. They enter the workflow when a store manager runs the `CONFIRMED → IN_COLLECTION` transition and selects them (`order.pickerId` is set at that moment; the picker receives an `order.assigned_to_picker` notification).

**The one rule that governs everything:** on top of the role check, every picker-facing write is scoped to *their own assigned order* — the service layer verifies `order.pickerId === actor.id` and returns **403** otherwise. A picker can never touch an order assigned to someone else, and never an order with no picker yet (e.g. `CONFIRMED` orders have `pickerId = null`, so all picker writes are rejected there).

What a picker **can** do:

| Capability | Endpoint |
| --- | --- |
| Log in / get own profile | `POST /auth/login`, `GET /auth/me` |
| Browse orders (read-only, any order) | `GET /orders`, `GET /orders/:id`, `GET /orders/:id/logs` |
| Flag / adjust / resolve an item's backorder state on their assigned order | `PATCH /orders/:id/items/:itemId` |
| Advance their assigned order: `in_collection → ready`, `in_collection → partial`, `partial → ready` | `POST /orders/:id/transitions` |
| Attach / detach physical carts (trolleys) while picking | `POST /orders/:id/carts`, `DELETE /orders/:id/carts/:cartId` |
| Read reference data | `GET /products*`, `GET /branches*`, `GET /customers*`, `GET /carts*` (all read-only) |
| Notifications (bell) | `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all` |
| Realtime updates | Socket.IO namespace `/socket` |

What a picker **cannot** do (hard limits, all enforced server-side):

- Create, cancel, confirm, or complete orders. Terminal legs (`ready → completed`, `ready → out_for_delivery`, `out_for_delivery → completed`) and all reverse transitions are store-manager/admin territory.
- Change an item's **`quantity`**, add items, or delete items — basket composition belongs to sales/store managers. `POST /orders/:id/items` and `DELETE /orders/:id/items/:itemId` reject the role outright; a `PATCH` payload containing `quantity` returns 403.
- Edit order details (`PATCH /orders/:id/details`), mark orders paid/unpaid, or touch payment in any way.
- Write to products, branches, customers, users, or cart CRUD (`POST/PATCH/DELETE /carts`).
- Call `GET /users/pickers` (that's the admin/store-manager picker-selection list, not for this app).

---

## 2. Authentication

### `POST /auth/login` (public)

```json
{ "username": "picker01", "password": "secret" }
```

Response:

```json
{
  "accessToken": "<JWT>",
  "user": {
    "id": "uuid",
    "name": "Aziz",
    "username": "picker01",
    "role": "picker",
    "isActive": true,
    "createdAt": "...",
    "updatedAt": "..."
  }
}
```

- Username lookup is case-insensitive; the user must be `isActive = true`.
- Send the token on every request: `Authorization: Bearer <accessToken>`.
- `GET /auth/me` returns the authenticated user — use it to restore a session on app launch. **Cache `user.id`** — it's what you compare against `order.pickerId` / `picker.id` everywhere.
- There is no refresh-token endpoint; on 401, re-login.

---

## 3. Finding "my orders"

### `GET /orders` — paginated Kanban feed (any authenticated user)

Useful query params: `statuses` (repeat or comma-separate, e.g. `?statuses=in_collection,partial`), `branchId`, `search`, `page`, `limit` (default 20, max 100). Ordered by `updatedAt DESC`.

> ⚠️ **There is no `pickerId` filter on this endpoint today.** The app must fetch by status/branch and filter client-side on `picker?.id === myUserId`. If the order volume makes this painful (~100 orders/day currently, so it's fine), ask the backend team to add a `pickerId` query param — it's a small change.

Each row is a trimmed `OrderListItemDto`:

```json
{
  "id": "uuid",
  "code": "26AA_001",
  "status": "in_collection",
  "endDate": "...",
  "completedAt": null,
  "paymentType": "bank_prepayment",
  "notes": null,
  "totalAmount": "1250000.00",
  "customer": { "id": "uuid", "companyName": "OOO Example" },
  "branch": { "id": "uuid", "name": "Chilanzar", "code": "CHI" },
  "contract": { "id": "uuid", "contractNumber": "K-2026-14" },
  "picker": { "id": "uuid", "name": "Aziz" },
  "backorderedItemsCount": 2,
  "cartsCount": 1,
  "createdAt": "...",
  "updatedAt": "..."
}
```

Response envelope: `{ "data": [...], "meta": { "page", "limit", "total", "totalPages" } }`.

### `GET /orders/:id` — full detail

Includes active `items` (soft-deleted lines excluded) with the joined `product`, plus `carts: { id, cartNumber }[]` and all relations. This backs the main picking screen.

### `GET /orders/:id/logs` — audit timeline

Every create / edit / transition / payment event, joined with the actor, newest first. Use for an order-history screen.

> **Numbers come as strings.** `totalAmount`, `quantity` (`"10.000"`, scale 3), `backorderedQuantity`, `originalPrice`, `discountedPrice` are Postgres `numeric` columns serialized as strings. Parse with a decimal-safe routine; send them back as strings too.

---

## 4. Editing item backorder state

### `PATCH /orders/:id/items/:itemId`

The picker's main tool during collection: flag an item as short, adjust the pending amount, or resolve it when stock arrives.

Body (`UpdateOrderItemDto` — all optional, but at least one of `status` / `backorderedQuantity` required for a picker; **never send `quantity`**):

| Field | Type | Meaning |
| --- | --- | --- |
| `status` | `"available"` \| `"backordered"` | Flip the line's stock state |
| `backorderedQuantity` | decimal string, e.g. `"2.500"` | Pending amount. Required when flipping to `backordered`. Must be `> 0` and `≤` the line's `quantity` |
| `notes` | string ≤ 2000 | Optional free text riding along |

The three supported operations:

```jsonc
// 1. Flag an available item as short
{ "status": "backordered", "backorderedQuantity": "2.500", "notes": "only 7.5 of 10 on shelf" }

// 2. Adjust the pending amount (item must already be backordered)
{ "backorderedQuantity": "1.000" }

// 3. Resolve — stock arrived (server forces backorderedQuantity to 0)
{ "status": "available" }
```

Rules enforced server-side:

- **Assigned order only** — `order.pickerId === you`, else 403 `Picker can only edit items on their own assigned order`.
- **No quantity** — payload containing `quantity` → 403 `Picker cannot change item quantity; only backorder fields (status, backorderedQuantity, notes) are allowed`.
- **Order status** — backorder fields are only accepted while the order is `confirmed`, `in_collection`, or `partial` (for a picker, effectively `in_collection` / `partial`, since `pickerId` is null before that). 400 otherwise.
- **PAID orders are fine** — backorder-only edits are deliberately allowed even when `paymentStatus = "paid"`; they can't change the total.
- No-op calls (same values) succeed but skip audit/socket/notifications.

Side effects: audit row on the timeline; SCM gets a `backorder.updated` notification when backorder state actually changed; the Kanban card refreshes via socket.

---

## 5. Advancing the order (transitions)

### `POST /orders/:id/transitions`

Body: `{ "nextStatus": "...", ...payload, "notes?": "≤2000 chars" }`. Pickers may perform exactly three transitions, **all only on their assigned order** (403 `Picker can only advance their own assigned order` otherwise):

| Transition | Body | Server-side rule |
| --- | --- | --- |
| `in_collection → ready` | `{ "nextStatus": "ready" }` | Fails 400 if **any** active item is still `backordered` |
| `in_collection → partial` | `{ "nextStatus": "partial" }` | Requires **≥ 1** active item currently `backordered` (flag them first via the item PATCH), else 400. Sending `backorderedItems` here is a 400 — declare backorders via the item endpoint |
| `partial → ready` | `{ "nextStatus": "ready", "arrivedItemIds": ["itemUuid", ...] }` | Each listed id must be an active `backordered` item on this order; they're flipped to `available` with `backorderedQuantity = 0`. Fails 400 if any item is **still** backordered afterwards — the call must resolve everything (or resolve individually via the item PATCH first and send the rest) |

`arrivedItemIds` is optional in the DTO — omit it if you already resolved every backorder via item edits and just need the status flip.

Typical picking loop:

1. Everything on the shelf → `{ "nextStatus": "ready" }`. Done.
2. Something short → PATCH each short line to `backordered`, then `{ "nextStatus": "partial" }`. The order waits for the main-warehouse delivery (2–3 days).
3. Stock arrives → `{ "nextStatus": "ready", "arrivedItemIds": [...] }` (or resolve line-by-line, then transition).

Note: an order can bounce back to you — store managers can run `ready → in_collection` or `partial → in_collection` (you stay assigned unless they reassign) and you'll get a fresh `order.assigned_to_picker` ping.

---

## 6. Carts (physical trolleys)

Carts are numbered per-branch trolleys. The picker grabs free ones and links them to the order so everyone knows which trolleys hold which order.

| Action | Endpoint | Notes |
| --- | --- | --- |
| Browse pool | `GET /carts?branchId=...&availability=available&isActive=true` | Also `search` (ILIKE on `cartNumber`), pagination. `availability` is `available` \| `in_use` |
| Attach | `POST /orders/:id/carts` body `{ "cartId": "uuid" }` | 201 |
| Detach | `DELETE /orders/:id/carts/:cartId` | 204 |

Rules (attach and detach are symmetric):

- **Only while the order is `in_collection`** — 400 `Carts can only be attached or detached while the order is IN_COLLECTION (current: <status>)`. Once the order moves to `partial`/`ready`, carts ride along and are auto-freed when the order completes.
- **Assigned order only** — 403 `Picker can only manage carts on their own assigned order`.
- Attach validates: cart exists (404), `isActive` (400 `Cart is inactive`), free (409 `Cart is already attached to another order`), same branch as the order (400 `Cart belongs to a different branch`).
- Detach returns 404 if the cart isn't currently on this order (not idempotent).
- Cart events write audit rows but fire **no notifications** — logistics only.

---

## 7. Notifications (bell menu)

| Endpoint | Returns |
| --- | --- |
| `GET /notifications?page=&limit=&isRead=` | Paginated list, newest first. Each row: `{ id, notificationId, type, entityType, entityId, title, body, data, readAt, createdAt }` — **`id` is the per-user recipient row id**, use it for mark-read |
| `GET /notifications/unread-count` | `{ "unreadCount": 3 }` — badge |
| `PATCH /notifications/:id/read` | Marks one read (idempotent). 404 if the row belongs to someone else |
| `PATCH /notifications/read-all` | `{ "updated": n }` |

The notification type a picker receives is **`order.assigned_to_picker`** — fired when they're assigned on `CONFIRMED → IN_COLLECTION`, on reassignment, and when an order reverses back into `in_collection`. `entityType` is `"order"` and `entityId` is the order id — deep-link to the order screen.

---

## 8. Realtime (Socket.IO)

- **Connect:** namespace **`/socket`**, transport **websocket only** (no polling fallback), JWT in the handshake:

  ```js
  const socket = io(`${BASE_URL}/socket`, {
    transports: ['websocket'],
    auth: { token: accessToken },
  });
  ```

  Invalid/missing token → immediate disconnect.

- **Rooms joined automatically:** `user:<yourId>`, `role:picker`, and `orders:all` (every non-BASIC user gets all order events today — filter client-side by `payload.card.picker?.id` or `payload.orderId`).

- **Everything arrives as one event named `message`** with envelope `{ type, payload, sentAt }`. Switch on `type`:

  | `type` | Payload | Use in the app |
  | --- | --- | --- |
  | `orders.changed` | `{ action, orderId, branchId, actor, previousStatus?, nextStatus?, card }` — `card` is the same `OrderListItemDto` as `GET /orders` | Refresh the order list / patch the card in place |
  | `order.changed` | same shape | Fires only for orders you explicitly watch |
  | `notification.created` | notification row + `unreadCount` | Show a push-style banner, bump the badge |
  | `notifications.unread_count_changed` | `{ unreadCount }` | Sync the badge |

- **Watching one order:** while the order screen is open, emit `order.watch` with `{ orderId }` to join `orders:<orderId>`; emit `order.unwatch` on leave.

- **Sockets are hints, not truth.** Redis pub/sub doesn't replay missed events — after reconnect or app resume, refetch `GET /orders` and `GET /notifications/unread-count`.

---

## 9. Error catalog

All errors use the standard shape `{ statusCode, message, error, timestamp, path }`.

| Status | Message (exact) | When |
| --- | --- | --- |
| 401 | — | Missing/expired/invalid JWT → re-login |
| 403 | `Picker can only advance their own assigned order` | Transition on someone else's order |
| 403 | `Picker can only edit items on their own assigned order` | Item PATCH on someone else's order |
| 403 | `Picker cannot change item quantity; only backorder fields (status, backorderedQuantity, notes) are allowed` | Item PATCH payload includes `quantity` |
| 403 | `Picker can only manage carts on their own assigned order` | Cart attach/detach on someone else's order |
| 403 | (role guard) | Any endpoint outside the allowed set (create order, add/delete item, mark paid, etc.) |
| 400 | `Transition <from> → <to> is not allowed` | Illegal state-machine move |
| 400 | (≥1 backordered item required) | `in_collection → partial` with no backordered items |
| 400 | (item still BACKORDERED) | `in_collection → ready` / `partial → ready` with unresolved backorders |
| 400 | `Carts can only be attached or detached while the order is IN_COLLECTION (current: <status>)` | Cart mutation outside `in_collection` |
| 400 | `Cart is inactive` / `Cart belongs to a different branch` | Attach validation |
| 409 | `Cart is already attached to another order` | Double attach |
| 404 | — | Unknown order/item/cart id, or detaching a cart not on this order |

Also: unknown body fields are rejected with 400 (`forbidNonWhitelisted` is on globally) — send only documented fields.

---

## 10. Suggested app flow

1. **Login** → store token + `user.id`.
2. **Connect socket** with the token.
3. **Home: "My orders"** — `GET /orders?statuses=in_collection,partial`, client-side filter `picker?.id === myId`, live-update from `orders.changed`.
4. **Order screen** — `GET /orders/:id`, emit `order.watch`. Show items with per-line status, carts, timeline (`/logs`).
5. **Pick** — attach carts as needed; check off lines; flag shortages via item PATCH (`backordered` + amount).
6. **Finish** — all available → transition to `ready`; any shortage → transition to `partial`.
7. **Backorder arrival** (order re-surfaces in `partial`, or reassignment ping arrives) — resolve items, transition `partial → ready` with `arrivedItemIds`.
8. **Notifications tab** — list + unread badge; deep-link `order.assigned_to_picker` to the order screen.

## Known gaps to raise with the backend team

- **No `pickerId` filter on `GET /orders`** — client-side filtering is required for the "my orders" list.
- **No refresh token** — plan the UX around JWT expiry (silent re-login or biometric re-auth).
- Branch-scoped permission checks (`hasPermission(userId, action, branchId)`) are not wired yet; the `orders:all` socket room means pickers receive events for all branches — filter in the app.
