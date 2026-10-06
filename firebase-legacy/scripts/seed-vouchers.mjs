// Adds a handful of sample vouchers so the Vouchers tab and checkout's
// voucher picker have real data to show. See core/models/voucher.dart for
// the schema this mirrors.
//
// Run: node scripts/seed-vouchers.mjs   (from the scripts/ directory, after `npm install`)

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

import admin from 'firebase-admin';

admin.initializeApp({ projectId: 'bookverse-placeholder' });
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

function daysFromNow(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

const vouchers = [
  {
    code: 'WELCOME20',
    title: 'Welcome Voucher',
    description: 'New to BookVerse? Take 20% off your first order, up to ₱300 off.',
    discountType: 'percent',
    discountValue: 20,
    minPurchase: 500,
    maxDiscount: 300,
    expiresAt: daysFromNow(60),
    isActive: true,
  },
  {
    code: 'FREESHIP',
    title: 'Free Shipping Voucher',
    description: 'Flat ₱60 off shipping on any order over ₱800.',
    discountType: 'fixed',
    discountValue: 60,
    minPurchase: 800,
    maxDiscount: null,
    expiresAt: daysFromNow(30),
    isActive: true,
  },
  {
    code: 'MANGA100',
    title: '₱100 Off Manga & Manhwa',
    description: 'Get ₱100 off when you spend ₱1,000 or more storewide.',
    discountType: 'fixed',
    discountValue: 100,
    minPurchase: 1000,
    maxDiscount: null,
    expiresAt: daysFromNow(45),
    isActive: true,
  },
  {
    code: 'BOOKWORM10',
    title: 'Bookworm 10% Off',
    description: '10% off your entire order, no minimum spend.',
    discountType: 'percent',
    discountValue: 10,
    minPurchase: 0,
    maxDiscount: 200,
    expiresAt: daysFromNow(90),
    isActive: true,
  },
];

async function main() {
  let count = 0;
  for (const v of vouchers) {
    const ref = db.collection('vouchers').doc();
    await ref.set({
      ...v,
      expiresAt: v.expiresAt ? Timestamp.fromDate(v.expiresAt) : null,
      createdAt: FieldValue.serverTimestamp(),
    });
    count++;
    console.log(`[${count}/${vouchers.length}] Added voucher "${v.code}"`);
  }
  console.log(`\nDone — added ${count} vouchers.`);
}

await main();
process.exit(0);
