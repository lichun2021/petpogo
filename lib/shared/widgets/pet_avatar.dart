import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class PetAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String fallbackEmoji;

  const PetAvatar({
    super.key,
    this.imageUrl,
    this.size = 44,
    this.fallbackEmoji = '🐾',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerLow,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _FallbackPetAvatar(
                size: size,
                fallbackEmoji: fallbackEmoji,
              ),
              errorWidget: (_, __, ___) => _FallbackPetAvatar(
                size: size,
                fallbackEmoji: fallbackEmoji,
              ),
            )
          : _FallbackPetAvatar(
              size: size,
              fallbackEmoji: fallbackEmoji,
            ),
    );
  }
}

class _FallbackPetAvatar extends StatelessWidget {
  final double size;
  final String fallbackEmoji;

  const _FallbackPetAvatar({
    required this.size,
    required this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    if (fallbackEmoji == '🐾') {
      return Container(
        color: AppColors.primaryContainer.withValues(alpha: 0.55),
        child: Icon(
          Icons.pets_rounded,
          color: AppColors.primary,
          size: size * 0.48,
        ),
      );
    }

    return Center(
      child: Text(
        fallbackEmoji,
        style: TextStyle(fontSize: size * 0.4),
      ),
    );
  }
}
