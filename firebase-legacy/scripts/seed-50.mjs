// Adds 50 books spanning every BookType (manga, manhwa, manhua, comic,
// novel, light novel, textbook, academic, book) and a wide mix of genres,
// so Explore/Store/Home have real variety to browse and filter. Cover art
// comes from Open Library's public covers-by-ISBN API — a few titles
// (mostly manhua/newer manhwa print runs) may not have a cataloged cover
// and will just show the app's normal fallback icon; that's expected, not
// a bug.
//
// Run: node scripts/seed-50.mjs   (from the scripts/ directory, after `npm install`)

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

import admin from 'firebase-admin';

admin.initializeApp({ projectId: 'bookverse-placeholder' });
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

function coverUrl(isbn) {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg`;
}

// [title, author, isbn, price, type, format, genres[], publisher, pages, year, rating, ratingCount, description, featuredSections[]]
const rows = [
  // ---- Manga (8) ----
  ['Naruto, Vol. 1', 'Masashi Kishimoto', '9781569319000', 320, 'manga', 'paperback', ['Action', 'Adventure'], 'VIZ Media', 192, 2003, 4.8, 5210, 'A young ninja outcast dreams of becoming leader of his village.', ['trending']],
  ['One Piece, Vol. 1', 'Eiichiro Oda', '9781569319017', 320, 'manga', 'paperback', ['Action', 'Adventure', 'Comedy'], 'VIZ Media', 216, 2003, 4.9, 6140, 'Monkey D. Luffy sets sail to find the legendary One Piece treasure.', ['trending', 'forYou']],
  ['Attack on Titan, Vol. 1', 'Hajime Isayama', '9781612620244', 350, 'manga', 'paperback', ['Action', 'Horror', 'Drama'], 'Kodansha', 192, 2012, 4.8, 4890, 'Humanity fights for survival against man-eating Titans.', ['newReleases']],
  ['Death Note, Vol. 1', 'Tsugumi Ohba', '9781421501680', 340, 'manga', 'paperback', ['Thriller', 'Mystery', 'Horror'], 'VIZ Media', 200, 2005, 4.9, 5320, 'A notebook that kills anyone whose name is written in it falls into the wrong hands.', ['forYou']],
  ['My Hero Academia, Vol. 1', 'Kohei Horikoshi', '9781421582696', 320, 'manga', 'paperback', ['Action', 'Adventure', 'Comedy'], 'VIZ Media', 216, 2015, 4.7, 4120, 'A quirkless boy dreams of becoming the greatest hero.', []],
  ['Demon Slayer: Kimetsu no Yaiba, Vol. 1', 'Koyoharu Gotouge', '9781974700523', 340, 'manga', 'paperback', ['Action', 'Fantasy', 'Drama'], 'VIZ Media', 192, 2018, 4.8, 4670, 'Tanjiro sets out to cure his demon sister and avenge his family.', ['newReleases', 'trending']],
  ['Fullmetal Alchemist, Vol. 1', 'Hiromu Arakawa', '9781591166996', 330, 'manga', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'VIZ Media', 192, 2005, 4.9, 3980, 'Two brothers use alchemy in search of the Philosopher\'s Stone.', []],
  ['Tokyo Ghoul, Vol. 1', 'Sui Ishida', '9781421580364', 340, 'manga', 'paperback', ['Horror', 'Action', 'Thriller'], 'VIZ Media', 224, 2015, 4.6, 3010, 'A college student survives a ghoul attack and is left half-ghoul himself.', []],

  // ---- Manhwa (6) ----
  ['Solo Leveling, Vol. 1', 'Chugong', '9781975342510', 450, 'manhwa', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Yen Press', 320, 2021, 4.9, 3410, 'The weakest hunter gains the power to level up without limit.', ['trending', 'nowReading']],
  ['Tower of God, Vol. 1', 'SIU', '9798888770193', 420, 'manhwa', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Webtoon Unscrolled', 300, 2023, 4.6, 1290, 'A boy climbs a mysterious tower in search of his best friend.', []],
  ['Sweet Home, Vol. 1', 'Carnby Kim & Youngchan Hwang', '9781638581248', 430, 'manhwa', 'paperback', ['Horror', 'Thriller'], 'Webtoon Unscrolled', 340, 2021, 4.5, 980, 'A reclusive teen must survive as neighbors turn into monsters.', []],
  ['Noblesse, Vol. 1', 'Son Jeho', '9781975337516', 420, 'manhwa', 'paperback', ['Action', 'Fantasy'], 'Yen Press', 208, 2019, 4.4, 720, 'An 820-year-old noble wakes up in a modern-day high school.', []],
  ['The Remarried Empress, Vol. 1', 'Alphatart', '9781975363454', 440, 'manhwa', 'paperback', ['Romance', 'Fantasy', 'Drama'], 'Yen Press', 300, 2021, 4.7, 1560, 'An empress starts over after her husband replaces her with another woman.', ['forYou']],
  ['True Beauty, Vol. 1', 'Yaongyi', '9781975345177', 400, 'manhwa', 'paperback', ['Romance', 'Comedy', 'Slice of Life'], 'Yen Press', 216, 2020, 4.5, 1340, 'A girl who transforms with makeup navigates high school romance.', []],

  // ---- Manhua (4) ----
  ['The King\'s Avatar, Vol. 1', 'Butterfly Blue', '9781646515335', 400, 'manhua', 'paperback', ['Action', 'Adventure'], 'Seven Seas', 200, 2021, 4.5, 640, 'A legendary pro gamer returns to competitive online gaming from scratch.', []],
  ['Battle Through the Heavens, Vol. 1', 'Tian Can Tu Dou', '9781638587523', 400, 'manhua', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Reikaverse', 220, 2022, 4.3, 410, 'A disgraced young genius fights to reclaim his lost talent.', []],
  ['Soul Land, Vol. 1', 'Tang Jia San Shao', '9781638587011', 400, 'manhua', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Reikaverse', 210, 2022, 4.2, 380, 'A martial artist is reborn into a world of spirits and soul power.', []],
  ['The Daily Life of the Immortal King, Vol. 1', 'Stay Gold', '9781638583327', 380, 'manhua', 'paperback', ['Comedy', 'Fantasy', 'Action'], 'Reikaverse', 200, 2021, 4.1, 290, 'A powerful cultivator tries to survive as an ordinary high schooler.', []],

  // ---- Comic (6) ----
  ['Watchmen', 'Alan Moore', '9780930289232', 550, 'comic', 'paperback', ['Drama', 'Thriller', 'Sci-Fi'], 'DC Comics', 416, 1987, 4.8, 2980, 'Retired vigilantes investigate a conspiracy in an alternate Cold War America.', []],
  ['Batman: Year One', 'Frank Miller', '9781401207526', 480, 'comic', 'paperback', ['Action', 'Drama', 'Mystery'], 'DC Comics', 144, 2005, 4.7, 1870, 'The definitive origin story of Bruce Wayne\'s first year as Batman.', []],
  ['The Sandman, Vol. 1', 'Neil Gaiman', '9781401225759', 520, 'comic', 'paperback', ['Fantasy', 'Horror', 'Drama'], 'Vertigo', 240, 2010, 4.8, 2340, 'Dream of the Endless is imprisoned and must reclaim his realm.', ['newReleases']],
  ['Saga, Vol. 1', 'Brian K. Vaughan', '9781607066019', 450, 'comic', 'paperback', ['Sci-Fi', 'Fantasy', 'Romance'], 'Image Comics', 160, 2012, 4.8, 2760, 'Star-crossed lovers from warring alien races flee with their newborn.', ['trending']],
  ['Spider-Man: Blue', 'Jeph Loeb', '9780785108561', 460, 'comic', 'paperback', ['Action', 'Romance', 'Drama'], 'Marvel', 200, 2003, 4.5, 640, 'Peter Parker reflects on his romance with Gwen Stacy.', []],
  ['V for Vendetta', 'Alan Moore', '9781401208417', 500, 'comic', 'paperback', ['Drama', 'Thriller', 'Sci-Fi'], 'DC Comics', 296, 2005, 4.7, 1980, 'A masked anarchist fights a totalitarian government in dystopian Britain.', []],

  // ---- Novel (8) ----
  ['1984', 'George Orwell', '9780451524935', 380, 'novel', 'paperback', ['Sci-Fi', 'Drama', 'Thriller'], 'Signet Classics', 328, 1949, 4.9, 6820, 'A dystopian vision of a society under total surveillance and control.', ['forYou']],
  ['The Great Gatsby', 'F. Scott Fitzgerald', '9780743273565', 350, 'novel', 'paperback', ['Drama', 'Romance'], 'Scribner', 180, 1925, 4.5, 4210, 'A mysterious millionaire\'s obsession with a lost love unravels in Jazz Age New York.', []],
  ['To Kill a Mockingbird', 'Harper Lee', '9780061120084', 380, 'novel', 'paperback', ['Drama', 'Historical'], 'Harper Perennial', 336, 1960, 4.8, 5340, 'A young girl witnesses her father defend a Black man falsely accused in the segregated South.', []],
  ['The Hobbit', 'J.R.R. Tolkien', '9780547928227', 420, 'novel', 'hardcover', ['Fantasy', 'Adventure'], 'Houghton Mifflin', 310, 1937, 4.8, 5980, 'A reluctant hobbit joins dwarves on a quest to reclaim their mountain home.', ['newReleases']],
  ['Dracula', 'Bram Stoker', '9780486411095', 300, 'novel', 'paperback', ['Horror', 'Thriller'], 'Dover Publications', 418, 1897, 4.6, 3120, 'A Transylvanian count\'s thirst for blood threatens Victorian England.', []],
  ['Crime and Punishment', 'Fyodor Dostoevsky', '9780486415871', 360, 'novel', 'paperback', ['Drama', 'Thriller'], 'Dover Publications', 545, 1866, 4.7, 2870, 'A poor ex-student in Saint Petersburg plots a murder that unravels his mind.', []],
  ['The Picture of Dorian Gray', 'Oscar Wilde', '9780486278070', 280, 'novel', 'paperback', ['Drama', 'Horror'], 'Dover Publications', 254, 1890, 4.6, 2460, 'A man\'s portrait ages in his place while he pursues endless vice.', []],
  ['Jane Eyre', 'Charlotte Brontë', '9780141441146', 380, 'novel', 'paperback', ['Romance', 'Drama'], 'Penguin Classics', 532, 1847, 4.7, 3560, 'An orphaned governess finds love and independence against Victorian constraints.', []],

  // ---- Light Novel (6) ----
  ['Sword Art Online, Vol. 1: Aincrad', 'Reki Kawahara', '9780316371247', 420, 'lightNovel', 'paperback', ['Action', 'Sci-Fi', 'Adventure'], 'Yen Press', 264, 2014, 4.6, 2340, 'Players trapped in a deadly VRMMO must clear the game to survive.', ['nowReading']],
  ['Re:ZERO, Vol. 1', 'Tappei Nagatsuki', '9780316391161', 430, 'lightNovel', 'paperback', ['Fantasy', 'Action', 'Drama'], 'Yen Press', 296, 2016, 4.7, 2010, 'Subaru is transported to another world and gains the power to rewind death.', ['forYou']],
  ['Overlord, Vol. 1', 'Kugane Maruyama', '9780316272247', 420, 'lightNovel', 'paperback', ['Fantasy', 'Action'], 'Yen Press', 240, 2016, 4.6, 1780, 'A player becomes trapped as his own overpowered game character.', []],
  ['Konosuba, Vol. 1', 'Natsume Akatsuki', '9780316385352', 400, 'lightNovel', 'paperback', ['Comedy', 'Fantasy', 'Adventure'], 'Yen Press', 216, 2016, 4.7, 1650, 'A boy reincarnated in a fantasy world is stuck with a hopeless goddess.', []],
  ['That Time I Got Reincarnated as a Slime, Vol. 1', 'Fuse', '9781975329542', 430, 'lightNovel', 'paperback', ['Fantasy', 'Comedy', 'Adventure'], 'Yen Press', 348, 2017, 4.6, 1420, 'A salaryman is reincarnated as a slime with limitless growth potential.', []],
  ['The Rising of the Shield Hero, Vol. 1', 'Aneko Yusagi', '9781626926244', 400, 'lightNovel', 'paperback', ['Fantasy', 'Action', 'Drama'], 'One Peace Books', 244, 2017, 4.5, 1230, 'Betrayed and shunned, the Shield Hero must rebuild his reputation from nothing.', []],

  // ---- Textbook (4) ----
  ['Introduction to Algorithms', 'Cormen, Leiserson, Rivest & Stein', '9780262046305', 1450, 'textbook', 'hardcover', ['Self-Help'], 'MIT Press', 1312, 2022, 4.7, 890, 'The standard reference on algorithm design and analysis.', []],
  ['Campbell Biology', 'Lisa Urry et al.', '9780134093413', 1600, 'textbook', 'hardcover', ['Self-Help'], 'Pearson', 1488, 2016, 4.5, 640, 'A comprehensive introduction to biological science.', []],
  ['Organic Chemistry', 'Paula Yurkanis Bruice', '9780134042282', 1350, 'textbook', 'hardcover', ['Self-Help'], 'Pearson', 1400, 2016, 4.3, 410, 'A rigorous introduction to organic chemistry principles and mechanisms.', []],
  ['Calculus: Early Transcendentals', 'James Stewart', '9781285741550', 1500, 'textbook', 'hardcover', ['Self-Help'], 'Cengage', 1368, 2015, 4.4, 720, 'A widely used calculus textbook covering limits through multivariable calculus.', []],

  // ---- Academic (4) ----
  ['A Brief History of Time', 'Stephen Hawking', '9780553380163', 420, 'academic', 'paperback', ['Self-Help'], 'Bantam', 256, 1998, 4.7, 4120, 'An accessible exploration of cosmology, black holes, and the origin of the universe.', []],
  ['Sapiens: A Brief History of Humankind', 'Yuval Noah Harari', '9780062316097', 480, 'academic', 'paperback', ['Historical', 'Self-Help'], 'Harper Perennial', 464, 2015, 4.8, 5230, 'A sweeping look at how Homo sapiens came to dominate the planet.', ['trending']],
  ['Thinking, Fast and Slow', 'Daniel Kahneman', '9780374533557', 460, 'academic', 'paperback', ['Self-Help'], 'Farrar, Straus and Giroux', 499, 2011, 4.6, 3980, 'A Nobel laureate explains the two systems that drive human thought.', []],
  ['The Selfish Gene', 'Richard Dawkins', '9780198788607', 440, 'academic', 'paperback', ['Self-Help', 'Historical'], 'Oxford University Press', 360, 2016, 4.5, 2140, 'A landmark exploration of evolution from the gene\'s point of view.', []],

  // ---- Book / other general (3) ----
  ['The Little Prince', 'Antoine de Saint-Exupéry', '9780156012195', 300, 'book', 'hardcover', ['Fantasy', 'Adventure', 'Slice of Life'], 'Mariner Books', 96, 1943, 4.8, 3980, 'A pilot stranded in the desert meets a young prince from a tiny asteroid.', ['newReleases']],
  ['Charlotte\'s Web', 'E.B. White', '9780064400558', 280, 'book', 'paperback', ['Drama', 'Slice of Life', 'Adventure'], 'HarperCollins', 192, 1952, 4.7, 2760, 'A pig named Wilbur is saved by a clever spider\'s web of words.', []],
  ['The Wonderful Wizard of Oz', 'L. Frank Baum', '9780486246913', 260, 'book', 'paperback', ['Fantasy', 'Adventure'], 'Dover Publications', 154, 1900, 4.6, 2340, 'Dorothy and her companions journey down the Yellow Brick Road to find the Wizard.', []],

  // ---- Other (1) ----
  ['The Art of Computer Programming, Vol. 1', 'Donald E. Knuth', '9780201896831', 1800, 'other', 'hardcover', [], 'Addison-Wesley', 672, 1997, 4.6, 410, 'The definitive multi-volume analysis of algorithms and computer programming.', []],
];

async function main() {
  let count = 0;
  for (const row of rows) {
    const [title, author, isbn, price, type, format, genres, publisher, pages, year, rating, ratingCount, description, featuredSections] = row;

    const ref = db.collection('books').doc();
    await ref.set({
      title,
      author,
      coverUrl: coverUrl(isbn),
      price,
      stock: 5 + Math.floor(Math.random() * 36),
      type,
      genres,
      format,
      language: 'English',
      publisher,
      pages,
      isbn,
      rating,
      ratingCount,
      releaseDate: Timestamp.fromDate(new Date(`${year}-01-01`)),
      description,
      tags: [],
      featuredSections,
      totalChapters: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    count++;
    console.log(`[${count}/${rows.length}] Added "${title}" (${type})`);
  }
  console.log(`\nDone — added ${count} books.`);
}

await main();
process.exit(0);
