// Grants admin (isAdmin: true) to every account currently in the local
// Auth emulator. Dev-only — see seed.mjs for why this can't be a
// self-service button in the app (Firestore rules block a user from
// setting their own isAdmin; only the Admin SDK, used here, bypasses that).
//
// Run: node scripts/make-admin.mjs   (from the scripts/ directory, after `npm install`)

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

import admin from 'firebase-admin';

admin.initializeApp({ projectId: 'bookverse-placeholder' });
const auth = admin.auth();
const db = admin.firestore();

const { users } = await auth.listUsers();
if (users.length === 0) {
  console.log('No emulator Auth users found — sign up in the app first, then re-run this script.');
} else {
  for (const user of users) {
    await db.collection('users').doc(user.uid).set({ isAdmin: true }, { merge: true });
    console.log(`Granted admin to ${user.email} (${user.uid})`);
  }
}
process.exit(0);
