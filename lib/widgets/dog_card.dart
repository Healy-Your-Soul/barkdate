import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/theme.dart';

class DogCard extends StatelessWidget {
  final Dog dog;
  final VoidCallback onBarkPressed;
  final VoidCallback? onPlaydatePressed;
  final VoidCallback? onOpenProfile;

  const DogCard({
    super.key,
    required this.dog,
    required this.onBarkPressed,
    this.onPlaydatePressed,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Dog photo
            GestureDetector(
              onTap: onOpenProfile,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.network(
                  dog.photos.first,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.pets,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Dog details
            Expanded(
              child: GestureDetector(
                onTap: onOpenProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dog.breed}, ${dog.distanceKm.toStringAsFixed(1)} miles',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'with ${dog.ownerName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons (Bark and Playdate)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bark button
                SizedBox(
                  width: 85,
                  child: ElevatedButton(
                    onPressed: onBarkPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark 
                        ? DarkModeColors.darkBarkButton 
                        : LightModeColors.lightBarkButton,
                      foregroundColor: isDark 
                        ? DarkModeColors.darkOnBarkButton 
                        : LightModeColors.lightOnBarkButton,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Bark',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark 
                          ? DarkModeColors.darkOnBarkButton 
                          : LightModeColors.lightOnBarkButton,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Playdate button
                SizedBox(
                  width: 85,
                  child: OutlinedButton.icon(
                    onPressed: onPlaydatePressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      'Play',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}