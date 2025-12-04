import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/features/events/presentation/providers/event_provider.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/app_button.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  bool _isLoading = false;
  bool _isParticipating = false;
  String? _currentUserId;
  String? _currentDogId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _checkParticipation();
  }

  Future<void> _getCurrentUser() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
      
      // Get user's first dog for participation
      try {
        final dogs = await BarkDateUserService.getUserDogs(user.id);
        if (dogs.isNotEmpty) {
          setState(() {
            _currentDogId = dogs.first['id'];
          });
        }
      } catch (e) {
        debugPrint('Error getting user dogs: $e');
      }
    }
  }

  Future<void> _checkParticipation() async {
    if (_currentUserId == null) return;
    
    try {
      final participating = await ref.read(eventRepositoryProvider).isUserParticipating(
        eventId: widget.event.id,
        userId: _currentUserId!,
      );
      if (mounted) {
        setState(() {
          _isParticipating = participating;
        });
      }
    } catch (e) {
      debugPrint('Error checking participation: $e');
    }
  }

  Future<void> _joinEvent() async {
    if (_currentUserId == null || _currentDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a dog profile first')),
      );
      return;
    }

    if (widget.event.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event is full')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(eventRepositoryProvider).joinEvent(
        eventId: widget.event.id,
        userId: _currentUserId!,
        dogId: _currentDogId!,
      );

      if (success) {
        setState(() {
          _isParticipating = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Joined event successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to join event. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error joining event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _leaveEvent() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(eventRepositoryProvider).leaveEvent(
        eventId: widget.event.id,
        userId: _currentUserId!,
      );

      if (success) {
        setState(() {
          _isParticipating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left event'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to leave event. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error leaving event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Category icon
                    Positioned(
                      top: 60,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.event.categoryIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    
                    // Price badge
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.event.isFree ? Colors.green : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.event.isFree ? 'FREE' : widget.event.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Event details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Organizer
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: widget.event.organizerAvatarUrl.isNotEmpty
                            ? NetworkImage(widget.event.organizerAvatarUrl)
                            : null,
                        child: widget.event.organizerAvatarUrl.isEmpty
                            ? Icon(
                                widget.event.organizerType == 'professional' 
                                    ? Icons.business 
                                    : Icons.person,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Organized by ${widget.event.organizerName}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.event.categoryDisplayName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Date and time
                  _buildDetailRow(
                    icon: Icons.schedule,
                    title: 'Date & Time',
                    content: widget.event.formattedDate,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Location
                  _buildDetailRow(
                    icon: Icons.location_on,
                    title: 'Location',
                    content: widget.event.location,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Participants
                  _buildDetailRow(
                    icon: Icons.pets,
                    title: 'Participants',
                    content: '${widget.event.currentParticipants}/${widget.event.maxParticipants} dogs',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  Text(
                    'About This Event',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description ?? 'No description provided.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Target audience
                  if (widget.event.targetAgeGroups.isNotEmpty || widget.event.targetSizes.isNotEmpty) ...[
                    Text(
                      'Target Audience',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (widget.event.targetAgeGroups.isNotEmpty) ...[
                      Text(
                        'Age Groups',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: widget.event.targetAgeGroups.map((age) => 
                          _buildChip(context, age.capitalize(), Theme.of(context).colorScheme.secondary)
                        ).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    if (widget.event.targetSizes.isNotEmpty) ...[
                      Text(
                        'Sizes',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: widget.event.targetSizes.map((size) => 
                          _buildChip(context, size.capitalize(), Theme.of(context).colorScheme.tertiary)
                        ).toList(),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                  ],
                  
                  // Action button
                  AppButton(
                    text: _isParticipating
                        ? 'Leave Event'
                        : widget.event.isFull
                            ? 'Event Full'
                            : 'Join Event',
                    onPressed: _isLoading
                        ? null
                        : (_isParticipating ? _leaveEvent : _joinEvent),
                    isLoading: _isLoading,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    customColor: _isParticipating
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
