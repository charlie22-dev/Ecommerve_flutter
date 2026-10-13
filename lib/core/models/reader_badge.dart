import 'package:flutter/material.dart';

/// Static badge catalog for the gamified profile. Earned status is derived
/// client-side from `AppUser` counters — no separate database table
/// needed since the rules are simple thresholds.
class ReaderBadge {
  const ReaderBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isEarned,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isEarned;

  /// Computes the full badge list from profile counters.
  /// Pure client-side function — no network calls or database writes needed.
  static List<ReaderBadge> compute({
    required int booksCompletedCount,
    required int streakCount,
    required int longestStreak,
  }) {
    return [
      ReaderBadge(
        id: 'first_finish',
        title: 'First Finish',
        description: 'Complete your first book',
        icon: Icons.auto_stories_rounded,
        isEarned: booksCompletedCount >= 1,
      ),
      ReaderBadge(
        id: 'bookworm',
        title: 'Bookworm',
        description: 'Complete 10 books',
        icon: Icons.menu_book_rounded,
        isEarned: booksCompletedCount >= 10,
      ),
      ReaderBadge(
        id: 'collector',
        title: 'Collector',
        description: 'Complete 25 books',
        icon: Icons.collections_bookmark_rounded,
        isEarned: booksCompletedCount >= 25,
      ),
      ReaderBadge(
        id: 'on_a_roll',
        title: 'On a Roll',
        description: 'Reach a 3-day reading streak',
        icon: Icons.local_fire_department_rounded,
        isEarned: streakCount >= 3 || longestStreak >= 3,
      ),
      ReaderBadge(
        id: 'unstoppable',
        title: 'Unstoppable',
        description: 'Reach a 7-day reading streak',
        icon: Icons.bolt_rounded,
        isEarned: streakCount >= 7 || longestStreak >= 7,
      ),
      ReaderBadge(
        id: 'marathoner',
        title: 'Marathoner',
        description: 'Reach a 30-day reading streak',
        icon: Icons.emoji_events_rounded,
        isEarned: streakCount >= 30 || longestStreak >= 30,
      ),
    ];
  }
}
