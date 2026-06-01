# Picker — Order Flow, Permissions, and Endpoints

Pickers physically collect items at a branch for an order they've been assigned to. Their authority is narrow by design: they can advance **their own** assigned order through the picking phase, edit **stock state** (not quantity) on items, and attach/detach carts while the order is being collected. Everything else — confirming, cancelling, editing endDate, marking paid, completing — belongs to other roles.

## Where picker fits in the order lifecycle

```
DRAFT → CONFIRMED → IN_COLLECTION ⇄┬→ READY ──→ COMPLETED
                          ↑        ⇅↘ PARTIAL ──→ READY
                          └── (picker assigned here)
```

A picker becomes the `order.pickerId` on the `CONFIRMED → IN_COLLECTION` transition (driven by ADMIN or STORE_MANAGER, who pick the picker). From that moment on, the picker can act on this order until it leaves the picking phase. The order can bounce back into `IN_COLLECTION` from `READY` or `PARTIAL`; the existing `pickerId` is retained unless explicitly reassigned, so the same picker stays in scope.

## What "their own assigned order" means

Every picker-facing action enforces `order.pickerId === actor.id` inside the service (not just the controller role gate). If a picker calls an endpoint for an order they aren't assigned to, the server returns **403** with a picker-specific message. Role-only widening would let any picker touch any order — the assigned-only check is what enforces the "physically collects items" boundary.

## Actions a picker can perform

### 1. Advance their order through the picking phase

| Transition                  | When picker uses it                                                      |
| --------------------------- | ------------------------------------------------------------------------ |
| `IN_COLLECTION → READY`     | All items collected, nothing is BACKORDERED                              |
| `IN_COLLECTION → PARTIAL`   | At least one item is BACKORDERED (declared earlier or flipped mid-pick)  |
| `PARTIAL → READY`           | Remaining BACKORDERED items have arrived — resolve them in the same call |

Endpoint: `POST /orders/:id/transitions`

```json
{ "nextStatus": "READY" }
{ "nextStatus": "PARTIAL" }
{ "nextStatus": "READY", "arrivedItemIds": ["<itemId>", "<itemId>"] }
```

Rules picker must satisfy:

- `IN_COLLECTION → READY` fails (400) if **any** active item is still `BACKORDERED`.
- `IN_COLLECTION → PARTIAL` requires **≥1 active item** currently in `BACKORDERED` status (declare via the item-edit endpoint below if needed); passing `backorderedItems` on this transition is a 400.
- `PARTIAL → READY`'s `arrivedItemIds` flips each listed item to `AVAILABLE` with `backorderedQuantity = 0` in the same transaction; the call fails if any active item is still `BACKORDERED` after resolution.

Picker **cannot** perform: `DRAFT → CONFIRMED`, `* → CANCELLED`, `READY → COMPLETED`, or any reverse transition (`READY → IN_COLLECTION`, `READY → PARTIAL`, `PARTIAL → IN_COLLECTION`).

### 2. Edit backorder state on an item (stock-state only — never quantity)

Endpoint: `PATCH /orders/:id/items/:itemId`

```json
{ "status": "BACKORDERED", "backorderedQuantity": 5 }
{ "status": "AVAILABLE" }
{ "backorderedQuantity": 3 }
{ "notes": "..." }
```

Three supported operations:

- **Re-flag an available item as backordered** — `status=BACKORDERED` + `backorderedQuantity`
- **Resolve a backorder** — `status=AVAILABLE` (server forces `backorderedQuantity=0`)
- **Adjust the pending amount** — `backorderedQuantity` only (item must already be `BACKORDERED`)
- `notes` may ride along on any of the above

Rules picker must satisfy:

- Order must be in `CONFIRMED`, `IN_COLLECTION`, or `PARTIAL` for backorder fields.
- Picker must own the order (`order.pickerId === actor.id`) — otherwise **403** `Picker can only edit items on their own assigned order`.
- Payload must **not** include `quantity` — otherwise **403** `Picker cannot change item quantity; only backorder fields (status, backorderedQuantity, notes) are allowed`.
- In `CONFIRMED`, the order has no picker yet, so this endpoint is effectively only usable by pickers in `IN_COLLECTION` / `PARTIAL`.

Backorder-only edits stay open even on PAID orders — payment status is never touched (no `payment.recheck_required` fires). SCM is notified via `backorder.updated`.

Picker **cannot**: add new items (`POST /orders/:id/items`), delete items (`DELETE /orders/:id/items/:itemId`), or change `quantity`. Basket composition belongs to sales/store.

### 3. Attach / detach carts to their order

Carts are physical numbered trolleys at the branch. The pool is pre-created by ADMIN or STORE_MANAGER via `/carts`. Picker attaches/detaches them during collection.

| Method   | Endpoint                       | Body            |
| -------- | ------------------------------ | --------------- |
| `POST`   | `/orders/:id/carts`            | `{ "cartId" }`  |
| `DELETE` | `/orders/:id/carts/:cartId`    | —               |

Rules picker must satisfy:

- Order must be in `IN_COLLECTION` (both attach and detach share this gate — 400 otherwise). Once the order moves to `PARTIAL` / `READY`, carts ride along until `READY → COMPLETED` auto-frees them.
- Picker must own the order — otherwise **403** `Picker can only manage carts on their own assigned order`.
- Attach also validates: cart exists (404), cart `isActive=true` (400), cart not already attached (409), cart belongs to the same branch (400).
- Detach 404s if the cart isn't currently attached to this order (strict, not idempotent).

No notifications fire — cart events are logistics-only.

## Endpoints picker can call (full list)

### Read

All authenticated users — including pickers — can call these:

| Method | Endpoint                          | Notes                                                          |
| ------ | --------------------------------- | -------------------------------------------------------------- |
| `GET`  | `/auth/me`                        | Current user                                                   |
| `GET`  | `/orders`                         | Paginated Kanban feed (no picker-side filter today)            |
| `GET`  | `/orders/:id`                     | Full detail incl. items + product, customer, branch, carts     |
| `GET`  | `/orders/:id/logs`                | Audit timeline for the detail pane                             |
| `GET`  | `/products`                       | Catalog (tokenized fuzzy search)                               |
| `GET`  | `/products/:id`                   | One product                                                    |
| `GET`  | `/branches`, `/branches/:id`      | Branch list / detail                                           |
| `GET`  | `/customers`, `/customers/:id`    | Customer list / detail                                         |
| `GET`  | `/customers/:id/contracts`        | Contract list for a customer                                   |
| `GET`  | `/carts`, `/carts/:id`            | Cart pool — useful to find which carts at the branch are free  |
| `GET`  | `/notifications`                  | Picker's own notifications                                     |
| `GET`  | `/notifications/unread-count`     | Bell badge count                                               |

Picker **cannot** call: `/users`, `/users/pickers`, `/products/import/status`, `/orders/backorder-items*`, `/orders/stats/*` (role-gated to other roles).

### Write (picker-permitted)

| Method   | Endpoint                                  | Constraint                                                                                              |
| -------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `POST`   | `/orders/:id/transitions`                 | `IN_COLLECTION → READY`, `IN_COLLECTION → PARTIAL`, `PARTIAL → READY` — assigned order only             |
| `PATCH`  | `/orders/:id/items/:itemId`               | Backorder fields only (no `quantity`); assigned order only; order in CONFIRMED/IN_COLLECTION/PARTIAL    |
| `POST`   | `/orders/:id/carts`                       | Assigned order only; order in IN_COLLECTION; cart active + free + same branch                           |
| `DELETE` | `/orders/:id/carts/:cartId`               | Assigned order only; order in IN_COLLECTION                                                             |
| `PATCH`  | `/notifications/:id/read`                 | Mark one of picker's own notifications as read (idempotent)                                             |
| `PATCH`  | `/notifications/read-all`                 | Mark all of picker's notifications as read                                                              |

### Realtime (Socket.IO `/socket`)

Connect with JWT in `handshake.auth.token`. Pickers automatically join:

- `user:<userId>` — receives `notification.created` (e.g. `order.assigned_to_picker`) and `notifications.unread_count_changed`
- `role:picker` — reserved for future role broadcasts
- `orders:all` — receives `orders.changed` for every order (Kanban feed hint)

Optionally call `order.watch` with `{ orderId }` to also receive `order.changed` for a specific open detail pane; `order.unwatch` to leave.

## Notifications a picker receives

| `type`                       | When                                                                                                              |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `order.assigned_to_picker`   | On `CONFIRMED → IN_COLLECTION` (and reverse paths that land in IN_COLLECTION) — sent to the assigned `pickerId`  |

Pickers do not receive `order.created`, `order.confirmed`, `order.ready`, `order.completed`, payment events, or backorder events — those go to sales / store managers / SCM / accountants.

## Typical picker workflow

1. **Get pinged.** Store manager moves an order `CONFIRMED → IN_COLLECTION` and picks you; you receive `order.assigned_to_picker` over the socket.
2. **Open the order.** `GET /orders/:id` to see the items, customer, branch.
3. **Attach a cart.** `POST /orders/:id/carts` with a free cart at your branch.
4. **Collect items.** If an item is short or missing, flip it: `PATCH /orders/:id/items/:itemId` `{ "status": "BACKORDERED", "backorderedQuantity": N }`. SCM gets notified.
5. **Advance:**
   - All items collected → `POST /orders/:id/transitions` `{ "nextStatus": "READY" }`
   - Some items backordered → `POST /orders/:id/transitions` `{ "nextStatus": "PARTIAL" }`
6. **Backorders arrive (still your order in PARTIAL).** Resolve in bulk via the transition: `POST /orders/:id/transitions` `{ "nextStatus": "READY", "arrivedItemIds": [...] }`. Or resolve individually with `PATCH /orders/:id/items/:itemId` `{ "status": "AVAILABLE" }`.
7. **Hand off.** Store manager runs `READY → COMPLETED` (after the order is marked PAID by the right role). Your carts are auto-freed.

## Picker-specific error messages (cheat sheet)

| Status | Message                                                                                                         | Cause                                                                                              |
| ------ | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| 403    | `Picker can only advance their own assigned order`                                                              | Transition call on an order where `order.pickerId !== actor.id`                                   |
| 403    | `Picker can only edit items on their own assigned order`                                                        | `PATCH /orders/:id/items/:itemId` on an unassigned order                                          |
| 403    | `Picker cannot change item quantity; only backorder fields (status, backorderedQuantity, notes) are allowed`    | Picker payload included `quantity`                                                                |
| 403    | `Picker can only manage carts on their own assigned order`                                                      | Cart attach/detach on an unassigned order                                                          |
| 400    | `Cart belongs to a different branch`                                                                            | Cart `branchId` ≠ order `branchId` on attach                                                       |
| 409    | `Cart is already attached to another order`                                                                     | Cart `orderId` is non-null on attach                                                               |
| 400    | (cart attach/detach status gate)                                                                                | Order is not in `IN_COLLECTION`                                                                    |
| 400    | `Transition X → Y is not allowed`                                                                               | Picker tried a non-permitted transition (e.g. `READY → COMPLETED`)                                |

## Things a picker explicitly cannot do

- Create / cancel / confirm orders
- Edit `endDate` (`PATCH /orders/:id/details`)
- Add or delete order items
- Change item `quantity`
- Mark / unmark paid
- Complete an order
- Manage the cart pool (`POST /carts`, `PATCH /carts/:id`, `DELETE /carts/:id`)
- Reassign themselves or another picker
- Use any reverse transition (`READY → *`, `PARTIAL → IN_COLLECTION`)
- Access staff, branch, customer, or product write endpoints
- Access the backorder queue (`GET /orders/backorder-items*`) or analytics (`/orders/stats/*`)
