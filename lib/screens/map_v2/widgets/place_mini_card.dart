import 'package:flutter/material.dart';
import 'package:barkdate/services/places_service.dart';

/// Compact card widget shown when tapping a place marker
class PlaceMiniCard extends StatelessWidget {
  final PlaceResult place;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const PlaceMiniCard({
    super.key,
    required this.place,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with close button
            Row(
              children: [
                // Category icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(place.category).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getCategoryIcon(place.category),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Place name
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Category & Distance
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(place.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    place.category.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getCategoryColor(place.category),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (place.distance > 0)
                  Text(
                    '${(place.distance / 1000).toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Tap to view hint
            Text(
              'Tap for details →',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.park:
        return Colors.green;
      case PlaceCategory.restaurant:
        return Colors.orange;
      case PlaceCategory.petStore:
        return Colors.blue;
      case PlaceCategory.veterinary:
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  String _getCategoryIcon(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.park:
        return '🌳';
      case PlaceCategory.restaurant:
        return '☕';
      case PlaceCategory.petStore:
        return '🏪';
      case PlaceCategory.veterinary:
        return '⚕️';
      default:
        return '📍';
    }
  }
}
