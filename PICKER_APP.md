# Picker App

## Purpose

This app is intended only for the `PICKER` role.

## Picker capabilities

- The picker only sees orders assigned to them.
- The picker can only change order statuses, not edit order details or items.
- The picker should not have access to staff, products, branches, or customers management.
- Status transitions allowed for a picker should be limited to the subset of order states relevant to pickup and collection.

## UX expectations

- Show a list of orders assigned to the picker.
- Provide only the actions needed to move the order through pickup-related states.
- Keep the interface simple: no catalog, no branch assignment UI, no customer edit actions.

## Notes

- Backend role checks currently restrict most transitions to `ADMIN`, `STORE_MANAGER`, and `SALES_MANAGER`.
- If a dedicated picker app is built, the API and permissions should be reviewed so pickers can only perform allowed status changes.
