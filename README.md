# BookVerse

BookVerse is a Flutter marketplace and reading tracker for manga, manhwa, manhua, comics, and light novels. Readers can discover books, manage a wishlist and cart, place orders, and track their reading. Sellers can manage listings and orders, while administrators oversee the marketplace.

## Features

- Browse, search, and explore books by category; view book details, ratings, and reviews.
- Save books to a wishlist and manage reading collections and progress.
- Add books to the cart, with quantities checked against live stock.
- Checkout with Cash on Delivery or Xendit's hosted online checkout. Available Xendit payment channels depend on the merchant account and mode.
- View order status, payment status, payment details, and order history.
- Apply vouchers and see shipping, tax, discounts, and totals at checkout.
- Apply to sell, manage a bookstore, maintain listings, and handle seller orders.
- Admin dashboard for orders, products, sellers, vouchers, customer messages, and listing review.
- In-app notifications and customer support messaging.

## Tech stack

| Area | Technology |
|---|---|
| App | Flutter and Dart |
| State management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase Auth, PostgreSQL, Storage, Realtime, and Edge Functions |
| Online payments | Xendit hosted invoices and authenticated payment verification |
| Images | Supabase Storage and `cached_network_image` |

## Project layout

```text
lib/
  core/                 Shared models, routing, theme, services, and widgets
  features/
    admin/              Marketplace administration
    auth/               Sign in and account registration
    book_details/       Book information and reviews
    cart/               Cart and stock-aware checkout selection
    catalog/            Book discovery and recommendations
    checkout/           Checkout, orders, payment, and receipts
    messages/            Customer and seller conversations
    notifications/      In-app notifications
    reviews/             Ratings and reviews
    seller/              Seller center and bookstore management
    wishlist/            Saved books
    ...                  Settings, vouchers, and reader features
supabase/
  functions/             Xendit invoice, status-check, and webhook functions
  migrations/            Ordered database updates
  tests/                 SQL payment and database checks
```

## Requirements

- Flutter SDK matching the Dart SDK constraint in `pubspec.yaml`.
- A Supabase project.
- For online payments, a Xendit account with the desired payment channels enabled.
- Supabase CLI for deploying Edge Functions (`npx supabase` works without a global install).

## Configure Supabase

The app reads its Supabase project URL and publishable key from `lib/core/config/supabase_config.dart`. You can override them at build time:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never put a Supabase `service_role` or secret key in the Flutter app. Keep server keys in Supabase Edge Function secrets.

### Database

Start with the base database setup in `supabase/schema.sql` for a new project. For an existing project, apply the SQL migrations from `supabase/migrations/` in filename order using the Supabase SQL Editor. In particular, the checkout/payment flow uses:

1. `20261026_checkout_payment_consistency.sql`
2. `20261027_verified_online_payments.sql`

The payment flow writes orders to `public.orders` and verified transaction records to `public.order_payments`. SQL statements that create or update schema objects may show no result rows; check the SQL Editor for errors and verify the tables under **Database → Tables**.

### Xendit Edge Functions

SQL does not deploy Edge Functions. Log in to the Supabase CLI, link your project, and deploy the payment functions:

```powershell
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase functions deploy create-invoice --project-ref YOUR_PROJECT_REF
npx supabase functions deploy sync-payment --project-ref YOUR_PROJECT_REF
npx supabase functions deploy xendit-webhook --project-ref YOUR_PROJECT_REF --no-verify-jwt
```

Set `XENDIT_SECRET_KEY` and `XENDIT_WEBHOOK_TOKEN` in the Supabase project's Edge Function secrets. Then configure the Xendit invoice callback URL:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook
```

Use a matching Xendit test or live key and callback configuration. Activate the channels you want in the Xendit Dashboard. See [supabase/PAYMENT_UPDATE.md](supabase/PAYMENT_UPDATE.md) for payment behavior and deployment checks.

## Run the app

```powershell
flutter pub get
flutter run
```

To build an Android release APK:

```powershell
flutter build apk --release
```

## Roles

- **Reader/customer:** browse books, manage a wishlist and cart, place orders, and track reading and purchases.
- **Seller:** apply for a bookstore and manage approved listings, orders, and customer conversations.
- **Administrator:** manage marketplace orders, products, sellers, vouchers, and listing reviews.

Role checks and database access are enforced by the app's Supabase policies and server-side functions; do not grant roles by editing this README or client settings.

## Verification

Run Flutter static analysis with:

```powershell
flutter analyze
```

Payment helper checks use Node.js 24 or newer:

```powershell
node --test supabase/functions/tests/xendit-payment.test.mjs
```

SQL tests in `supabase/tests/` should only be run against a disposable, schema-compatible database; they roll back their fixtures.
