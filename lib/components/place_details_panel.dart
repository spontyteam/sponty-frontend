import 'package:flutter/material.dart';

import '../services/backend_api.dart';
import '../theme/colors.dart';

class PlaceDetailsPanel extends StatelessWidget {
  const PlaceDetailsPanel({
    super.key,
    required this.summary,
    required this.details,
    required this.isLoading,
    required this.error,
    required this.onClose,
  });

  final PlacePoint summary;
  final PlaceDetails? details;
  final bool isLoading;
  final String? error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = details?.name ?? summary.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralDarkest,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.neutralDarkLight),
            ),
          ],
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.neutralDarkLight),
            ),
          )
        else ...[
          _RatingRow(details: details),
          const SizedBox(height: 10),
          if ((details?.photoUrls.isNotEmpty ?? false))
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: details!.photoUrls.length.clamp(0, 3),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final url = details!.photoUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.neutralLightMedium,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppColors.neutralDarkLightest,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          if ((details?.photoUrls.isNotEmpty ?? false))
            const SizedBox(height: 10),
          Text(
            details?.summary ?? details?.address ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.neutralDarkMedium,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Address', value: details?.address),
          _InfoRow(label: 'Open now', value: _formatOpenNow(details?.openNow)),
          _InfoRow(label: 'Phone', value: details?.phone),
        ],
      ],
    );
  }

  String? _formatOpenNow(bool? openNow) {
    if (openNow == null) return null;
    return openNow ? 'Yes' : 'No';
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.details});

  final PlaceDetails? details;

  @override
  Widget build(BuildContext context) {
    final rating = details?.rating;
    final total = details?.userRatingsTotal;

    if (rating == null && total == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Icon(Icons.star, size: 16, color: AppColors.starDarkest),
        const SizedBox(width: 6),
        Text(
          rating != null ? rating.toStringAsFixed(1) : '-',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neutralDarkest,
          ),
        ),
        if (total != null) ...[
          const SizedBox(width: 6),
          Text(
            '($total)',
            style: const TextStyle(color: AppColors.neutralDarkLight),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutralDarkLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutralDarkMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
