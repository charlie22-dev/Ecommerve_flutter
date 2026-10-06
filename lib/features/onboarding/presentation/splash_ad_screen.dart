import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/onboarding/launch_prefs.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../catalog/presentation/catalog_providers.dart';

/// Shown once per install (see launch_prefs.dart) — a full-bleed collage of
/// real catalog covers behind the BookVerse mark, with "Start" pinned at
/// the bottom. Uses actual seeded book covers rather than stock/marketing
/// images, since none exist for this project.
class SplashAdScreen extends ConsumerWidget {
  const SplashAdScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    ref.read(hasSeenLaunchSplashProvider.notifier).state = true;
    await LaunchPrefs.markSplashSeen();
    if (context.mounted) context.go(AppRoute.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      backgroundColor: colors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          booksAsync.when(
            data: (books) {
              final covers = books.take(12).toList();
              if (covers.isEmpty) return const SizedBox.shrink();
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 0.66,
                ),
                itemCount: covers.length,
                itemBuilder: (context, i) => BookCoverImage(url: covers[i].coverUrl, borderRadius: 0),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, _) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.ink.withValues(alpha: 0.55),
                  colors.ink.withValues(alpha: 0.75),
                  colors.ink,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.menu_book_rounded, color: colors.onInk, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    'BookVerse',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onInk, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manga, manhwa, manhua, comics & light novels —\nshop your next read and track your shelf.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onInk.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  // Not PrimaryButton here — its theme styling is
                  // ink-on-onInk, which would blend into this screen's
                  // solid `ink` background. Inverted explicitly instead.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _start(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.onInk,
                        foregroundColor: colors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
