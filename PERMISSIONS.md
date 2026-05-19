# Role Permissions & Restrictions

The Korzinka Business system uses a role-based access control (RBAC) model. Below are the specific permissions and restrictions for each role. Roles are assigned to users per-branch (except for globally scoped roles).

## 1. ADMIN
**Scope:** Cross-region, cross-branch
**Responsibility:** Full system control, operations oversight, and user management.

**Permissions:**
- Full CRUD access to **Staff** (`/users`), **Products** (`/products`), **Branches** (`/branches`), and **Customers** (`/customers`).
- Can assign or unassign staff to branches.
- Can create new orders.
- Can view cross-branch Kanban and all orders across the system.
- Can perform all forward and reverse order state transitions.
- Can cancel orders at any allowed stage.
- Can use the `POST /orders/:id/unmark-paid` endpoint to revert a paid order to unpaid for editing.
- Can mark both Bank and Cash/Card orders as `PAID`.
- Can edit order items (add, update, delete) and details (like `endDate`) at any allowed stage.

**Restrictions:**
- None. Full access.

## 2. SALES_MANAGER
**Scope:** Multi-branch, multi-region
**Responsibility:** Taking orders from corporate clients, managing customers, and routing orders to the appropriate branches.

**Permissions:**
- Can create new orders and select the branch.
- Can edit order items and details before the order is paid.
- Can cancel orders that are in `DRAFT`, `CONFIRMED`, `IN_COLLECTION`, or `PARTIAL` states.
- Can perform reverse/recovery transitions from `READY` or `PARTIAL` back to `IN_COLLECTION` or `PARTIAL`.
- Can mark cash/card orders as `PAID` (only if the order is in `READY` status).
- Has cross-branch visibility for the orders they manage.

**Restrictions:**
- Cannot transition `DRAFT → CONFIRMED` (this is handled by SCM/ADMIN).
- Cannot transition `CONFIRMED → IN_COLLECTION` or `IN_COLLECTION → READY` (handled by STORE_MANAGER).
- Cannot transition `READY → COMPLETED`.
- Cannot unmark a paid order.
- Cannot manage Staff, Branches, or Products.

## 3. STORE_MANAGER
**Scope:** Single branch
**Responsibility:** Managing branch-level order fulfillment and driving the order state machine forward for their specific branch.

**Permissions:**
- Can assign a Picker to an order (`CONFIRMED → IN_COLLECTION`).
- Can drive forward order states: `IN_COLLECTION → READY`, `IN_COLLECTION → PARTIAL`, `PARTIAL → READY`, `READY → COMPLETED`.
- Can drive reverse/recovery order states: `PARTIAL → IN_COLLECTION`, `READY → IN_COLLECTION`, `READY → PARTIAL`.
- Can edit order items and details.
- Can view the list of Pickers available in their branch.
- Can mark cash/card orders as `PAID` (only if the order is in `READY` status).

**Restrictions:**
- Cannot create new orders or cancel existing orders.
- Cannot transition `DRAFT → CONFIRMED`.
- Cannot unmark paid orders.
- Cannot manage Staff (except viewing Pickers), Branches, Products, or Customers.

## 4. SCM (Supply Chain Manager)
**Scope:** Cross-branch
**Responsibility:** Managing backordered items, warehouse supply, and resolving stock availability.

**Permissions:**
- Can transition orders from `DRAFT → CONFIRMED`, officially confirming stock and declaring backorders.
- Can create new Products and perform bulk product imports via XLSX.
- Receives notifications on backorder item updates.

**Restrictions:**
- Cannot drive the order collection process (e.g., cannot transition to `IN_COLLECTION` or `READY`).
- Cannot mark orders as paid.
- Cannot manage Staff, Branches, or Customers.

## 5. ACCOUNTANT
**Scope:** Multi-branch, multi-region
**Responsibility:** Payment gating, invoicing, and reconciling bank transfers.

**Permissions:**
- Can mark Bank prepayment and post-payment orders as `PAID`.
- Receives notifications when an order payment recheck is required.

**Restrictions:**
- Cannot unmark paid orders.
- Cannot perform operational order transitions (`DRAFT → CONFIRMED → IN_COLLECTION → READY`).
- Cannot create, edit, or cancel orders.
- Cannot manage Staff, Products, Branches, or Customers.

## 6. PICKER
**Scope:** Single branch
**Responsibility:** Physically collecting items in a branch.

**Permissions:**
- Can be assigned to orders during the `CONFIRMED → IN_COLLECTION` transition.
- Can update item backorder statuses during collection (switching between `AVAILABLE` and `BACKORDERED`).

**Restrictions:**
- Cannot transition order states.
- Cannot create, cancel, or edit order details.
- Cannot mark orders as paid.
- Only views their own assigned workload and branch-specific orders.

## 7. BASIC
**Scope:** None
**Responsibility:** Default baseline role.

**Permissions:**
- Can authenticate and access basic endpoints available to any authenticated user.

**Restrictions:**
- Cannot create, edit, or transition orders.
- Cannot manage any system entities.
