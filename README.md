# BookVerse 📚

A full-featured **Flutter marketplace and reading tracker** for manga, manhwa, manhua, comics, and light novels. Buyers can browse, purchase, and track their reading; sellers can list and fulfil their own titles; admins oversee everything from a built-in panel.

Backend: **[Supabase](https://supabase.com)** (Auth, Postgres, Storage, Realtime).

---

## Table of Contents

1. [Features](#features)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Database Tables](#database-tables)
5. [User Roles](#user-roles)
6. [Getting Started](#getting-started)
7. [Running the App](#running-the-app)
8. [Testing](#testing)

---

## Features

### 🛍️ Marketplace
- Browse books by type (manga, manhwa, manhua, comic, novel, light novel, textbook, academic)
- Home feed with curated rails: **Now Reading**, **For You**, **Trending**, **New Releases**
- Full-text search and filter by genre, format (paperback / hardcover / digital), price
- Book detail page with description, reviews, and store info
- Wishlist — save titles to buy later

### 🛒 Cart & Checkout
- Multi-store cart (items from different sellers checked out together)
- Voucher/discount code support
- **Cash on Delivery** payment (GCash / Maya / card via PayMongo ready — needs Edge Functions)
- Order confirmation screen with per-shipment tracking numbers

### 📖 Reading Library
- Personal library of purchased/tracked titles
- Reading streaks, longest streak, and books-completed counter
- Collections for organising your shelf

### 👤 Profile & Settings
- Avatar upload (Supabase Storage)
- Display name, badges, reading stats
- Address book management
- Notification preferences

### 💬 Messaging
- Real-time buyer ↔ seller / buyer ↔ admin chat (Supabase Realtime)
- Admin conversation view for support

### 🔔 Notifications
- In-app notification feed (order updates, seller approvals, etc.)

### 🏪 Seller Center
- Apply to become a seller (admin approval required)
- List and edit products with cover image upload
- Order management: Confirm → Ship (add courier + tracking number) → Delivered
- Seller-scoped view: only sees their own orders and listings

### 🛠️ Admin Panel
| Section | What it does |
|---|---|
| Dashboard | Key stats at a glance |
| Products | Browse & add products (auto-published to BookVerse Official store) |
| Orders | View all platform orders |
| Vouchers | Create / edit discount codes (must be UPPERCASE) |
| Messages | Reply to any buyer conversation |
| Sellers | Approve or reject seller applications |
| Listing Review | Approve seller product listings before they go live |

### 🔐 Authentication
- Email / password sign-up & login
- Google and Facebook OAuth (optional, configured in Supabase dashboard)
- Email confirmation flow with in-app guidance
- Onboarding splash shown once on first launch

---

## Tech Stack

| Layer | Library / Service |
|---|---|
| Framework | Flutter 3 (Dart ^3.13) |
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) ^2.6 |
| Navigation | [go_router](https://pub.dev/packages/go_router) ^15.1 |
| Backend | [supabase_flutter](https://pub.dev/packages/supabase_flutter) ^2.10 |
| Fonts | [google_fonts](https://pub.dev/packages/google_fonts) (Anton display, Manrope body) |
| Images | [cached_network_image](https://pub.dev/packages/cached_network_image), [image_picker](https://pub.dev/packages/image_picker) |
| Checkout webview | [webview_flutter](https://pub.dev/packages/webview_flutter) |
| Utilities | `intl`, `equatable`, `uuid`, `shared_preferences`, `shimmer` |

---

## Project Structure

```
my_app/
├── lib/
│   ├── main.dart               # App entry point
│   ├── app.dart                # MaterialApp + theme setup
│   ├── core/
│   │   ├── auth/               # Auth state providers
│   │   ├── config/             # supabase_config.dart (URL + key)
│   │   ├── models/             # Shared data models (Book, Order, Profile…)
│   │   ├── router/             # go_router config + AppRoute constants
│   │   ├── services/           # db.dart — Supabase client, table names, live queries
│   │   ├── theme/              # Colors, typography (app_typography.dart)
│   │   └── widgets/            # Shared/reusable widgets
│   └── features/
│       ├── admin/              # Admin panel screens & providers
│       ├── auth/               # Login / sign-up screens
│       ├── book_details/       # Book detail page
│       ├── cart/               # Cart screen & logic
│       ├── catalog/            # Home feed, Explore, Store tabs
│       ├── checkout/           # Checkout flow, order confirmation
│       ├── library/            # Reading library & collections
│       ├── messages/           # Real-time chat
│       ├── notifications/      # Notification feed
│       ├── onboarding/         # Splash / onboarding screens
│       ├── profile/            # Profile & edit-profile screens
│       ├── reviews/            # Review submission & display
│       ├── seller/             # Seller Center screens & providers
│       ├── settings/           # Settings screen
│       ├── vouchers/           # Voucher listing screen
│       └── wishlist/           # Wishlist screen
├── supabase/
│   ├── schema.sql              # Tables, RLS policies, triggers, storage buckets
│   ├── seed.sql                # 100 sample books + 4 vouchers (optional)
│   ├── SETUP.md                # Step-by-step Supabase setup guide
│   └── tests/
│       └── marketplace_rls_test.sql  # RLS security tests
├── firebase-legacy/            # Retired Firebase config (reference only)
└── test/                       # Widget & model unit tests
```

Each `features/<name>/` folder follows a consistent layout:
```
features/<name>/
├── data/         # Repository — the only code that talks to Supabase
├── providers/    # Riverpod providers
└── screens/      # Flutter screens / widgets
```

---

## Database Tables

| Table | Description |
|---|---|
| `profiles` | One row per user; mirrors auth.users |
| `user_roles` | Extra roles: `seller`, `admin`, `super_admin` |
| `books` | Product catalogue |
| `orders` | Customer orders |
| `order_items` | Line items, seller id, commission snapshot |
| `cart_items` | Shopping cart |
| `wishlist_items` | Saved-for-later |
| `library_entries` | Purchased / tracked reading |
| `collections` | User-defined shelves |
| `addresses` | Delivery addresses |
| `reviews` | Star ratings + text reviews |
| `vouchers` | Discount codes |
| `notifications` | In-app notification feed |
| `messages` | Chat messages |
| `platform_settings` | Commission rate and other platform config |
| `stores` | Seller store info |

Storage buckets: `avatars`, `book-covers`, `review-photos`.

---

## User Roles

| Role | Access |
|---|---|
| Customer (default) | Browse, buy, review, chat, manage personal data |
| Seller | + Seller Center (list products, fulfil own orders). Requires admin approval. |
| Admin | + Admin Panel (approve sellers & listings, manage orders, vouchers, messages) |
| Super Admin | + Grant / revoke admin rights via `set_user_role()` |

Roles live in `user_roles`; the app reads them but **never writes** them directly — only trusted server-side functions and the SQL editor may do so.

---

## Getting Started

### 1. Supabase setup

Follow **[supabase/SETUP.md](supabase/SETUP.md)** for a full walkthrough. The short version:

1. Create a free project at <https://supabase.com/dashboard>.
2. In **SQL Editor → New query**, paste and run `supabase/schema.sql`.
3. Optionally run `supabase/seed.sql` to load 100 sample books and 4 vouchers.
4. Copy your **Project URL** and **publishable (anon) key** from **Project Settings → API Keys**.
5. Paste them into [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart).

> **Never** use the `service_role` / secret key inside the app — it bypasses all Row Level Security.

### 2. Authentication settings (Supabase dashboard)

- **Authentication → URL Configuration → Site URL**: `http://localhost:5000`
- **Redirect URLs** — add:
  - `com.bookverse.app://login-callback` (Android deep link)
  - `http://localhost:*/**` (local web dev)
  - Your production URL if deployed

### 3. Make yourself an admin

After signing up with your email, run in **SQL Editor**:

```sql
insert into public.user_roles (user_id, role)
select id, 'super_admin' from auth.users where email = 'you@example.com';
```

Restart the app — the **Admin Panel** entry appears in the Profile tab.

### 4. Install dependencies

```bash
flutter pub get
```

---

## Running the App

```bash
# Web (recommended for development)
flutter run -d chrome --web-port 5000

# Android device / emulator
flutter run -d <device-id>

# List available devices
flutter devices
```

> The app requires **Dart SDK ^3.13** / **Flutter 3**. Run `flutter doctor` to verify your environment.

---

## Testing

```bash
# All tests
flutter test

# Single file
flutter test test/models_test.dart
```

The `test/` directory contains:
- `models_test.dart` — Unit tests for core data models
- `admin_dashboard_test.dart` — Admin dashboard widget tests
- `chat_threads_test.dart` — Messaging widget tests
- `widget_test.dart` — General widget smoke tests

To run the **RLS security tests** against a live Supabase project, paste `supabase/tests/marketplace_rls_test.sql` into a new SQL Editor query and run it. A passing run prints `ALL MARKETPLACE TESTS PASSED`.
