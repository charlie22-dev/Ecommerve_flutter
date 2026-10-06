# Retired Firebase setup

BookVerse now runs on Supabase (see `../supabase/SETUP.md`). These files are
the old Firebase configuration and admin scripts, kept only for reference —
nothing in the app uses them any more. Safe to delete once you no longer need
them.

- `firestore.rules`, `storage.rules` → replaced by the RLS and storage
  policies in `../supabase/schema.sql`
- `scripts/seed-*.mjs` → replaced by `../supabase/seed.sql`
- `scripts/make-admin.mjs` → replaced by the one-line SQL in SETUP.md
- `scripts/*firebase-adminsdk*.json` is a live admin key for the old Firebase
  project — delete it (and revoke it in the Firebase console) when done.
