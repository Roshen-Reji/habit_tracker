import 'dart:io';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BookCoverThumbnail extends StatelessWidget {
  final PdfBook book;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showProgressBadge;
  final bool showSpine;

  const BookCoverThumbnail({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius,
    this.showProgressBadge = true,
    this.showSpine = true,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38BDF8);
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(ExpressiveTokens.radiusSm);

    return SizedBox(
      width: width,
      height: height,
      child: FutureBuilder<File?>(
        future: ReaderService.getOrCreateCoverThumbnail(
          book.path,
          book.modified,
        ),
        builder: (context, snapshot) {
          final file = snapshot.data;
          final hasImage = file != null && file.existsSync();

          return ClipRRect(
            borderRadius: effectiveRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base thumbnail or stylized placeholder cover
                if (hasImage)
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => _buildFallbackCover(accent),
                  )
                else
                  _buildFallbackCover(accent),

                // Realistic book spine crease overlay (if enabled)
                if (showSpine)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.2, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                // Favorite badge
                if (book.isFavorite)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.heart,
                        color: Colors.redAccent,
                        size: 11,
                      ),
                    ),
                  ),

                // Progress Badge / Finished tag
                if (showProgressBadge)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: book.isFinished
                            ? const Color(0xFF10B981).withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        book.isFinished
                            ? 'FINISHED'
                            : '${(book.progressFraction * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackCover(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PDF',
                  style: TextStyle(
                    color: accent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.fileText,
                color: accent.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
          const Spacer(),
          Text(
            book.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'p. ${book.lastPage} / ${book.totalPages}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
