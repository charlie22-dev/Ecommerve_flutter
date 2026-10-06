// Adds 100 books spanning every BookType to the REAL Firebase project
// (myproject304-aaaae) — not the local emulator. Uses the downloaded service
// account key for Admin SDK auth (see .gitignore — that key must never be
// committed). Cover art comes from Open Library's public covers-by-ISBN
// API — a few titles (mostly manhua/newer manhwa print runs) may not have
// a cataloged cover and will just show the app's normal fallback icon;
// that's expected, not a bug.
//
// Run: node scripts/seed-100-prod.mjs   (from the scripts/ directory, after `npm install`)

import { readdirSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

import admin from 'firebase-admin';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'myproject304-aaaae';
// Picks up whichever key Firebase generated for this project (Project
// settings → Service accounts → Generate new private key), so the script
// doesn't hardcode a key id that changes every time one is rotated.
const keyFile = readdirSync(__dirname).find((f) => f.startsWith(`${PROJECT_ID}-firebase-adminsdk-`) && f.endsWith('.json'));
if (!keyFile) {
  console.error(`No service account key for ${PROJECT_ID} found in scripts/ — download one from the Firebase console first.`);
  process.exit(1);
}
const serviceAccount = JSON.parse(readFileSync(join(__dirname, keyFile), 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

function coverUrl(isbn) {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg`;
}

// [title, author, isbn, price, type, format, genres[], publisher, pages, year, rating, ratingCount, description, featuredSections[]]
const rows = [
  // ---- Manga (16) ----
  ['Naruto, Vol. 1', 'Masashi Kishimoto', '9781569319000', 320, 'manga', 'paperback', ['Action', 'Adventure'], 'VIZ Media', 192, 2003, 4.8, 5210, 'A young ninja outcast dreams of becoming leader of his village.', ['trending']],
  ['One Piece, Vol. 1', 'Eiichiro Oda', '9781569319017', 320, 'manga', 'paperback', ['Action', 'Adventure', 'Comedy'], 'VIZ Media', 216, 2003, 4.9, 6140, 'Monkey D. Luffy sets sail to find the legendary One Piece treasure.', ['trending', 'forYou']],
  ['Attack on Titan, Vol. 1', 'Hajime Isayama', '9781612620244', 350, 'manga', 'paperback', ['Action', 'Horror', 'Drama'], 'Kodansha', 192, 2012, 4.8, 4890, 'Humanity fights for survival against man-eating Titans.', ['newReleases']],
  ['Death Note, Vol. 1', 'Tsugumi Ohba', '9781421501680', 340, 'manga', 'paperback', ['Thriller', 'Mystery', 'Horror'], 'VIZ Media', 200, 2005, 4.9, 5320, 'A notebook that kills anyone whose name is written in it falls into the wrong hands.', ['forYou']],
  ['My Hero Academia, Vol. 1', 'Kohei Horikoshi', '9781421582696', 320, 'manga', 'paperback', ['Action', 'Adventure', 'Comedy'], 'VIZ Media', 216, 2015, 4.7, 4120, 'A quirkless boy dreams of becoming the greatest hero.', []],
  ['Demon Slayer: Kimetsu no Yaiba, Vol. 1', 'Koyoharu Gotouge', '9781974700523', 340, 'manga', 'paperback', ['Action', 'Fantasy', 'Drama'], 'VIZ Media', 192, 2018, 4.8, 4670, 'Tanjiro sets out to cure his demon sister and avenge his family.', ['newReleases', 'trending']],
  ['Fullmetal Alchemist, Vol. 1', 'Hiromu Arakawa', '9781591166996', 330, 'manga', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'VIZ Media', 192, 2005, 4.9, 3980, 'Two brothers use alchemy in search of the Philosopher\'s Stone.', []],
  ['Tokyo Ghoul, Vol. 1', 'Sui Ishida', '9781421580364', 340, 'manga', 'paperback', ['Horror', 'Action', 'Thriller'], 'VIZ Media', 224, 2015, 4.6, 3010, 'A college student survives a ghoul attack and is left half-ghoul himself.', []],
  ['Bleach, Vol. 1', 'Tite Kubo', '9781591164418', 320, 'manga', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'VIZ Media', 192, 2004, 4.7, 3760, 'A teenager gains soul reaper powers after saving his family from a Hollow.', []],
  ['Hunter x Hunter, Vol. 1', 'Yoshihiro Togashi', '9781591168363', 340, 'manga', 'paperback', ['Action', 'Adventure'], 'VIZ Media', 200, 2004, 4.8, 3340, 'A boy sets out to become a Hunter and find his estranged father.', []],
  ['Jujutsu Kaisen, Vol. 1', 'Gege Akutami', '9781974710002', 340, 'manga', 'paperback', ['Action', 'Horror', 'Fantasy'], 'VIZ Media', 192, 2020, 4.8, 3980, 'A boy swallows a cursed talisman and joins a school of sorcerers.', ['trending', 'newReleases']],
  ['Chainsaw Man, Vol. 1', 'Tatsuki Fujimoto', '9781974709939', 340, 'manga', 'paperback', ['Action', 'Horror', 'Comedy'], 'VIZ Media', 192, 2020, 4.7, 2980, 'A devil hunter merges with his chainsaw dog devil to survive.', ['newReleases']],
  ['Vinland Saga, Vol. 1', 'Makoto Yukimura', '9781612629204', 480, 'manga', 'hardcover', ['Action', 'Historical', 'Drama'], 'Kodansha', 448, 2013, 4.8, 1980, 'A young Viking seeks revenge across the brutal shores of medieval Europe.', []],
  ['Berserk, Vol. 1', 'Kentaro Miura', '9781593070205', 400, 'manga', 'paperback', ['Action', 'Fantasy', 'Horror'], 'Dark Horse', 224, 2003, 4.9, 2870, 'A lone mercenary swordsman is hunted by demons in a dark fantasy world.', []],
  ['Vagabond, Vol. 1', 'Takehiko Inoue', '9781421506092', 380, 'manga', 'paperback', ['Action', 'Historical', 'Drama'], 'VIZ Media', 224, 2008, 4.9, 1560, 'A fictionalized retelling of legendary swordsman Musashi Miyamoto\'s life.', []],
  ['Dragon Ball, Vol. 1', 'Akira Toriyama', '9781569319202', 320, 'manga', 'paperback', ['Action', 'Adventure', 'Comedy'], 'VIZ Media', 192, 2000, 4.8, 4020, 'A young monkey-tailed boy searches for seven magic Dragon Balls.', []],

  // ---- Manhwa (12) ----
  ['Solo Leveling, Vol. 1', 'Chugong', '9781975342510', 450, 'manhwa', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Yen Press', 320, 2021, 4.9, 3410, 'The weakest hunter gains the power to level up without limit.', ['trending', 'nowReading']],
  ['Tower of God, Vol. 1', 'SIU', '9798888770193', 420, 'manhwa', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Webtoon Unscrolled', 300, 2023, 4.6, 1290, 'A boy climbs a mysterious tower in search of his best friend.', []],
  ['Sweet Home, Vol. 1', 'Carnby Kim & Youngchan Hwang', '9781638581248', 430, 'manhwa', 'paperback', ['Horror', 'Thriller'], 'Webtoon Unscrolled', 340, 2021, 4.5, 980, 'A reclusive teen must survive as neighbors turn into monsters.', []],
  ['Noblesse, Vol. 1', 'Son Jeho', '9781975337516', 420, 'manhwa', 'paperback', ['Action', 'Fantasy'], 'Yen Press', 208, 2019, 4.4, 720, 'An 820-year-old noble wakes up in a modern-day high school.', []],
  ['The Remarried Empress, Vol. 1', 'Alphatart', '9781975363454', 440, 'manhwa', 'paperback', ['Romance', 'Fantasy', 'Drama'], 'Yen Press', 300, 2021, 4.7, 1560, 'An empress starts over after her husband replaces her with another woman.', ['forYou']],
  ['True Beauty, Vol. 1', 'Yaongyi', '9781975345177', 400, 'manhwa', 'paperback', ['Romance', 'Comedy', 'Slice of Life'], 'Yen Press', 216, 2020, 4.5, 1340, 'A girl who transforms with makeup navigates high school romance.', []],
  ['The Beginning After the End, Vol. 1', 'TurtleMe', '9781648273155', 440, 'manhwa', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Yen Press', 250, 2022, 4.7, 1120, 'A king is reborn into a magical world as a weak but gifted child.', ['newReleases']],
  ['Bastard, Vol. 1', 'Carnby Kim', '9781648271205', 420, 'manhwa', 'paperback', ['Thriller', 'Horror', 'Mystery'], 'Webtoon Unscrolled', 300, 2022, 4.5, 690, 'A teenager helps cover up his serial-killer father\'s murders.', []],
  ['God of High School, Vol. 1', 'Yongje Park', '9781648273476', 420, 'manhwa', 'paperback', ['Action', 'Fantasy', 'Comedy'], 'Webtoon Unscrolled', 280, 2022, 4.4, 610, 'A tournament of martial artists reveals a fight for godlike power.', []],
  ['Wind Breaker, Vol. 1', 'Jo Yong-suk', '9798888430026', 420, 'manhwa', 'paperback', ['Action', 'Slice of Life', 'Comedy'], 'Webtoon Unscrolled', 260, 2023, 4.5, 540, 'A introverted student finds belonging in a biking crew.', []],
  ['Omniscient Reader, Vol. 1', 'Sing Shong', '9781975363010', 440, 'manhwa', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Yen Press', 320, 2022, 4.8, 1340, 'The sole reader of a completed web novel finds himself living its apocalypse.', ['trending']],
  ['Eleceed, Vol. 1', 'Jeho Son & ZHENA', '9798888431566', 420, 'manhwa', 'paperback', ['Action', 'Comedy', 'Fantasy'], 'Webtoon Unscrolled', 260, 2023, 4.6, 780, 'A kind-hearted boy befriends a powerful cat who is secretly an esper.', []],

  // ---- Manhua (8) ----
  ['The King\'s Avatar, Vol. 1', 'Butterfly Blue', '9781646515335', 400, 'manhua', 'paperback', ['Action', 'Adventure'], 'Seven Seas', 200, 2021, 4.5, 640, 'A legendary pro gamer returns to competitive online gaming from scratch.', []],
  ['Battle Through the Heavens, Vol. 1', 'Tian Can Tu Dou', '9781638587523', 400, 'manhua', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Reikaverse', 220, 2022, 4.3, 410, 'A disgraced young genius fights to reclaim his lost talent.', []],
  ['Soul Land, Vol. 1', 'Tang Jia San Shao', '9781638587011', 400, 'manhua', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Reikaverse', 210, 2022, 4.2, 380, 'A martial artist is reborn into a world of spirits and soul power.', []],
  ['The Daily Life of the Immortal King, Vol. 1', 'Stay Gold', '9781638583327', 380, 'manhua', 'paperback', ['Comedy', 'Fantasy', 'Action'], 'Reikaverse', 200, 2021, 4.1, 290, 'A powerful cultivator tries to survive as an ordinary high schooler.', []],
  ['Martial Peak, Vol. 1', 'Momo', '9781648275111', 390, 'manhua', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Reikaverse', 220, 2022, 4.2, 320, 'An orphan\'s single spark of talent grows into unstoppable cultivation power.', []],
  ['Tales of Demons and Gods, Vol. 1', 'Mad Snail', '9781648273988', 390, 'manhua', 'paperback', ['Action', 'Fantasy'], 'Reikaverse', 210, 2022, 4.1, 260, 'A reincarnated cultivator gets a second chance to change his fate.', []],
  ['Apotheosis, Vol. 1', 'Wang Yu', '9781638586217', 380, 'manhua', 'paperback', ['Action', 'Fantasy', 'Adventure'], 'Reikaverse', 200, 2021, 4.0, 240, 'A young man is reborn into a clan of cultivators after being betrayed.', []],
  ['Renegade Immortal, Vol. 1', 'Er Gen', '9781638589008', 380, 'manhua', 'paperback', ['Fantasy', 'Action', 'Adventure'], 'Reikaverse', 210, 2022, 4.0, 210, 'A sickly village boy stumbles into the hidden world of immortal cultivators.', []],

  // ---- Comic (12) ----
  ['Watchmen', 'Alan Moore', '9780930289232', 550, 'comic', 'paperback', ['Drama', 'Thriller', 'Sci-Fi'], 'DC Comics', 416, 1987, 4.8, 2980, 'Retired vigilantes investigate a conspiracy in an alternate Cold War America.', []],
  ['Batman: Year One', 'Frank Miller', '9781401207526', 480, 'comic', 'paperback', ['Action', 'Drama', 'Mystery'], 'DC Comics', 144, 2005, 4.7, 1870, 'The definitive origin story of Bruce Wayne\'s first year as Batman.', []],
  ['The Sandman, Vol. 1', 'Neil Gaiman', '9781401225759', 520, 'comic', 'paperback', ['Fantasy', 'Horror', 'Drama'], 'Vertigo', 240, 2010, 4.8, 2340, 'Dream of the Endless is imprisoned and must reclaim his realm.', ['newReleases']],
  ['Saga, Vol. 1', 'Brian K. Vaughan', '9781607066019', 450, 'comic', 'paperback', ['Sci-Fi', 'Fantasy', 'Romance'], 'Image Comics', 160, 2012, 4.8, 2760, 'Star-crossed lovers from warring alien races flee with their newborn.', ['trending']],
  ['Spider-Man: Blue', 'Jeph Loeb', '9780785108561', 460, 'comic', 'paperback', ['Action', 'Romance', 'Drama'], 'Marvel', 200, 2003, 4.5, 640, 'Peter Parker reflects on his romance with Gwen Stacy.', []],
  ['V for Vendetta', 'Alan Moore', '9781401208417', 500, 'comic', 'paperback', ['Drama', 'Thriller', 'Sci-Fi'], 'DC Comics', 296, 2005, 4.7, 1980, 'A masked anarchist fights a totalitarian government in dystopian Britain.', []],
  ['Superman: Red Son', 'Mark Millar', '9781401229417', 480, 'comic', 'paperback', ['Sci-Fi', 'Drama', 'Action'], 'DC Comics', 176, 2004, 4.6, 1420, 'Superman\'s rocket lands in Soviet Ukraine instead of Kansas.', []],
  ['All-Star Superman, Vol. 1', 'Grant Morrison', '9781401223175', 460, 'comic', 'paperback', ['Sci-Fi', 'Action', 'Drama'], 'DC Comics', 160, 2007, 4.7, 1310, 'A dying Superman spends his final days completing twelve labors.', []],
  ['Invincible, Vol. 1', 'Robert Kirkman', '9781582405312', 400, 'comic', 'paperback', ['Action', 'Sci-Fi', 'Drama'], 'Image Comics', 128, 2003, 4.7, 1560, 'A teenager inherits his father\'s superpowers — and enemies.', []],
  ['The Walking Dead, Vol. 1', 'Robert Kirkman', '9781582406725', 420, 'comic', 'paperback', ['Horror', 'Drama', 'Thriller'], 'Image Comics', 144, 2004, 4.6, 2110, 'A sheriff\'s deputy wakes from a coma into a zombie apocalypse.', []],
  ['Y: The Last Man, Vol. 1', 'Brian K. Vaughan', '9781401201152', 440, 'comic', 'paperback', ['Sci-Fi', 'Drama', 'Adventure'], 'Vertigo', 128, 2002, 4.6, 1240, 'The last man on Earth searches for answers after a mysterious plague.', []],
  ['Hellboy, Vol. 1: Seed of Destruction', 'Mike Mignola', '9781593070944', 440, 'comic', 'paperback', ['Horror', 'Fantasy', 'Action'], 'Dark Horse', 144, 2004, 4.6, 980, 'A demon raised by the Bureau for Paranormal Research battles ancient evil.', []],
  ['Preacher, Vol. 1', 'Garth Ennis', '9781401252196', 460, 'comic', 'paperback', ['Action', 'Horror', 'Drama'], 'Vertigo', 192, 2013, 4.6, 1050, 'A preacher possessed by a rogue divine entity sets out to find God.', []],
  ['Daredevil: Born Again', 'Frank Miller', '9780785190205', 480, 'comic', 'paperback', ['Action', 'Drama', 'Thriller'], 'Marvel', 208, 2010, 4.7, 890, 'Matt Murdock\'s life is destroyed by the Kingpin, forcing him to rebuild from nothing.', []],

  // ---- Novel (16) ----
  ['1984', 'George Orwell', '9780451524935', 380, 'novel', 'paperback', ['Sci-Fi', 'Drama', 'Thriller'], 'Signet Classics', 328, 1949, 4.9, 6820, 'A dystopian vision of a society under total surveillance and control.', ['forYou']],
  ['The Great Gatsby', 'F. Scott Fitzgerald', '9780743273565', 350, 'novel', 'paperback', ['Drama', 'Romance'], 'Scribner', 180, 1925, 4.5, 4210, 'A mysterious millionaire\'s obsession with a lost love unravels in Jazz Age New York.', []],
  ['To Kill a Mockingbird', 'Harper Lee', '9780061120084', 380, 'novel', 'paperback', ['Drama', 'Historical'], 'Harper Perennial', 336, 1960, 4.8, 5340, 'A young girl witnesses her father defend a Black man falsely accused in the segregated South.', []],
  ['The Hobbit', 'J.R.R. Tolkien', '9780547928227', 420, 'novel', 'hardcover', ['Fantasy', 'Adventure'], 'Houghton Mifflin', 310, 1937, 4.8, 5980, 'A reluctant hobbit joins dwarves on a quest to reclaim their mountain home.', ['newReleases']],
  ['Dracula', 'Bram Stoker', '9780486411095', 300, 'novel', 'paperback', ['Horror', 'Thriller'], 'Dover Publications', 418, 1897, 4.6, 3120, 'A Transylvanian count\'s thirst for blood threatens Victorian England.', []],
  ['Crime and Punishment', 'Fyodor Dostoevsky', '9780486415871', 360, 'novel', 'paperback', ['Drama', 'Thriller'], 'Dover Publications', 545, 1866, 4.7, 2870, 'A poor ex-student in Saint Petersburg plots a murder that unravels his mind.', []],
  ['The Picture of Dorian Gray', 'Oscar Wilde', '9780486278070', 280, 'novel', 'paperback', ['Drama', 'Horror'], 'Dover Publications', 254, 1890, 4.6, 2460, 'A man\'s portrait ages in his place while he pursues endless vice.', []],
  ['Jane Eyre', 'Charlotte Brontë', '9780141441146', 380, 'novel', 'paperback', ['Romance', 'Drama'], 'Penguin Classics', 532, 1847, 4.7, 3560, 'An orphaned governess finds love and independence against Victorian constraints.', []],
  ['Brave New World', 'Aldous Huxley', '9780060850524', 380, 'novel', 'paperback', ['Sci-Fi', 'Drama'], 'Harper Perennial', 288, 1932, 4.7, 4560, 'A genetically engineered society trades freedom for stability and pleasure.', ['forYou']],
  ['Fahrenheit 451', 'Ray Bradbury', '9781451673319', 360, 'novel', 'paperback', ['Sci-Fi', 'Drama'], 'Simon & Schuster', 256, 1953, 4.7, 4120, 'A fireman whose job is burning books begins to question his world.', []],
  ['Pride and Prejudice', 'Jane Austen', '9780141439518', 360, 'novel', 'paperback', ['Romance', 'Drama', 'Comedy'], 'Penguin Classics', 480, 1813, 4.8, 5670, 'Sparks and misunderstandings fly between a spirited woman and a proud gentleman.', []],
  ['Wuthering Heights', 'Emily Brontë', '9780141439556', 360, 'novel', 'paperback', ['Romance', 'Drama'], 'Penguin Classics', 416, 1847, 4.4, 2980, 'A tale of obsessive love and revenge across the Yorkshire moors.', []],
  ['The Catcher in the Rye', 'J.D. Salinger', '9780316769488', 380, 'novel', 'paperback', ['Drama', 'Slice of Life'], 'Little, Brown', 234, 1951, 4.3, 3980, 'A disillusioned teenager wanders New York after leaving prep school.', []],
  ['Frankenstein', 'Mary Shelley', '9780486282114', 300, 'novel', 'paperback', ['Horror', 'Sci-Fi', 'Drama'], 'Dover Publications', 166, 1818, 4.6, 3210, 'A scientist\'s creation turns against him in this gothic tale of ambition.', []],
  ['Lord of the Flies', 'William Golding', '9780571056866', 340, 'novel', 'paperback', ['Drama', 'Thriller'], 'Penguin', 224, 1954, 4.5, 3670, 'Stranded boys descend into savagery on a deserted island.', []],
  ['Slaughterhouse-Five', 'Kurt Vonnegut', '9780385333849', 360, 'novel', 'paperback', ['Sci-Fi', 'Drama'], 'Dial Press', 275, 1969, 4.6, 3020, 'A soldier becomes unstuck in time after surviving the bombing of Dresden.', []],
  ['Moby-Dick', 'Herman Melville', '9781503280786', 400, 'novel', 'paperback', ['Drama', 'Adventure'], 'Penguin Classics', 720, 1851, 4.3, 2340, 'A captain\'s obsessive hunt for the white whale that took his leg.', []],
  ['The Count of Monte Cristo', 'Alexandre Dumas', '9780140449266', 420, 'novel', 'paperback', ['Drama', 'Adventure', 'Thriller'], 'Penguin Classics', 1276, 1844, 4.8, 3980, 'A wrongly imprisoned man escapes to exact an elaborate revenge.', []],

  // ---- Light Novel (12) ----
  ['Sword Art Online, Vol. 1: Aincrad', 'Reki Kawahara', '9780316371247', 420, 'lightNovel', 'paperback', ['Action', 'Sci-Fi', 'Adventure'], 'Yen Press', 264, 2014, 4.6, 2340, 'Players trapped in a deadly VRMMO must clear the game to survive.', ['nowReading']],
  ['Re:ZERO, Vol. 1', 'Tappei Nagatsuki', '9780316391161', 430, 'lightNovel', 'paperback', ['Fantasy', 'Action', 'Drama'], 'Yen Press', 296, 2016, 4.7, 2010, 'Subaru is transported to another world and gains the power to rewind death.', ['forYou']],
  ['Overlord, Vol. 1', 'Kugane Maruyama', '9780316272247', 420, 'lightNovel', 'paperback', ['Fantasy', 'Action'], 'Yen Press', 240, 2016, 4.6, 1780, 'A player becomes trapped as his own overpowered game character.', []],
  ['Konosuba, Vol. 1', 'Natsume Akatsuki', '9780316385352', 400, 'lightNovel', 'paperback', ['Comedy', 'Fantasy', 'Adventure'], 'Yen Press', 216, 2016, 4.7, 1650, 'A boy reincarnated in a fantasy world is stuck with a hopeless goddess.', []],
  ['That Time I Got Reincarnated as a Slime, Vol. 1', 'Fuse', '9781975329542', 430, 'lightNovel', 'paperback', ['Fantasy', 'Comedy', 'Adventure'], 'Yen Press', 348, 2017, 4.6, 1420, 'A salaryman is reincarnated as a slime with limitless growth potential.', []],
  ['The Rising of the Shield Hero, Vol. 1', 'Aneko Yusagi', '9781626926244', 400, 'lightNovel', 'paperback', ['Fantasy', 'Action', 'Drama'], 'One Peace Books', 244, 2017, 4.5, 1230, 'Betrayed and shunned, the Shield Hero must rebuild his reputation from nothing.', []],
  ['No Game No Life, Vol. 1', 'Yuu Kamiya', '9780316385772', 430, 'lightNovel', 'paperback', ['Comedy', 'Fantasy', 'Sci-Fi'], 'Yen Press', 280, 2015, 4.6, 1540, 'A shut-in sibling duo is summoned to a world where everything is decided by games.', []],
  ['Classroom of the Elite, Vol. 1', 'Syougo Kinugasa', '9781975307960', 420, 'lightNovel', 'paperback', ['Drama', 'Mystery', 'Slice of Life'], 'Yen Press', 256, 2017, 4.6, 1680, 'A seemingly average student hides sharp instincts at an elite, ruthless school.', []],
  ['The Devil Is a Part-Timer!, Vol. 1', 'Satoshi Wagahara', '9780316383778', 400, 'lightNovel', 'paperback', ['Comedy', 'Fantasy'], 'Yen Press', 232, 2015, 4.5, 1190, 'The Demon Lord flees to modern Tokyo and takes a fast-food job to get by.', []],
  ['Spice and Wolf, Vol. 1', 'Isuna Hasekura', '9780316079177', 410, 'lightNovel', 'paperback', ['Fantasy', 'Romance', 'Drama'], 'Yen Press', 248, 2009, 4.6, 1360, 'A traveling merchant partners with a centuries-old wolf goddess.', []],
  ['Goblin Slayer, Vol. 1', 'Kumo Kagyu', '9780316501943', 420, 'lightNovel', 'paperback', ['Fantasy', 'Action', 'Horror'], 'Yen Press', 224, 2016, 4.5, 1290, 'A grim adventurer devotes his life to exterminating goblins.', []],
  ['The Saga of Tanya the Evil, Vol. 1', 'Carlo Zen', '9781975325469', 420, 'lightNovel', 'paperback', ['Fantasy', 'Sci-Fi', 'Action'], 'Yen Press', 232, 2017, 4.5, 1050, 'A ruthless commanding officer wages war in a world eerily like WWI Europe.', []],

  // ---- Textbook (6) ----
  ['Introduction to Algorithms', 'Cormen, Leiserson, Rivest & Stein', '9780262046305', 1450, 'textbook', 'hardcover', ['Self-Help'], 'MIT Press', 1312, 2022, 4.7, 890, 'The standard reference on algorithm design and analysis.', []],
  ['Campbell Biology', 'Lisa Urry et al.', '9780134093413', 1600, 'textbook', 'hardcover', ['Self-Help'], 'Pearson', 1488, 2016, 4.5, 640, 'A comprehensive introduction to biological science.', []],
  ['Organic Chemistry', 'Paula Yurkanis Bruice', '9780134042282', 1350, 'textbook', 'hardcover', ['Self-Help'], 'Pearson', 1400, 2016, 4.3, 410, 'A rigorous introduction to organic chemistry principles and mechanisms.', []],
  ['Calculus: Early Transcendentals', 'James Stewart', '9781285741550', 1500, 'textbook', 'hardcover', ['Self-Help'], 'Cengage', 1368, 2015, 4.4, 720, 'A widely used calculus textbook covering limits through multivariable calculus.', []],
  ['Physics for Scientists and Engineers', 'Serway & Jewett', '9781337553278', 1550, 'textbook', 'hardcover', ['Self-Help'], 'Cengage', 1484, 2018, 4.4, 480, 'A calculus-based physics text covering mechanics through modern physics.', []],
  ['Fundamentals of Database Systems', 'Elmasri & Navathe', '9780133970777', 1400, 'textbook', 'hardcover', ['Self-Help'], 'Pearson', 1242, 2015, 4.3, 360, 'A comprehensive introduction to database design and systems.', []],

  // ---- Academic (6) ----
  ['A Brief History of Time', 'Stephen Hawking', '9780553380163', 420, 'academic', 'paperback', ['Self-Help'], 'Bantam', 256, 1998, 4.7, 4120, 'An accessible exploration of cosmology, black holes, and the origin of the universe.', []],
  ['Sapiens: A Brief History of Humankind', 'Yuval Noah Harari', '9780062316097', 480, 'academic', 'paperback', ['Historical', 'Self-Help'], 'Harper Perennial', 464, 2015, 4.8, 5230, 'A sweeping look at how Homo sapiens came to dominate the planet.', ['trending']],
  ['Thinking, Fast and Slow', 'Daniel Kahneman', '9780374533557', 460, 'academic', 'paperback', ['Self-Help'], 'Farrar, Straus and Giroux', 499, 2011, 4.6, 3980, 'A Nobel laureate explains the two systems that drive human thought.', []],
  ['The Selfish Gene', 'Richard Dawkins', '9780198788607', 440, 'academic', 'paperback', ['Self-Help', 'Historical'], 'Oxford University Press', 360, 2016, 4.5, 2140, 'A landmark exploration of evolution from the gene\'s point of view.', []],
  ['Guns, Germs, and Steel', 'Jared Diamond', '9780393317558', 460, 'academic', 'paperback', ['Historical', 'Self-Help'], 'W. W. Norton', 480, 1999, 4.6, 3410, 'Why history unfolded differently on different continents.', []],
  ['The Origin of Species', 'Charles Darwin', '9780451529060', 380, 'academic', 'paperback', ['Historical', 'Self-Help'], 'Signet Classics', 528, 1859, 4.5, 1980, 'The foundational text of evolutionary biology.', []],

  // ---- Book / other general (6) ----
  ['The Little Prince', 'Antoine de Saint-Exupéry', '9780156012195', 300, 'book', 'hardcover', ['Fantasy', 'Adventure', 'Slice of Life'], 'Mariner Books', 96, 1943, 4.8, 3980, 'A pilot stranded in the desert meets a young prince from a tiny asteroid.', ['newReleases']],
  ['Charlotte\'s Web', 'E.B. White', '9780064400558', 280, 'book', 'paperback', ['Drama', 'Slice of Life', 'Adventure'], 'HarperCollins', 192, 1952, 4.7, 2760, 'A pig named Wilbur is saved by a clever spider\'s web of words.', []],
  ['The Wonderful Wizard of Oz', 'L. Frank Baum', '9780486246913', 260, 'book', 'paperback', ['Fantasy', 'Adventure'], 'Dover Publications', 154, 1900, 4.6, 2340, 'Dorothy and her companions journey down the Yellow Brick Road to find the Wizard.', []],
  ['Alice\'s Adventures in Wonderland', 'Lewis Carroll', '9780486275437', 260, 'book', 'paperback', ['Fantasy', 'Adventure', 'Comedy'], 'Dover Publications', 100, 1865, 4.6, 3120, 'A girl tumbles down a rabbit hole into a nonsensical wonderland.', []],
  ['The Secret Garden', 'Frances Hodgson Burnett', '9780486419020', 280, 'book', 'paperback', ['Drama', 'Slice of Life'], 'Puffin Classics', 208, 1911, 4.7, 1980, 'An orphaned girl discovers a hidden garden that changes everything.', []],
  ['Peter Pan', 'J.M. Barrie', '9780486408367', 260, 'book', 'paperback', ['Fantasy', 'Adventure'], 'Dover Publications', 176, 1911, 4.6, 2210, 'A boy who never grows up whisks children away to Neverland.', []],

  // ---- Other (2) ----
  ['The Art of Computer Programming, Vol. 1', 'Donald E. Knuth', '9780201896831', 1800, 'other', 'hardcover', [], 'Addison-Wesley', 672, 1997, 4.6, 410, 'The definitive multi-volume analysis of algorithms and computer programming.', []],
  ['The Elements of Style', 'Strunk & White', '9780205309023', 320, 'other', 'paperback', ['Self-Help'], 'Longman', 105, 1999, 4.5, 1670, 'The classic, concise guide to clear and correct English writing.', []],
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
  console.log(`\nDone — added ${count} books to the REAL project (${PROJECT_ID}).`);
}

await main();
process.exit(0);
