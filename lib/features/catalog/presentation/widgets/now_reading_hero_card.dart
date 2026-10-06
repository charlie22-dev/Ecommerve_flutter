import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_cover_image.dart';
import '../../../../core/widgets/reading_progress_bar.dart';
import '../../../library/presentation/library_providers.dart';

/// The "Now Reading" hero from basis.png: cover thumbnail, title/chapter/
/// author, a progress readout, and a full-width "Continue Reading" pill.
class NowReadingHeroCard extends StatelessWidget {
  const NowReadingHeroCard({super.key, required this.nowReading});

  final NowReading nowReading;

  @override
  Widget build(BuildContext context) {
    final book = nowReading.book;
    final entry = nowReading.entry;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed height so the Expanded/Spacer column below has a bounded
          // main-axis constraint to lay out against.
          SizedBox(
            height: 144,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  height: 144,
                  child: BookCoverImage(url: book.coverUrl, borderRadius: 12),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      if (entry.currentChapter > 0)
                        Text(
                          'Chapter ${entry.currentChapter}',
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                        ),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.progressPercent.round()}% complete',
                        style: TextStyle(
                          color: context.colors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ReadingProgressBar(percent: entry.progressPercent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.push('/home/book/${book.id}'),
              child: const Text('Continue Reading'),
            ),
          ),
        ],
      ),
    );
  }
}
