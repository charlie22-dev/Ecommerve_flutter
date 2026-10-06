import 'package:equatable/equatable.dart';

import '../services/db.dart';

enum ReadingShelf {
  currentlyReading,
  completed,
  wantToRead,
  favorites;

  static ReadingShelf fromKey(String? key) => ReadingShelf.values.firstWhere(
        (s) => s.name == key,
        orElse: () => ReadingShelf.wantToRead,
      );

  String get label => switch (this) {
        ReadingShelf.currentlyReading => 'Currently Reading',
        ReadingShelf.completed => 'Completed',
        ReadingShelf.wantToRead => 'Want to Read',
        ReadingShelf.favorites => 'Favorites',
      };
}

/// A user's progress on one book. `favorites` is tracked as a boolean flag
/// rather than a shelf so a book can be a favorite while also currently
/// being read.
class LibraryEntry extends Equatable {
  const LibraryEntry({
    required this.bookId,
    required this.shelf,
    this.progressPercent = 0,
    this.currentChapter = 0,
    this.isFavorite = false,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
  });

  final String bookId;
  final ReadingShelf shelf;
  final double progressPercent;
  final int currentChapter;
  final bool isFavorite;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  factory LibraryEntry.fromRow(Map<String, dynamic> row) {
    return LibraryEntry(
      bookId: row['book_id'] as String,
      shelf: ReadingShelf.fromKey(row['shelf'] as String?),
      progressPercent: toDouble(row['progress_percent']),
      currentChapter: toInt(row['current_chapter']),
      isFavorite: row['is_favorite'] as bool? ?? false,
      startedAt: parseTimestamp(row['started_at']),
      completedAt: parseTimestamp(row['completed_at']),
      updatedAt: parseTimestamp(row['updated_at']),
    );
  }

  /// `updated_at` is maintained by a trigger.
  Map<String, dynamic> toRow(String uid) => {
        'user_id': uid,
        'book_id': bookId,
        'shelf': shelf.name,
        'progress_percent': progressPercent,
        'current_chapter': currentChapter,
        'is_favorite': isFavorite,
        'started_at': startedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };

  LibraryEntry copyWith({
    ReadingShelf? shelf,
    double? progressPercent,
    int? currentChapter,
    bool? isFavorite,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return LibraryEntry(
      bookId: bookId,
      shelf: shelf ?? this.shelf,
      progressPercent: progressPercent ?? this.progressPercent,
      currentChapter: currentChapter ?? this.currentChapter,
      isFavorite: isFavorite ?? this.isFavorite,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [bookId, shelf, progressPercent, isFavorite];
}
