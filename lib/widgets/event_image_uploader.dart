import 'dart:typed_data';

import 'package:barkdate/services/selected_image.dart';
import 'package:flutter/material.dart';

class EventImageUploader extends StatelessWidget {
  final List<SelectedImage> images;
  final int maxImages;
  final VoidCallback onAddPressed;
  final void Function(int index) onRemovePressed;
  final bool isUploading;
  final int uploadCurrent;
  final int uploadTotal;

  const EventImageUploader({
    super.key,
    required this.images,
    required this.onAddPressed,
    required this.onRemovePressed,
    this.maxImages = 5,
    this.isUploading = false,
    this.uploadCurrent = 0,
    this.uploadTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddMore = images.length < maxImages && !isUploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Event photos',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text('(${images.length}/$maxImages)',
                style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length + (canAddMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (canAddMore && index == images.length) {
              return _AddTile(
                  onPressed: onAddPressed, isUploading: isUploading);
            }

            final image = images[index];
            return _ImagePreviewTile(
              imageBytes: image.bytes,
              onRemove: () => onRemovePressed(index),
            );
          },
        ),
        if (isUploading && uploadTotal > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Uploading photos... ($uploadCurrent/$uploadTotal)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Add up to $maxImages photos to showcase your event vibe. First photo is used as the cover.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isUploading;

  const _AddTile({
    required this.onPressed,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: isUploading ? null : onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Center(
          child: isUploading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 32, color: theme.colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('Add photos',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ImagePreviewTile extends StatelessWidget {
  final Uint8List imageBytes;
  final VoidCallback onRemove;

  const _ImagePreviewTile({
    required this.imageBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: MemoryImage(imageBytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
