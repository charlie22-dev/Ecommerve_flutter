// Bulk-adds books from local cover images. Drop image files into
// scripts/book-covers-inbox/, optionally add a manifest.json there (see
// manifest.example.json for the shape) to give each file real metadata —
// any file not listed in the manifest still gets added, with a title
// guessed from its filename and everything else defaulted.
//
// Run: node scripts/add-books.mjs   (from the scripts/ directory, after `npm install`)
//
// Dev-only against the local emulator suite by default (see the env vars
// below). To use this against a REAL Firebase project instead, delete
// those three env var lines and run `gcloud auth application-default
// login` (or set GOOGLE_APPLICATION_CREDENTIALS to a service account key)
// first — same script, real backend.

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';

import { randomUUID } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import admin from 'firebase-admin';

const PROJECT_ID = 'bookverse-placeholder';
const BUCKET = `${PROJECT_ID}.appspot.com`;
const INBOX_DIR = join(fileURLToPath(import.meta.url), '..', 'book-covers-inbox');
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp']);

admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const { Timestamp, FieldValue } = admin.firestore;

function loadManifest() {
  try {
    return JSON.parse(readFileSync(join(INBOX_DIR, 'manifest.json'), 'utf8'));
  } catch {
    return {};
  }
}

function titleFromFilename(filename) {
  const base = filename.replace(extname(filename), '');
  return base
    .replace(/[-_]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

async function uploadCover(filename, bytes) {
  const ext = extname(filename).slice(1).toLowerCase();
  const contentType = `image/${ext === 'jpg' ? 'jpeg' : ext}`;
  const token = randomUUID();
  const path = `book-covers/${randomUUID()}.${ext}`;

  const file = bucket.file(path);
  await file.save(bytes, {
    metadata: { contentType, metadata: { firebaseStorageDownloadTokens: token } },
  });

  return `http://127.0.0.1:9199/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function main() {
  const manifest = loadManifest();
  const files = readdirSync(INBOX_DIR).filter((f) => IMAGE_EXTENSIONS.has(extname(f).toLowerCase()));

  if (files.length === 0) {
    console.log(`No images found in ${INBOX_DIR}.`);
    console.log('Drop .jpg/.png/.webp cover images there (and optionally a manifest.json — see manifest.example.json), then re-run this script.');
    return;
  }

  for (const filename of files) {
    const meta = manifest[filename] ?? {};
    const bytes = readFileSync(join(INBOX_DIR, filename));
    const coverUrl = await uploadCover(filename, bytes);

    const ref = db.collection('books').doc();
    await ref.set({
      title: meta.title ?? titleFromFilename(filename),
      author: meta.author ?? 'Unknown',
      coverUrl,
      price: meta.price ?? 0,
      stock: meta.stock ?? 10,
      type: meta.type ?? 'book',
      genres: meta.genres ?? [],
      format: meta.format ?? 'paperback',
      language: meta.language ?? 'English',
      publisher: meta.publisher ?? '',
      pages: meta.pages ?? null,
      isbn: meta.isbn ?? null,
      rating: 0,
      ratingCount: 0,
      releaseDate: meta.releaseDate ? Timestamp.fromDate(new Date(meta.releaseDate)) : null,
      description: meta.description ?? '',
      tags: [],
      featuredSections: meta.featuredSections ?? [],
      totalChapters: meta.totalChapters ?? null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    console.log(`Added "${meta.title ?? titleFromFilename(filename)}" from ${filename} (${ref.id})`);
  }

  console.log(`\nDone — added ${files.length} book(s). Move/delete the images from book-covers-inbox/ once you're happy with the result (they've already been uploaded to Storage).`);
}

await main();
process.exit(0);
