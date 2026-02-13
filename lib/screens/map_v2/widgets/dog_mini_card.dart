import 'package:flutter/material.dart';

/// A mini popup card shown when tapping a live dog marker on the map
class DogMiniCard extends StatelessWidget {
  final String dogName;
  final String? humanName;
  final String? dogPhotoUrl;
  final String timeAgo;
  final bool isFriend;
  final bool isOwnDog; // Can't bark at yourself!
  final VoidCallback onBark;
  final VoidCallback? onAddToPack;
  final VoidCallback onClose;

  const DogMiniCard({
    super.key,
    required this.dogName,
    this.humanName,
    this.dogPhotoUrl,
    required this.timeAgo,
    required this.isFriend,
    this.isOwnDog = false,
    required this.onBark,
    this.onAddToPack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 200),
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
              backgroundImage: dogPhotoUrl != null 
                  ? NetworkImage(dogPhotoUrl!) 
                  : null,
              child: dogPhotoUrl == null 
                  ? const Icon(Icons.pets, size: 32) 
                  : null,
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
            
            // Status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFriend ? Icons.favorite : Icons.location_on,
                  size: 14,
                  color: isFriend ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  isFriend ? 'Friend • $timeAgo' : timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Actions - hidden for own dog
            if (!isOwnDog)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFriend && onAddToPack != null)
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
                  
                  if (!isFriend) const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: isFriend 
                      ? ElevatedButton.icon(
                          onPressed: onBark,
                          icon: const Icon(Icons.record_voice_over, size: 16),
                          label: const Text('Bark 👋'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onBark,
                          icon: const Icon(Icons.record_voice_over, size: 14),
                          label: const Text('Bark 👋'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: Colors.orange),
                            foregroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                  ),
                ],
              )
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
}
