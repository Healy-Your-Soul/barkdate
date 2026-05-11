import 'package:flutter/material.dart';

/// A mini popup card shown when tapping a live dog marker on the map.
///
/// Supports 4 friendship states:
///   null           → "Add to Pack" button
///   'pending_sent' → "Request Sent" chip (disabled)
///   'pending_received' → not used here (handled via notifications)
///   'accepted'     → "In Pack ✓" chip + "Walk Together" button
class DogMiniCard extends StatelessWidget {
  final String dogName;
  final String? humanName;
  final String? dogPhotoUrl;
  final String timeAgo;
  final String? friendshipStatus; // null | pending_sent | accepted
  final bool isOwnDog;
  final String? parkName;
  final VoidCallback? onWalkTogether;
  final VoidCallback? onAddToPack;
  final VoidCallback onClose;

  const DogMiniCard({
    super.key,
    required this.dogName,
    this.humanName,
    this.dogPhotoUrl,
    required this.timeAgo,
    this.friendshipStatus,
    this.isOwnDog = false,
    this.parkName,
    this.onWalkTogether,
    this.onAddToPack,
    required this.onClose,
  });

  bool get _isFriend => friendshipStatus == 'accepted';
  bool get _isPending =>
      friendshipStatus == 'pending_sent' ||
      friendshipStatus == 'pending_received';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20, color: Colors.grey),
              ),
            ),

            // Dog photo
            CircleAvatar(
              radius: 32,
              backgroundImage:
                  dogPhotoUrl != null ? NetworkImage(dogPhotoUrl!) : null,
              child:
                  dogPhotoUrl == null ? const Icon(Icons.pets, size: 32) : null,
            ),
            const SizedBox(height: 8),

            // Dog name (Human name)
            Text(
              dogName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (humanName != null)
              Text(
                '($humanName)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),

            const SizedBox(height: 4),

            // Status row — location + friendship badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFriend ? Icons.favorite : Icons.location_on,
                  size: 14,
                  color: _isFriend ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Park name if available
            if (parkName != null && parkName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                parkName!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Actions — hidden for own dog
            if (!isOwnDog)
              _buildActions()
            else
              Text(
                'This is you!',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_isFriend) {
      // Friend — show "In Pack" pill + "Walk Together" button
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In Pack pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                SizedBox(width: 4),
                Text(
                  'In Pack ✓',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Walk Together button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onWalkTogether,
              icon: const Icon(Icons.directions_walk, size: 16),
              label: const Text('Walk Together'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_isPending) {
      // Pending — show "Request Sent" chip
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  'Request Sent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Still allow Walk Together even for non-friends
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onWalkTogether,
              icon: const Icon(Icons.directions_walk, size: 16),
              label: const Text('Walk Together'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Color(0xFF0D47A1)),
                foregroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Non-friend — show "Add to Pack" + "Walk Together"
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAddToPack != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAddToPack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Add to Pack'),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onWalkTogether,
            icon: const Icon(Icons.directions_walk, size: 16),
            label: const Text('Walk Together'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: const BorderSide(color: Color(0xFF0D47A1)),
              foregroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
