# Order Items

## Item behavior

- `OrderItem.status` defaults to `AVAILABLE` on create.
- Backorders are declared at confirm time via `backorderedItems: [{ itemId, backorderedQuantity }]`.
- Unlisted items during confirm are set to `AVAILABLE` with `backorderedQuantity = 0`.
- `IN_COLLECTION → PARTIAL` takes no payload and requires at least one active `BACKORDERED` item.
- `PARTIAL → READY` accepts `arrivedItemIds: string[]` to resolve backordered items; the transition fails if any active item remains `BACKORDERED` afterward.

## Item CRUD without transitions

Available while order status is `DRAFT`, `CONFIRMED`, `IN_COLLECTION`, `PARTIAL`, or `READY`.

- `PATCH /orders/:id/details`
- `POST /orders/:id/items`
- `PATCH /orders/:id/items/:itemId`
- `DELETE /orders/:i/items/:itemId`

Item delete is a soft-delete via `OrderItem.deletedAt`. The last active item cannot be deleted. Changing a product means deleting the old line and adding a new line.

## PAID order rules

- When `paymentStatus = PAID`:
  - `POST /orders/:id/items` is blocked.
  - `DELETE /orders/:id/items/:itemId` is blocked.
  - `PATCH /orders/:id/items/:itemId` is blocked only when `quantity` is changed.
- Backorder-only item PATCHes remain allowed so picker/SCM can track stock changes without unmarking paid.
- `quantity * discountedPrice` is the only contributor to `totalAmount`, so backorder-only edits do not change payment amount.
- To change quantity or basket composition on a PAID order, ADMIN must use `POST /orders/:id/unmark-paid` first.

## Adding Items via Product Search Flow

To fully implement adding a new item from the frontend, follow this functional flow:
1. **Search Products**: Use `GET /products?search={query}&isActive=true` to fetch available products. The backend handles multi-word fuzzy matching (`name`) or literal matching (`sku`, `barcode`).
2. **Select Product**: Present the search results to the user (e.g., in a dropdown or search modal).
3. **Set Quantity**: The user selects the `productId` and specifies the desired `quantity`.
4. **Create Item**: Call `POST /orders/:id/items` with the `productId` and `quantity`.
5. **Update UI**: On success, the backend recalculates the order's `totalAmount` and triggers an `order.details_updated` event if connected via WebSockets. Re-fetch or locally update the order items list.

## Item endpoints

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| `GET`    | `/products` | any authenticated | Use this to search for products before adding them as items. Supports `search` (fuzzy transliteration match on `name` or literal match on `sku`/`barcode`), `isActive`, and pagination. |
| `POST`  | `/orders/:id/items` | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER` | Add one active item. Requires `productId`, `quantity`, optional `originalPrice`. Allowed only when `paymentStatus = UNPAID`. Rejects inactive/unknown products and duplicate active product lines. |
| `PATCH` | `/orders/:id/items/:itemId` | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER` | Edit an active item. Body may include `quantity`, `status`, `backorderedQuantity`, `notes`. At least one field is required. `status` / `backorderedQuantity` changes are only accepted in `CONFIRMED`, `IN_COLLECTION`, or `PARTIAL`. |
| `DELETE` | `/orders/:id/items/:itemId` | `ADMIN`, `SALES_MANAGER`, `STORE_MANAGER` | Soft-delete an item. Disallowed if it would leave the order with zero active items. |

## Backorder edit rules

- `PATCH /orders/:id/items/:itemId` supports:
  - full resolve: `status = AVAILABLE` forces `backorderedQuantity = 0`
  - re-flag available → backordered: `status = BACKORDERED` with positive `backorderedQuantity`
  - adjust pending amount: `backorderedQuantity` only on an existing `BACKORDERED` item
- SCM receives `backorder.updated` notifications when status or quantity changes, and when a backordered active item is deleted.
- `order.details_updated` also notifies SCM when `addItem` or `deleteItem` occurs, so warehouse staff see item-composition changes.
