# Connecting BookVerse to Supabase

Everything the app stores now lives in Supabase: accounts (Auth), products and
all user data (Postgres), images (Storage), and live updates (Realtime).

## 1. Create the project

1. Go to <https://supabase.com/dashboard> → **New project**.
2. Pick an organization, name it (e.g. `bookverse`), set a database password
   (save it somewhere), and pick the region closest to your users
   (e.g. **Southeast Asia (Singapore)**). The free plan is enough.
3. Wait about 2 minutes for it to finish provisioning.

## 2. Create the database (tables, security, storage)

1. Left sidebar → **SQL Editor** → **New query**.
2. Open `supabase/schema.sql` from this repo, copy **all** of it, paste, then **Run**.
   You should see "Success. No rows returned".
3. Optional, for 100 sample books and 4 vouchers: **New query** again, paste all of
   `supabase/seed.sql`, then **Run**.

Check: **Table Editor** should list `books`, `profiles`, `orders`, … and
**Storage** should show the `avatars`, `book-covers` and `review-photos` buckets.

**Updating an existing project:** whenever `schema.sql` changes, paste and run
the whole file again. It's written to be re-run safely and keeps your data.

**Security tests (optional):** paste all of `supabase/tests/marketplace_rls_test.sql`
into a new query and **Run**. It checks roles, seller approval, checkout pricing,
stock and privacy as real customer/seller/admin sessions, then rolls everything
back. You should see `ALL MARKETPLACE TESTS PASSED`.

## 3. Put your keys in the app

1. Left sidebar → **Project Settings** → **API Keys** (or click **Connect** at the top).
2. Copy the **Project URL** (`https://xxxx.supabase.co`) and the **publishable key**
   (`sb_publishable_…`; older projects call it the **anon / public** key, and either works).
3. Paste both into `lib/core/config/supabase_config.dart`.

> **Never** put the `service_role` / secret key in the app. It bypasses all
> security rules.

## 4. Authentication settings

**Authentication → Sign In / Providers**
- **Email** is on by default.
- **Confirm email**: if this is **on** (the default), new users must click the link
  in their inbox before they can log in, and the app tells them so after signup.
  Turn it **off** during development to log in straight after signing up.
  On the free plan, Supabase only sends a few emails per hour.

**Authentication → URL Configuration**
- **Site URL**: where the web app runs. For local testing use
  `http://localhost:5000` and run the app with
  `flutter run -d chrome --web-port 5000`.
- **Redirect URLs** → **Add URL**: `com.bookverse.app://login-callback`
  (the Android app's deep link for email confirmation, password reset, and
  Google/Facebook sign-in).

**Google / Facebook sign-in (optional)**: **Authentication → Sign In / Providers →
Google** (or Facebook) → enable, then paste the Client ID and secret from Google
Cloud Console / Meta for Developers. On their side, set the authorized redirect URI to
`https://<your-project-ref>.supabase.co/auth/v1/callback`.

## 5. Make yourself an admin

1. Run the app and sign up with your own email.
2. **SQL Editor** → run:
   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'super_admin' from auth.users where email = 'you@example.com';
   ```
3. Restart the app. You now get the Admin Panel (Profile tab), can approve
   sellers, and can advance orders.

Roles live in `user_roles` (`seller`, `admin`, `super_admin`); the app can read
them but never write them.

**Seller flow:** a user taps **Profile → Become a Seller** and applies. An admin
approves or rejects it in **Admin Panel → Sellers**, which opens their store.
The seller adds listings in **Profile → Seller Center**. An admin approves those
in **Admin Panel → Listing review**, and only then do they appear in the store.
When someone buys, each store ships its own items from **Seller Center → Orders**
(Confirm → Ship with courier + tracking → Delivered). The buyer sees each
shipment's tracking under **Order Details**. A super admin can grant or
revoke admin rights with `select set_user_role('<user id>', 'admin', true);`.

Products created by admins go to the **BookVerse Official** store, already
published. Sellers' products start as `pending_review` and only appear in the
store after an admin sets `listing_status` to `published`.

The platform commission rate is in **Table Editor → platform_settings** (0.10 =
10%). Each order item keeps the rate it was sold at.

## 6. Adding products

You can add products either way:

- **In the app** (as an admin): the admin product form, which includes cover upload.
- **In Supabase**: **Table Editor → books → Insert → Insert row**. Only `title` is
  required; everything else has a default. Valid values:

  | Column | Values |
  |---|---|
  | `type` | `book`, `manga`, `manhwa`, `manhua`, `comic`, `novel`, `lightNovel`, `textbook`, `academic`, `other` |
  | `format` | `paperback`, `hardcover`, `digital` |
  | `featured_sections` | any of `nowReading`, `forYou`, `trending`, `newReleases`, which put the book on the Home tab rails |
  | `genres`, `tags` | lists, written as `{Action,Fantasy}` in the editor |
  | `cover_url` | any image URL. To host one yourself: **Storage → book-covers → Upload**, then copy its public URL |
  | `price` | pesos, e.g. `320` |

  To import many products at once: **Table Editor → books → Insert → Import data from CSV**.

New and edited products show up in the running app within a second; no restart needed.

Vouchers work the same way in **Table Editor → vouchers**. Codes must be UPPERCASE.

## 7. Online payments (GCash / Maya / card)

These need two Supabase Edge Functions, `createEwalletSource` and
`createCardPayment`, that hold the PayMongo **secret** key server-side. They
don't exist yet (they weren't in the old Firebase project either). Cash on
Delivery works without them.

## What changed from Firebase

| Firebase | Supabase |
|---|---|
| Firestore `users/{uid}` | `profiles` table, created automatically by a trigger at signup (fixes the old "signup failed but I can log in" bug) |
| `users/{uid}/cart`, `/wishlist`, `/library`, `/collections`, `/addresses` | `cart_items`, `wishlist_items`, `library_entries`, `collections`, `addresses` |
| `books`, `orders`, `vouchers`, `reviews`, `notifications`, `messages` | same names |
| `firestore.rules` / `storage.rules` | Row Level Security policies + storage policies in `schema.sql` |
| Firebase Storage (needed the paid Blaze plan) | Supabase Storage (included in the free plan) |

The old Firebase files are in `firebase-legacy/`, for reference only.
