# Cart Attach / Detach — Order Flow for ADMIN and PICKER

Physical numbered trolleys ("carts") are attached to an order while it is being picked, then auto-freed when the order completes. Two roles can attach and detach during the picking phase: **ADMIN** (cross-branch, no order-ownership check) and the **PICKER** assigned to the order. The pool itself (creating new carts, deactivating retired ones) belongs to ADMIN and STORE_MANAGER and is documented at the bottom — it is not part of the per-order attach/detach flow.

## Where this fits in the order lifecycle

```
DRAFT → CONFIRMED → IN_COLLECTION ⇄┬→ READY ──→ COMPLETED
                          ▲        ⇅↘ PARTIAL ──→ READY
                          │                              │
                  attach / detach                  auto-free on
                  allowed here only                 READY → COMPLETED
```

Cart attach/detach is a **logistics** event, not a state-machine event:

- It does **not** transition the order.
- It does **not** fire any notifications (no `order.*`, no SCM/accountant ping).
- It writes to the audit timeline (`AuditAction = UPDATE`) and emits an `order.changed` socket event with `action: 'cartAttached'` / `'cartDetached'` so the Kanban detail pane refreshes.

## Endpoints

| Method   | Endpoint                                  | Body            |
| -------- | ----------------------------------------- | --------------- |
| `POST`   | `/orders/:id/carts`                       | `{ "cartId" }`  |
| `DELETE` | `/orders/:id/carts/:cartId`               | —               |

Both endpoints are gated to `@Roles(UserRole.ADMIN, UserRole.PICKER)` at the controller. PICKER actors are then narrowed to their assigned order inside `OrderCartsMutationService` (see "Picker ownership check" below).

## The single status gate: order must be in `IN_COLLECTION`

Both attach and detach reject with **400** when the order is in any status other than `IN_COLLECTION`:

```
Carts can only be attached or detached while the order is IN_COLLECTION (current: <status>)
```

This is the **symmetric** rule that drives the whole flow:

- `DRAFT` / `CONFIRMED` — too early; no picker has been assigned yet.
- `PARTIAL` / `READY` — too late; once the order has moved past `IN_COLLECTION`, attached carts ride along until the order completes.
- `COMPLETED` / `CANCELLED` — terminal; carts are already freed (or were never attached).

To detach a cart that has carried into `PARTIAL` / `READY`, an ADMIN or SALES_MANAGER / STORE_MANAGER must first walk the order back via a reverse transition (`READY → IN_COLLECTION` or `PARTIAL → IN_COLLECTION`); from `IN_COLLECTION` the picker or ADMIN can then detach.

## Picker ownership check (PICKER actors only)

`OrderCartsMutationService.assertActorAllowed`:

```
if (actor.role === PICKER && order.pickerId !== actor.id)
  → 403  Picker can only manage carts on their own assigned order
```

ADMIN actors skip this check entirely — they may attach/detach on any branch's order.

## Attach — `POST /orders/:id/carts`

Body:

```json
{ "cartId": "<uuid>" }
```

Validations, in order:

1. **Order exists** — 404 otherwise (`Order ... was not found`).
2. **Actor allowed** — PICKER must own the order (403 above); ADMIN always passes.
3. **Order status is `IN_COLLECTION`** — 400 otherwise (message above).
4. **Cart exists** — 404 (`Cart <cartId> was not found`).
5. **Cart is active** — 400 (`Cart <cartId> is inactive`). Deactivated trolleys (e.g. broken, retired) cannot be attached.
6. **Cart is free** — 409 (`Cart <cartId> is already attached to another order`). Detach from the other order first.
7. **Same branch** — 400 (`Cart <cartId> belongs to a different branch`). Carts are branch-bound; cross-branch attach is rejected.

On success, inside one DB transaction:

- `cart.orderId = order.id` saved
- `order.updatedAt` bumped (so the Kanban card surfaces to the top of the feed)
- Audit `UPDATE` row written with diff:
  ```json
  { "carts.<cartId>": { "operation": "attach", "cart": { "id": "<cartId>", "cartNumber": "<n>" } } }
  ```

After commit:

- Socket `order.changed` / `orders.changed` event emitted with `action: 'cartAttached'` and the trimmed `OrderListItemDto` (whose `cartsCount` now reflects the new attach).
- **No notifications fire.**

Response: `201 Created` with the full order detail (post-attach).

## Detach — `DELETE /orders/:id/carts/:cartId`

Validations, in order:

1. **Order exists** — 404.
2. **Actor allowed** — PICKER must own the order (403); ADMIN always passes.
3. **Order status is `IN_COLLECTION`** — 400 (same message as attach).
4. **Cart exists** — 404.
5. **Cart is currently attached to this order** — 404 if `cart.orderId !== order.id` (`Cart <cartId> is not attached to order <orderId>`). This is **strict**, not idempotent — re-running a detach on an already-free cart 404s rather than no-ops, so the caller knows their model of "what's on this order" is stale.

On success, inside one DB transaction:

- `cart.orderId = null` saved
- `order.updatedAt` bumped
- Audit `UPDATE` row written with diff:
  ```json
  { "carts.<cartId>": { "operation": "detach", "cart": { "id": "<cartId>", "cartNumber": "<n>" } } }
  ```

After commit:

- Socket `order.changed` / `orders.changed` event emitted with `action: 'cartDetached'`.
- **No notifications fire.**

Response: full order detail (post-detach).

## Auto-free on `READY → COMPLETED`

Once the order is collected and marked PAID, STORE_MANAGER (or ADMIN) drives `READY → COMPLETED`. Inside that same transaction `OrderTransitionService` calls `CartLookupService.loadActiveCartsForOrder(em, order.id)` and runs:

```sql
UPDATE carts SET orderId = NULL WHERE orderId = <order.id>;
```

The freed cart ids/numbers are merged into the `STATUS_CHANGE` audit row under `diff.cartsFreed`:

```json
{
  "cartsFreed": [
    { "id": "...", "cartNumber": "12" },
    { "id": "...", "cartNumber": "7" }
  ]
}
```

If the order had no carts attached, no UPDATE runs and `cartsFreed` is absent. This is the **only** automatic detach — there is no auto-free on cancellation or on reverse transitions.

## What the order payload exposes

- `GET /orders` (`OrderListItemDto`) — `cartsCount: number` (carts currently attached to the order).
- `GET /orders/:id` — full `carts: { id, cartNumber }[]` array (only carts currently attached; auto-freed carts are gone).
- `GET /orders/:id/logs` — every attach / detach surfaces as an `UPDATE` audit row with the `carts.<cartId>` diff entry, and `STATUS_CHANGE` rows for `READY → COMPLETED` carry `cartsFreed`.

## Finding a cart to attach

The picker / admin can list available carts at a branch via:

```
GET /carts?branchId=<branchId>&availability=available
```

`availability=available` filters to `isActive=true AND orderId IS NULL`. The pool itself (creating, renaming, deactivating carts) is owned by ADMIN and STORE_MANAGER via `/carts` CRUD — see `CLAUDE.md` → "Carts" for that surface. PICKER cannot create or deactivate carts; they can only read the pool and attach/detach to their own order.

## Error cheat sheet

| Status | Message                                                                                                          | Cause                                                                                  |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 400    | `Carts can only be attached or detached while the order is IN_COLLECTION (current: <status>)`                    | Order is in DRAFT / CONFIRMED / PARTIAL / READY / COMPLETED / CANCELLED                |
| 400    | `Cart <cartId> is inactive`                                                                                      | Attempting to attach a deactivated cart                                                |
| 400    | `Cart <cartId> belongs to a different branch`                                                                    | Attach with a cart from a branch other than `order.branchId`                           |
| 403    | `Picker can only manage carts on their own assigned order`                                                       | PICKER calling attach/detach on an order where `order.pickerId !== actor.id`           |
| 404    | `Order ... was not found`                                                                                        | Unknown order id                                                                       |
| 404    | `Cart <cartId> was not found`                                                                                    | Unknown cart id                                                                        |
| 404    | `Cart <cartId> is not attached to order <orderId>`                                                               | Detach when the cart is on a different order, or already free                          |
| 409    | `Cart <cartId> is already attached to another order`                                                             | Attach when the cart's `orderId` is already non-null                                   |

## Typical flows

### Picker — happy path

1. Store manager runs `CONFIRMED → IN_COLLECTION` and picks you; you receive `order.assigned_to_picker`.
2. `GET /carts?branchId=<yourBranch>&availability=available` to find a free trolley.
3. `POST /orders/:id/carts { "cartId": "<chosen>" }` to attach.
4. Collect items; if you swap to a different trolley mid-pick, detach the old one and attach the new one. Both calls must happen while the order is still in `IN_COLLECTION`.
5. Advance to `READY` (or `PARTIAL` → `READY`). Carts ride along; do **not** try to detach in `PARTIAL` / `READY`.
6. Once the store manager completes the order, every attached cart is auto-freed; you don't need to detach.

### Admin — corrective action

- A cart was attached to the wrong order during collection. ADMIN calls `DELETE /orders/:id/carts/:cartId` while the order is still in `IN_COLLECTION` — no ownership check applies.
- A cart needs to be retrieved from an order that has already moved to `PARTIAL` / `READY`. ADMIN (or SALES_MANAGER / STORE_MANAGER) runs the reverse transition (`READY → IN_COLLECTION` or `PARTIAL → IN_COLLECTION`) first, then detaches.
- A cart's `cartNumber` was mistyped at pool creation. ADMIN renames via `PATCH /carts/:id { "cartNumber": "..." }` — does **not** require detach (rename is a pool-level edit).

## Things ADMIN / PICKER explicitly cannot do via this flow

- Attach or detach while the order is **not** in `IN_COLLECTION` (no exceptions; reverse-transition first).
- Attach a cart from a different branch.
- Attach an inactive cart, or one already attached elsewhere.
- Bulk-attach more than one cart in a single call (one cart per `POST`; repeat for multiple).
- Trigger notifications from cart events (none fire — by design).
- Reassign a cart between orders in one call (must detach, then attach).
- PICKER: touch carts on an order they're not assigned to.
- PICKER: create / rename / deactivate carts in the pool (`POST /carts`, `PATCH /carts/:id`, `DELETE /carts/:id` are ADMIN + STORE_MANAGER only).
