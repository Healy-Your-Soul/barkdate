import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/notification_manager.dart';

class DogDetailsScreen extends StatefulWidget {
  final Dog dog;

  const DogDetailsScreen({super.key, required this.dog});

  @override
  State<DogDetailsScreen> createState() => _DogDetailsScreenState();
}

class _DogDetailsScreenState extends State<DogDetailsScreen> {
  late PageController _pageController;
  int _currentPhotoIndex = 0;
  bool _isBarked = false;
  bool _isLoading = false;
  String? _friendshipStatus; // null, 'pending', 'accepted', 'declined'
  String? _friendshipId;
  String? _myDogId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadFriendshipStatus();
  }

  Future<void> _loadFriendshipStatus() async {
    // Get current user's first dog to check friendship
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    final myDogs = await BarkDateUserService.getUserDogs(userId);
    if (myDogs.isEmpty) return;

    _myDogId = myDogs.first['id'];
    if (_myDogId == null) return;

    // Don't show bark for your own dogs
    if (_myDogId == widget.dog.id) return;

    final friendship = await DogFriendshipService.getFriendshipStatus(
      dogId1: _myDogId!,
      dogId2: widget.dog.id,
    );

    if (mounted) {
      setState(() {
        _friendshipStatus = friendship?['status'];
        _friendshipId = friendship?['id'];
        _isBarked = _friendshipStatus != null;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onAddToPack() async {
    if (_myDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need a dog to add friends!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_friendshipStatus == null) {
        // Send a new friend request
        final success = await DogFriendshipService.sendBark(
          fromDogId: _myDogId!,
          toDogId: widget.dog.id,
        );

        if (success && mounted) {
          setState(() {
            _isBarked = true;
            _friendshipStatus = 'pending';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${widget.dog.name}! 🐕'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already friends or error occurred')),
          );
        }
      } else if (_friendshipId != null) {
        // Remove existing bark/friendship
        final success = await DogFriendshipService.removeFriendship(_friendshipId!);

        if (success && mounted) {
          setState(() {
            _isBarked = false;
            _friendshipStatus = null;
            _friendshipId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${widget.dog.name} from pack'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onBarkPoke() async {
    if (_myDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need a dog to bark!')),
      );
      return;
    }

    // Get my dog details for the notification
    final myDogName = (await BarkDateUserService.getUserDogs(SupabaseConfig.auth.currentUser!.id)).firstWhere((d) => d['id'] == _myDogId)['name'];

    try {
      // Use BarkDateBarkService with rate limiting (3/day for non-friends)
      final success = await BarkDateBarkService.sendBark(
        fromDogId: _myDogId!,
        toDogId: widget.dog.id,
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You\'ve reached your daily bark limit for this pup! 🐕'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Also send push notification
      await NotificationManager.sendBarkNotification(
        receiverUserId: widget.dog.ownerId,
        senderDogName: myDogName ?? 'Someone',
        receiverDogName: widget.dog.name,
        senderUserId: SupabaseConfig.auth.currentUser?.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You barked at ${widget.dog.name}! 🐕'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending bark poke: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send bark right now')),
        );
      }
    }
  }

  void _onMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat feature coming soon!')),
    );
  }

  void _onSuggestPlaydate() {
    context.push('/create-playdate', extra: widget.dog);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.dog.photos.isNotEmpty ? widget.dog.photos : ['https://via.placeholder.com/400'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // 1. Sliver App Bar with Image Carousel
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.share_outlined, color: Colors.black),
                          onPressed: () {
                            // TODO: Share
                          },
                        ),
                      ),
                    ),
                    // Removed Heart icon as per user request
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentPhotoIndex = index),
                          itemCount: photos.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              photos[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.pets, size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.dog.name,
                                          style: AppTypography.h3().copyWith(color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_currentPhotoIndex + 1} / ${photos.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.dog.name,
                                    style: AppTypography.h1().copyWith(fontSize: 32),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.dog.breed} • ${widget.dog.age} years old',
                                    style: AppTypography.h3().copyWith(fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                            // Distance badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.dog.distanceKm.toStringAsFixed(1)} km',
                                    style: AppTypography.labelSmall().copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 48),

                        // Human Section
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${widget.dog.ownerId}'),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('My human ${widget.dog.ownerName}', style: AppTypography.h3().copyWith(fontSize: 16)),
                                Text('${widget.dog.age} years barking together', style: AppTypography.bodySmall().copyWith(color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),

                        const Divider(height: 48),

                        // About Section
                        Text('About ${widget.dog.name}', style: AppTypography.h2()),
                        const SizedBox(height: 16),
                        Text(
                          widget.dog.bio.isNotEmpty ? widget.dog.bio : 'No bio available.',
                          style: AppTypography.bodyLarge().copyWith(color: Colors.grey[800]),
                        ),

                        const Divider(height: 48),

                        // Details Grid
                        Text('Details', style: AppTypography.h2()),
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.straighten, 'Size', widget.dog.size),
                        _buildDetailRow(Icons.transgender, 'Gender', widget.dog.gender),
                        _buildDetailRow(Icons.bolt, 'Energy', 'High'), // Placeholder

                        const SizedBox(height: 32),
                        
                        // Action Buttons (only show for other people's dogs)
                        if (_myDogId != null && _myDogId != widget.dog.id) ...[
                          Row(
                            children: [
                              // Add to Pack Button (Primary)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _onAddToPack,
                                  icon: _isLoading 
                                    ? const SizedBox(
                                        width: 16, 
                                        height: 16, 
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(
                                        _isBarked ? Icons.check : Icons.group_add,
                                        color: _isBarked ? Colors.white : null,
                                      ),
                                  label: Text(_getAddButtonText()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isBarked 
                                      ? (_friendshipStatus == 'accepted' ? Colors.green : Colors.grey)
                                      : null,
                                    foregroundColor: _isBarked ? Colors.white : null,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Message Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _onMessage,
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Message'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Secondary Row: Bark + Playdate
                          Row(
                            children: [
                              // Bark Poke Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _onBarkPoke,
                                  icon: const Icon(Icons.pets, color: Colors.orange),
                                  label: const Text('Bark 👋'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Playdate Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _onSuggestPlaydate,
                                  icon: const Icon(Icons.calendar_today),
                                  label: const Text('Playdate'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAddButtonText() {
    switch (_friendshipStatus) {
      case 'pending':
        return 'Request Sent';
      case 'accepted':
        return 'In Pack';
      case 'declined':
        return 'Try Again';
      default:
        return 'Add to Pack';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.h3().copyWith(fontSize: 16)),
                Text(value, style: AppTypography.bodyMedium().copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
