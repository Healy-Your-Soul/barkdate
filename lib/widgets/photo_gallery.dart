import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barkdate/services/selected_image.dart';

/// Tinder-style photo gallery with swipe navigation and full-screen viewing
class PhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  final List<SelectedImage>? localImages;
  final int initialIndex;
  final bool isEditable;
  final Function(List<String>)? onReorder;
  final Function(String)? onDelete;
  final Widget? emptyState;
  final bool showThumbnails;
  final bool enableZoom;

  const PhotoGallery({
    super.key,
    this.photoUrls = const [],
    this.localImages,
    this.initialIndex = 0,
    this.isEditable = false,
    this.onReorder,
    this.onDelete,
    this.emptyState,
    this.showThumbnails = true,
    this.enableZoom = true,
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<dynamic> get _allImages {
    final List<dynamic> images = [];
    images.addAll(widget.photoUrls);
    if (widget.localImages != null) {
      images.addAll(widget.localImages!);
    }
    return images;
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _deleteCurrentImage() {
    if (widget.onDelete != null && _currentIndex < widget.photoUrls.length) {
      final imageToDelete = widget.photoUrls[_currentIndex];
      widget.onDelete!(imageToDelete);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCurrentImage();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allImages.isEmpty) {
      return widget.emptyState ?? _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main photo gallery
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: _allImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: _getImageProvider(_allImages[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: widget.enableZoom ? PhotoViewComputedScale.covered * 3 : PhotoViewComputedScale.contained,
                onTapUp: (context, details, controllerValue) => _toggleUI(),
                heroAttributes: PhotoViewHeroAttributes(tag: 'photo_$index'),
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

          // UI Overlay
          AnimatedOpacity(
            opacity: _showUI ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildUIOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        // Top bar
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                
                const Spacer(),
                
                // Photo counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${_allImages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Delete button (if editable)
                if (widget.isEditable && widget.onDelete != null)
                  IconButton(
                    onPressed: _showDeleteConfirmation,
                    icon: const Icon(Icons.delete, color: Colors.white),
                  )
                else
                  const SizedBox(width: 48), // Balance the layout
              ],
            ),
          ),
        ),
        
        const Spacer(),
        
        // Bottom thumbnail strip
        if (widget.showThumbnails && _allImages.length > 1)
          _buildThumbnailStrip(),
      ],
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allImages.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnailImage(_allImages[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnailImage(dynamic image) {
    if (image is String) {
      return CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.image, color: Colors.white54),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.error, color: Colors.white54),
        ),
      );
    } else if (image is SelectedImage) {
      return Image.memory(
        image.bytes,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        color: Colors.grey[800],
        child: const Icon(Icons.image, color: Colors.white54),
      );
    }
  }

  ImageProvider _getImageProvider(dynamic image) {
    if (image is String) {
      return CachedNetworkImageProvider(image);
    } else if (image is SelectedImage) {
      return MemoryImage(image.bytes);
    } else {
      throw ArgumentError('Unsupported image type: ${image.runtimeType}');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No photos to display',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact photo gallery for card views with thumbnail navigation
class CompactPhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  final double height;
  final bool showIndicator;
  final Function(int)? onPhotoTap;

  const CompactPhotoGallery({
    super.key,
    required this.photoUrls,
    this.height = 200,
    this.showIndicator = true,
    this.onPhotoTap,
  });

  @override
  State<CompactPhotoGallery> createState() => _CompactPhotoGalleryState();
}

class _CompactPhotoGalleryState extends State<CompactPhotoGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.pets,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    if (widget.photoUrls.length == 1) {
      return GestureDetector(
        onTap: () => widget.onPhotoTap?.call(0),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: widget.photoUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.photoUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => widget.onPhotoTap?.call(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.photoUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Photo counter indicator
        if (widget.showIndicator)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentIndex + 1}/${widget.photoUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Navigation indicators (dots)
        if (widget.showIndicator && widget.photoUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photoUrls.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 6,
                  width: _currentIndex == index ? 20 : 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
