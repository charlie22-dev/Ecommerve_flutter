import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// A user-curated grouping of saved books — main_basis.png's "Recently
/// Saved" collection cards (e.g. "Mindset & Money", "Design & Craft").
class BookCollection extends Equatable {
  const BookCollection({
    required this.id,
    required this.title,
    this.description = '',
    this.bookIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final List<String> bookIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Number of books currently saved in this collection.
  int get bookCount => bookIds.length;

  factory BookCollection.fromRow(Map<String, dynamic> row) {
    return BookCollection(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Untitled collection',
      description: row['description'] as String? ?? '',
      bookIds: stringList(row['book_ids']),
      createdAt: parseTimestamp(row['created_at']),
      updatedAt: parseTimestamp(row['updated_at']),
    );
  }

  @override
  List<Object?> get props => [id, title, bookIds];
}
