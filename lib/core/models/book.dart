import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// Every readable/collectible type the catalog supports. New types can be
/// added here by also adding them to the `books.type` check constraint in
/// supabase/schema.sql — `Book` stores every field as optional so any
/// combination of type/format fits one row shape.
enum BookType {
  book,
  manga,
  manhwa,
  manhua,
  comic,
  novel,
  lightNovel,
  textbook,
  academic,
  other;

  static BookType fromKey(String? key) => BookType.values.firstWhere(
        (t) => t.name == key,
        orElse: () => BookType.other,
      );

  String get label => switch (this) {
        BookType.book => 'Book',
        BookType.manga => 'Manga',
        BookType.manhwa => 'Manhwa',
        BookType.manhua => 'Manhua',
        BookType.comic => 'Comic',
        BookType.novel => 'Novel',
        BookType.lightNovel => 'Light Novel',
        BookType.textbook => 'Textbook',
        BookType.academic => 'Academic',
        BookType.other => 'Other',
      };
}

enum BookFormat {
  paperback,
  hardcover,
  digital;

  static BookFormat fromKey(String? key) => BookFormat.values.firstWhere(
        (f) => f.name == key,
        orElse: () => BookFormat.paperback,
      );

  String get label => switch (this) {
        BookFormat.paperback => 'Paperback',
        BookFormat.hardcover => 'Hardcover',
        BookFormat.digital => 'Digital',
      };
}

/// Curated genre chip options for the admin product form — `Book.genres`
/// itself stays a free-form string list so nothing else has to change if
/// this list grows.
const kGenreOptions = <String>[
  'Romance',
  'Fantasy',
  'Horror',
  'Mystery',
  'Action',
  'Sci-Fi',
  'Slice of Life',
  'Thriller',
  'Comedy',
  'Drama',
  'Adventure',
  'Historical',
  'Self-Help',
  'Biography',
];

/// Named catalog sections the Home tab renders (Now Reading / For You /
/// Trending / New Releases). A book can belong to more than one.
enum FeaturedSection {
  nowReading,
  forYou,
  trending,
  newReleases;

  static FeaturedSection? fromKey(String key) =>
      FeaturedSection.values.where((s) => s.name == key).firstOrNull;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class Book extends Equatable {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl = '',
    this.price = 0,
    this.stock = 0,
    this.type = BookType.other,
    this.genres = const [],
    this.format = BookFormat.paperback,
    this.language = 'English',
    this.publisher = '',
    this.pages,
    this.isbn,
    this.rating = 0,
    this.ratingCount = 0,
    this.releaseDate,
    this.description = '',
    this.tags = const [],
    this.featuredSections = const [],
    this.totalChapters,
    this.listingStatus = 'published',
    this.moderationNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final double price;
  final int stock;
  final BookType type;
  final List<String> genres;
  final BookFormat format;
  final String language;
  final String publisher;
  final int? pages;
  final String? isbn;
  final double rating;
  final int ratingCount;
  final DateTime? releaseDate;
  final String description;
  final List<String> tags;
  final List<FeaturedSection> featuredSections;

  /// Used to compute reading progress percent alongside `currentChapter` on
  /// a library entry; null means progress is tracked as a raw page count
  /// instead of a chapter fraction.
  final int? totalChapters;

  /// draft · pending_review · published · rejected · suspended · archived.
  /// Only `published` listings appear in the store; sellers can't publish
  /// their own (the `guard_book_write` trigger in supabase/schema.sql).
  final String listingStatus;

  /// The admin's reason when a listing is rejected or suspended.
  final String? moderationNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get inStock => stock > 0;

  factory Book.fromRow(Map<String, dynamic> row) {
    return Book(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Untitled',
      author: row['author'] as String? ?? 'Unknown',
      coverUrl: row['cover_url'] as String? ?? '',
      price: toDouble(row['price']),
      stock: toInt(row['stock']),
      type: BookType.fromKey(row['type'] as String?),
      genres: stringList(row['genres']),
      format: BookFormat.fromKey(row['format'] as String?),
      language: row['language'] as String? ?? 'English',
      publisher: row['publisher'] as String? ?? '',
      pages: (row['pages'] as num?)?.toInt(),
      isbn: row['isbn'] as String?,
      rating: toDouble(row['rating']),
      ratingCount: toInt(row['rating_count']),
      releaseDate: parseTimestamp(row['release_date']),
      description: row['description'] as String? ?? '',
      tags: stringList(row['tags']),
      featuredSections:
          stringList(row['featured_sections']).map(FeaturedSection.fromKey).whereType<FeaturedSection>().toList(),
      totalChapters: (row['total_chapters'] as num?)?.toInt(),
      listingStatus: row['listing_status'] as String? ?? 'published',
      moderationNote: row['moderation_note'] as String?,
      createdAt: parseTimestamp(row['created_at']),
      updatedAt: parseTimestamp(row['updated_at']),
    );
  }

  /// Columns written on insert/update. `id`, `created_at` and `updated_at`
  /// are filled in by Postgres (defaults + trigger).
  Map<String, dynamic> toRow() => {
        'title': title,
        'author': author,
        'cover_url': coverUrl,
        'price': price,
        'stock': stock,
        'type': type.name,
        'genres': genres,
        'format': format.name,
        'language': language,
        'publisher': publisher,
        'pages': pages,
        'isbn': isbn,
        'rating': rating,
        'rating_count': ratingCount,
        'release_date': formatDate(releaseDate),
        'description': description,
        'tags': tags,
        'featured_sections': featuredSections.map((s) => s.name).toList(),
        'total_chapters': totalChapters,
        'listing_status': listingStatus,
      };

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? coverUrl,
    double? price,
    int? stock,
    BookType? type,
    List<String>? genres,
    BookFormat? format,
    String? language,
    String? publisher,
    int? pages,
    String? isbn,
    double? rating,
    int? ratingCount,
    DateTime? releaseDate,
    String? description,
    List<String>? tags,
    List<FeaturedSection>? featuredSections,
    int? totalChapters,
    String? listingStatus,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      type: type ?? this.type,
      genres: genres ?? this.genres,
      format: format ?? this.format,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      pages: pages ?? this.pages,
      isbn: isbn ?? this.isbn,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      releaseDate: releaseDate ?? this.releaseDate,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      featuredSections: featuredSections ?? this.featuredSections,
      totalChapters: totalChapters ?? this.totalChapters,
      listingStatus: listingStatus ?? this.listingStatus,
      moderationNote: moderationNote,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, author, coverUrl, price, stock, rating, listingStatus, moderationNote];
}
