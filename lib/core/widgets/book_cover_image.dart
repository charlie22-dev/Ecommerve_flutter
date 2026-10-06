import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_color_tokens.dart';

class BookCoverImage extends StatefulWidget {
  const BookCoverImage({
    super.key,
    required this.url,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double borderRadius;
  final BoxFit fit;

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
          : CachedNetworkImage(
              // Keying on the retry count forces a fresh CachedNetworkImage
              // instance on retry, rather than re-showing a widget that's
              // already resolved to its cached failure — plain image covers
              // sometimes failed on first paint (a slow/blocked first
              // fetch) but loaded fine moments later, which this retry
              // now recovers from automatically instead of leaving a
              // permanent fallback icon.
              key: ValueKey('${widget.url}-$_retryCount'),
              imageUrl: widget.url,
              fit: widget.fit,
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
