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
              placeholder: (_, __) => Center(
                child: Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.4)),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.4)),
              ),
            )
          : Center(
              child: Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.4)),
            ),
    );
  }
}
