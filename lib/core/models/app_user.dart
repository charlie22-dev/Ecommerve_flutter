import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// The full user profile, read from the `profiles` table.
/// Created automatically on signup via a Postgres trigger — see
/// `on_auth_user_created` in supabase/schema.sql.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl,
    this.badgeIds = const [],
    this.streakCount = 0,
    this.longestStreak = 0,
    this.lastReadAt,
    this.booksCompletedCount = 0,
    this.createdAt,
    this.isAdmin = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> badgeIds;
  final int streakCount;
  final int longestStreak;
  final DateTime? lastReadAt;
  final int booksCompletedCount;
  final DateTime? createdAt;

  /// Shows the Admin Panel. A read-only mirror of the user's admin /
  /// super_admin role in `user_roles` (supabase/schema.sql); the database
  /// enforces admin rights itself, this only drives the UI.
  final bool isAdmin;

  /// Profiles rows are created server-side by the `on_auth_user_created`
  /// trigger (supabase/schema.sql), so there's no client-side `toRow`.
  factory AppUser.fromRow(Map<String, dynamic> row) {
    return AppUser(
      uid: row['id'] as String,
      email: row['email'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      photoUrl: row['photo_url'] as String?,
      badgeIds: stringList(row['badge_ids']),
      streakCount: toInt(row['streak_count']),
      longestStreak: toInt(row['longest_streak']),
      lastReadAt: parseTimestamp(row['last_read_at']),
      booksCompletedCount: toInt(row['books_completed_count']),
      createdAt: parseTimestamp(row['created_at']),
      isAdmin: row['is_admin'] as bool? ?? false,
    );
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? badgeIds,
    int? streakCount,
    int? longestStreak,
    DateTime? lastReadAt,
    int? booksCompletedCount,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      badgeIds: badgeIds ?? this.badgeIds,
      streakCount: streakCount ?? this.streakCount,
      longestStreak: longestStreak ?? this.longestStreak,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      booksCompletedCount: booksCompletedCount ?? this.booksCompletedCount,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [uid, email, displayName, streakCount, booksCompletedCount];
}
