# BookVerse

Flutter marketplace and reading tracker for manga, manhwa, manhua, comics and
light novels. Backend: **Supabase** (Auth, Postgres, Storage, Realtime).

## Setup

1. Follow **[supabase/SETUP.md](supabase/SETUP.md)**: create the project, run
   `supabase/schema.sql` (and optionally `supabase/seed.sql`), and paste your
   project URL and publishable key into `lib/core/config/supabase_config.dart`.
2. `flutter pub get`
3. `flutter run -d chrome --web-port 5000` (or an Android device)

## Layout

- `lib/core/services/db.dart`: Supabase client, table names, live queries
- `lib/features/*/data/`: one repository per feature, the only code that talks to Supabase
- `supabase/schema.sql`: tables, Row Level Security, triggers, storage buckets
- `firebase-legacy/`: the retired Firebase setup, kept for reference only
