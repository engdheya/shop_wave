# Shop Wave

Shop Wave is a **multi-vendor e-commerce marketplace** connecting customers with independent sellers and stores through one digital platform. Customers can discover, compare, and purchase products across stores; sellers manage their own catalogs and orders; platform administrators oversee the marketplace centrally.

This Flutter prototype follows the supplied *Shop Wave SRS Draft v1.0* for the main marketplace flows: store ownership on listings, same-category comparison (up to four products), one multi-store cart, and a parent order split into one sub-order per store.

## Demo features

- Arabic-first, right-to-left interface with an English language toggle; responsive phone, tablet, and desktop layouts.
- Store directory and a sample catalog covering several independent sellers.
- Product search, category/store/price/availability filters, and sorting.
- Product details show the associated store, seller context, stock, and attributes.
- Comparison is limited to four products from the same category.
- A single cart groups items by store. Demo checkout rechecks stock, reduces inventory, and creates a parent order with a separate store order for every seller represented in the cart.
- Customer order tracking and cancellation of eligible store sub-orders.
- Seller workspace for the sample Nova Tech store: profile, catalog, price/stock/visibility, and order-status updates.
- Platform-admin preview for seller applications, store/listing moderation, parent/sub-order visibility, and an activity log.

## Run locally

```bash
flutter pub get
flutter run -d chrome
```

Run the business-logic tests with:

```bash
flutter test
```

Use the workspace menu in the top bar to switch between **Customer**, **Seller workspace**, and **Platform admin** previews. These are demonstration views, not authenticated accounts.

## Prototype boundary

The current screens use in-memory sample data so the marketplace flows work without a Firebase project. Restarting the app resets demo cart, orders, seller changes, and admin actions. Checkout is a sandbox simulation: it does not collect card details, contact a payment gateway, or charge money.

Before production, connect the flows to an authenticated backend and enforce role/store ownership in server-side security rules (not only in the UI/provider), persist orders and inventory transactionally, and integrate the approved payment, notification, and image-storage services. The SRS also calls for secure accounts, seller verification, audit retention, and measured non-functional requirements; those require backend and deployment work beyond this local prototype.
