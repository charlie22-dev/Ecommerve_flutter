import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_color_tokens.dart';

/// Renders a book cover image with caching, sizing optimization, and resilient fallback states.
class BookCoverImage extends StatelessWidget {
  const BookCoverImage({
    super.key,
    required this.url,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double borderRadius;
  final BoxFit fit;

  /// Cache of URLs that failed to load (e.g. 404 Not Found from Open Library).
  /// Prevents spamming the network and WebGL texture pipeline on every scroll/rebuild.
  static final Set<String> _failedUrls = <String>{};

  /// Open Library serves each cover in S/M/L. The seed data links L (~50 KB,
  /// often 3s+); M (~18 KB, under 1s) is plenty for anything drawn up to
  /// ~220px wide, so cards and lists ask for M and only big covers keep L.
  /// `default=false` makes a missing cover a 404 (-> our fallback icon)
  /// instead of a blank 1x1 image that "loads" fine and shows nothing.
  static String sizedUrl(String url, double width) {
    if (!url.contains('covers.openlibrary.org')) return url;
    final sized = width <= 220 ? url.replaceFirst('-L.jpg', '-M.jpg') : url;
    return sized.contains('?') ? sized : '$sized?default=false';
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _fallback(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final finalUrl = BookCoverImage.sizedUrl(url, width.isFinite ? width : double.infinity);

          if (_failedUrls.contains(finalUrl)) {
            return _fallback(context);
          }

          return CachedNetworkImage(
            imageUrl: finalUrl,
            fit: fit,
            memCacheWidth: (width > 0 && width.isFinite) ? (width * dpr).round() : null,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => Shimmer.fromColors(
              baseColor: context.colors.surfaceMuted,
              highlightColor: context.colors.surface,
              child: Container(color: context.colors.surfaceMuted),
            ),
            errorWidget: (_, _, _) {
              _failedUrls.add(finalUrl);
              return _fallback(context);
            },
          );
        },
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.colors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded, color: context.colors.textTertiary, size: 28),
    );
  }
}
