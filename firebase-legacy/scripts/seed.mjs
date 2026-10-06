// Dev-only: grants admin to every account in the local Auth emulator and
// seeds a handful of sample books into the local Firestore emulator, so
// Home/Explore/Store aren't empty and the admin product form has data to
// edit. Never touches a real Firebase project — see the emulator host env
// vars below, which only work against `firebase emulators:start`.
//
// Run: node scripts/seed.mjs   (from the scripts/ directory, after `npm install`)

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';

import admin from 'firebase-admin';

admin.initializeApp({ projectId: 'bookverse-placeholder' });
const auth = admin.auth();
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

async function grantAdminToAllUsers() {
  const { users } = await auth.listUsers();
  if (users.length === 0) {
    console.log('No emulator Auth users found yet — sign up in the app first, then re-run this script.');
    return;
  }
  for (const user of users) {
    await db.collection('users').doc(user.uid).set({ isAdmin: true }, { merge: true });
    console.log(`Granted admin to ${user.email} (${user.uid})`);
  }
}

function coverUrl(isbn) {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg`;
}

const sampleBooks = [
  {
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    isbn: '9780141439518',
    price: 349,
    stock: 24,
    type: 'novel',
    genres: ['Romance', 'Drama', 'Comedy'],
    format: 'paperback',
    language: 'English',
    publisher: 'Penguin Classics',
    pages: 432,
    rating: 4.8,
    ratingCount: 1423,
    releaseDate: new Date('1813-01-28'),
    description:
      "Elizabeth Bennet navigates manners, marriage, and misunderstanding in Regency England, sparring with the proud Mr. Darcy along the way.",
    featuredSections: ['forYou', 'trending'],
  },
  {
    title: 'Frankenstein',
    author: 'Mary Shelley',
    isbn: '9780141439471',
    price: 299,
    stock: 18,
    type: 'novel',
    genres: ['Horror', 'Sci-Fi', 'Thriller'],
    format: 'paperback',
    language: 'English',
    publisher: 'Penguin Classics',
    pages: 280,
    rating: 4.5,
    ratingCount: 981,
    releaseDate: new Date('1818-01-01'),
    description:
      "Victor Frankenstein's obsession with conquering death gives rise to a creature whose torment reshapes both their fates.",
    featuredSections: ['trending', 'newReleases'],
  },
  {
    title: 'The Art of War',
    author: 'Sun Tzu',
    isbn: '9781599869773',
    price: 249,
    stock: 40,
    type: 'academic',
    genres: ['Historical', 'Self-Help'],
    format: 'hardcover',
    language: 'English',
    publisher: 'Filiquarian',
    pages: 96,
    rating: 4.6,
    ratingCount: 2210,
    releaseDate: new Date('1772-01-01'),
    description:
      'A treatise on strategy, discipline, and leadership that has shaped military and business thinking for over two thousand years.',
    featuredSections: ['forYou'],
  },
  {
    title: 'A Study in Scarlet',
    author: 'Arthur Conan Doyle',
    isbn: '9781503288946',
    price: 279,
    stock: 15,
    type: 'novel',
    genres: ['Mystery', 'Thriller', 'Action'],
    format: 'paperback',
    language: 'English',
    publisher: 'CreateSpace',
    pages: 154,
    rating: 4.9,
    ratingCount: 3054,
    releaseDate: new Date('1887-01-01'),
    description:
      "Sherlock Holmes meets Dr. Watson for the first time and unravels a murder that leads to a trail of revenge stretching back to America.",
    featuredSections: ['nowReading', 'trending'],
  },
  {
    title: "Alice's Adventures in Wonderland",
    author: 'Lewis Carroll',
    isbn: '9780486275437',
    price: 199,
    stock: 30,
    type: 'book',
    genres: ['Fantasy', 'Adventure', 'Comedy', 'Slice of Life'],
    format: 'paperback',
    language: 'English',
    publisher: 'Dover Publications',
    pages: 100,
    rating: 4.7,
    ratingCount: 1670,
    releaseDate: new Date('1865-11-26'),
    description:
      'Alice tumbles down a rabbit hole into a world of riddles, talking creatures, and a rather short-tempered Queen of Hearts.',
    featuredSections: ['newReleases', 'forYou'],
  },
];

async function seedBooks() {
  for (const book of sampleBooks) {
    const ref = db.collection('books').doc();
    await ref.set({
      title: book.title,
      author: book.author,
      coverUrl: coverUrl(book.isbn),
      price: book.price,
      stock: book.stock,
      type: book.type,
      genres: book.genres,
      format: book.format,
      language: book.language,
      publisher: book.publisher,
      pages: book.pages,
      isbn: book.isbn,
      rating: book.rating,
      ratingCount: book.ratingCount,
      releaseDate: Timestamp.fromDate(book.releaseDate),
      description: book.description,
      tags: [],
      featuredSections: book.featuredSections,
      totalChapters: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`Seeded "${book.title}" (${ref.id})`);
  }
}

await grantAdminToAllUsers();
await seedBooks();
console.log('Done.');
process.exit(0);
