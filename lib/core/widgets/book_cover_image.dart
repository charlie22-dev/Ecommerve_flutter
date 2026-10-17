import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_color_tokens.dart';

/// Renders a book cover image with caching, sizing optimization, and fallback states.
class BookCoverImage extends StatefulWidget {
  const BookCoverImage({super.key, required this.url, this.borderRadius = 10, this.fit = BoxFit.cover});

  final String url;
  final double borderRadius;
  final BoxFit fit;

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
  State<BookCoverImage> createState() => _BookCoverImageState();
}

class _BookCoverImageState extends State<BookCoverImage> {
  static const _maxRetries = 2;
  int _retryCount = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: widget.url.isEmpty
          ? _fallback(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final url = BookCoverImage.sizedUrl(widget.url, width.isFinite ? width : double.infinity);
                return CachedNetworkImage(
                  // Keying on the retry count forces a fresh CachedNetworkImage
                  // instance on retry, rather than re-showing a widget that's
                  // already resolved to its cached failure — plain image covers
                  // sometimes failed on first paint (a slow/blocked first
                  // fetch) but loaded fine moments later, which this retry
                  // now recovers from automatically instead of leaving a
                  // permanent fallback icon.
                  key: ValueKey('$url-$_retryCount'),
                  imageUrl: url,
                  fit: widget.fit,
                  // Decode at the size it's drawn, not the file's full size.
                  memCacheWidth: width.isFinite ? (width * dpr).round() : null,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => Shimmer.fromColors(
                    baseColor: context.colors.surfaceMuted,
                    highlightColor: context.colors.surface,
                    child: Container(color: context.colors.surfaceMuted),
                  ),
                  errorWidget: (_, _, _) {
                    if (_retryCount < _maxRetries) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Future.delayed(Duration(milliseconds: 400 * (_retryCount + 1)), () {
                          if (mounted) setState(() => _retryCount++);
                        });
                      });
                      return Shimmer.fromColors(
                        baseColor: context.colors.surfaceMuted,
                        highlightColor: context.colors.surface,
                        child: Container(color: context.colors.surfaceMuted),
                      );
                    }
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
