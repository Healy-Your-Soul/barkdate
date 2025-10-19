import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/screens/chat_detail_screen.dart';
import 'package:barkdate/models/message.dart';
import 'package:barkdate/screens/playdates_screen.dart';

class DogProfileSheet extends StatelessWidget {
  final Dog dog;
  final VoidCallback onBark;

  const DogProfileSheet({super.key, required this.dog, required this.onBark});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _HeaderPhoto(dog: dog),
              const SizedBox(height: 16),
              Text(
                dog.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${dog.breed} • ${dog.age} yrs • ${dog.size}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    '${dog.distanceKm.toStringAsFixed(1)} km away',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                dog.bio,
                style: Theme.of(context).textTheme.bodyLarge,
                softWrap: true,
              ),
              const SizedBox(height: 16),
              _OwnerRow(ownerName: dog.ownerName),
              const SizedBox(height: 20),
              _ActionRow(
                onBark: () {
                  Navigator.pop(context);
                  onBark();
                },
                onMessage: () {
                  Navigator.pop(context);
                  final preview = ChatPreview(
                    chatId: 'new_${dog.id}',
                    otherUserId: dog.ownerId,
                    otherUserName: dog.ownerName,
                    otherDogName: dog.name,
                    otherDogPhoto: dog.photos.isNotEmpty ? dog.photos.first : '',
                    lastMessage: '',
                    lastMessageTime: DateTime.now(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        recipientName: dog.ownerName,
                        dogName: dog.name,
                      ),
                    ),
                  );
                },
                onInvite: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlaydatesScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  final Dog dog;
  const _HeaderPhoto({required this.dog});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              dog.photos.isNotEmpty ? dog.photos.first : '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Icon(Icons.pets, size: 48, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pets, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      dog.gender,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  final String ownerName;
  const _OwnerRow({required this.ownerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Owner', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              Text(ownerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onBark;
  final VoidCallback onMessage;
  final VoidCallback onInvite;
  const _ActionRow({required this.onBark, required this.onMessage, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onBark,
            icon: Icon(Icons.campaign, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Bark', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.event_available),
            label: const Text('Invite'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }
}
