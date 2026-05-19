# Orders

## Order lifecycle

```
DRAFT ──┐→ CONFIRMED ──┐→ IN_COLLECTION ⇄┬→ READY ──→ COMPLETED
        ↓              ↓                 ⇅↘ PARTIAL ──→ READY
        CANCELLED ←────┴─────────────────/
```

`READY` can step back to `IN_COLLECTION` (no payload, retains the existing picker) or to `PARTIAL` (requires `backorderedItems`, mirroring `DRAFT → CONFIRMED`). Both reverse paths are gated to `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER`.

- **Order code** is generated on `DRAFT → CONFIRMED` as `KB-{BRANCH}-{YEAR}-{NNNN}`.
- **Backorders-first confirm**: `DRAFT → CONFIRMED` accepts optional `backorderedItems: [{ itemId, backorderedQuantity }]`. Listed items become `BACKORDERED`; unlisted items become `AVAILABLE` with `backorderedQuantity = 0`. The order always enters `CONFIRMED`.
- **Picker assignment**: `CONFIRMED → IN_COLLECTION` requires `pickerId` and the user must have role `PICKER`.
- **PARTIAL**: `IN_COLLECTION → PARTIAL` takes no payload and requires ≥1 active `BACKORDERED` item.

## Orders API

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| `POST`  | `/orders` | every role except `PICKER` and `BASIC` | Create an order. Requires `contractId` referencing one of the customer's active contracts. Copies `paymentType` from the customer, sets `deliveryType`, defaults `paymentStatus = UNPAID`, writes an audit row, and starts in `DRAFT` with `code = null`. `paymentStatus = paid` at create is bank-only. |
| `GET`   | `/orders` | any authenticated | Paginated Kanban feed. **Search & Filters:** `search` (matches `code` or customer `name`), `statuses`, `branchId`, `customerId`, `salesManagerId`, `paymentStatus`, `paymentType`, `from`, `to`, `page`, `limit`. Returns trimmed `OrderListItemDto` and `backorderedItemsCount`. |
| `GET`   | `/orders/:id` | any authenticated | Full order detail with active `items.product` and all relations. |
| `GET`   | `/orders/:id/logs` | any authenticated | Audit timeline for the order, newest first. |
| `PATCH` | `/orders/:id/details` | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER` | Edit `endDate` only. Allowed in `DRAFT`, `CONFIRMED`, `IN_COLLECTION`, `PARTIAL`, `READY`. Validated by `@IsNotInPast()`. No-op calls are skipped. |
| `POST`  | `/orders/:id/transitions` | varies per transition | Drive the state machine. Body includes `nextStatus`, `pickerId?`, `backorderedItems?`, `arrivedItemIds?`, `notes?`. `READY → COMPLETED` requires `paymentStatus = PAID`. |
| `POST`  | `/orders/:id/mark-paid` | depends on payment type | Flip `paymentStatus` from `UNPAID` to `PAID`. Bank orders require `ADMIN` or `ACCOUNTANT`; cash/card orders require any non-`PICKER`/`BASIC` role and the order must be `READY`. |
| `POST`  | `/orders/:id/unmark-paid` | `ADMIN` only | Flip `paymentStatus` from `PAID` back to `UNPAID` so paid orders can be edited. |

## Transition rules

| From → To | Roles | Required payload | Side-effect |
|-----------|-------|------------------|-------------|
| `DRAFT → CONFIRMED` | `ADMIN`, `SCM` | optional `backorderedItems` | Marks listed items `BACKORDERED`, unlisted items `AVAILABLE`, generates code, enters `CONFIRMED`. |
| `DRAFT → CANCELLED` | `ADMIN`, `SALES_MANAGER` | — | Cancel order. |
| `CONFIRMED → IN_COLLECTION` | `ADMIN`, `STORE_MANAGER` | `pickerId` | Assigns picker. |
| `CONFIRMED → CANCELLED` | `ADMIN`, `SALES_MANAGER` | — | Cancel order. |
| `IN_COLLECTION → READY` | `ADMIN`, `STORE_MANAGER` | — | Fails if any item is still `BACKORDERED`. |
| `IN_COLLECTION → PARTIAL` | `ADMIN`, `STORE_MANAGER` | — | Requires ≥1 `BACKORDERED` item. |
| `IN_COLLECTION → CANCELLED` | `ADMIN`, `SALES_MANAGER` | — | Cancel order. |
| `PARTIAL → READY` | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | `arrivedItemIds` | Resolves listed backordered items and requires no remaining `BACKORDERED` items. |
| `PARTIAL → IN_COLLECTION` | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | optional `pickerId` | Reverse path; retains or reassigns picker. |
| `PARTIAL → CANCELLED` | `ADMIN`, `SALES_MANAGER` | — | Cancel order. |
| `READY → COMPLETED` | `ADMIN`, `STORE_MANAGER` | — | Requires `PAID`; sets `completedAt`. |
| `READY → IN_COLLECTION` | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | optional `pickerId` | Reverse path; blocked if `PAID` and cash/card. |
| `READY → PARTIAL` | `ADMIN`, `STORE_MANAGER`, `SALES_MANAGER` | `backorderedItems` | Reverse path; declares backorders and writes item diffs. Blocked if `PAID` and cash/card. |

Any other transition pair is rejected. Roles are enforced by `ORDER_TRANSITION_ROLES`.
