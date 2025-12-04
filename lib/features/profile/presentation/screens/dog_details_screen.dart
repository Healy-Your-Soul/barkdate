import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onBark() {
    setState(() => _isBarked = !_isBarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBarked ? 'You barked at ${widget.dog.name}! 🐕' : 'Bark removed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
                        Text(
                          widget.dog.name,
                          style: AppTypography.h1().copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.dog.breed} • ${widget.dog.age} years old',
                          style: AppTypography.h3().copyWith(fontWeight: FontWeight.normal),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.black),
                            const SizedBox(width: 4),
                            Text('4.98', style: AppTypography.labelMedium()), // Mock rating
                            const SizedBox(width: 4),
                            Text('·', style: AppTypography.labelMedium()),
                            const SizedBox(width: 4),
                            Text('12 reviews', style: AppTypography.labelMedium().copyWith(decoration: TextDecoration.underline)),
                            const Spacer(),
                            Text('${widget.dog.distanceKm.toStringAsFixed(1)} miles away', style: AppTypography.bodySmall()),
                          ],
                        ),

                        const Divider(height: 48),

                        // Host Section
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${widget.dog.ownerId}'), // Mock owner image
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hosted by ${widget.dog.ownerName}', style: AppTypography.h3().copyWith(fontSize: 16)),
                                Text('Superhost · 3 years barking', style: AppTypography.bodySmall().copyWith(color: Colors.grey[600])),
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
                        
                        // Inline Action Button
                        const SizedBox(height: 32),
                        
                        // Removed "Schedule Playdate" button as per user request
                        // The flow should be initiated from other places or maybe just chat first
                        
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
