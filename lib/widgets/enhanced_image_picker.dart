import 'package:flutter/material.dart';

import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';

/// Enhanced Image Picker with multi-selection, preview, and reordering
class EnhancedImagePicker extends StatefulWidget {
  final bool allowMultiple;
  final int maxImages;
  final List<SelectedImage> initialImages;
  final Function(List<SelectedImage>) onImagesChanged;
  final Widget? placeholder;
  final String? title;
  final bool showPreview;

  const EnhancedImagePicker({
    super.key,
    this.allowMultiple = false,
    this.maxImages = 10,
    this.initialImages = const [],
    required this.onImagesChanged,
    this.placeholder,
    this.title,
    this.showPreview = true,
  });

  @override
  State<EnhancedImagePicker> createState() => _EnhancedImagePickerState();
}

class _EnhancedImagePickerState extends State<EnhancedImagePicker> {
  late List<SelectedImage> _selectedImages;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.initialImages);
  }

  Future<void> _pickImages() async {
    setState(() => _isLoading = true);

    try {
      if (widget.allowMultiple) {
        final availableSlots = widget.maxImages - _selectedImages.length;
        if (availableSlots <= 0) {
          _showMaxImagesReached();
          return;
        }

        final files = await context.showMultiImagePicker(maxImages: availableSlots);
        if (files != null && files.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(files);
          });
          widget.onImagesChanged(_selectedImages);
        }
      } else {
        final file = await context.showImagePicker();
        if (file != null) {
          setState(() {
            _selectedImages = [file];
          });
          widget.onImagesChanged(_selectedImages);
        }
      }
    } catch (e) {
      _showError('Failed to pick images: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onImagesChanged(_selectedImages);
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
    widget.onImagesChanged(_selectedImages);
  }

  void _showMaxImagesReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.maxImages} images allowed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Image preview grid
        if (widget.showPreview && _selectedImages.isNotEmpty) ...[
          _buildImageGrid(),
          const SizedBox(height: 16),
        ],

        // Add images button
        _buildAddButton(),

        // Loading indicator
        if (_isLoading) ...[
          const SizedBox(height: 12),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }

  Widget _buildImageGrid() {
    if (!widget.allowMultiple && _selectedImages.isNotEmpty) {
      // Single image preview
      return _buildSingleImagePreview(_selectedImages.first);
    }

    // Multiple images grid with reordering
    return SizedBox(
      height: 120,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        onReorder: _reorderImages,
        itemBuilder: (context, index) {
          return _buildImageThumbnail(
            key: ValueKey('image_$index'),
            imageFile: _selectedImages[index],
            index: index,
          );
        },
      ),
    );
  }

  Widget _buildSingleImagePreview(SelectedImage imageFile) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.memory(
              imageFile.bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          
          // Delete button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeImage(0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail({
    required Key key,
    required SelectedImage imageFile,
    required int index,
  }) {
    return Container(
      key: key,
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              imageFile.bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          
          // Delete button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
          
          // Reorder handle
          if (widget.allowMultiple)
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(
                Icons.drag_handle,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    final canAddMore = _selectedImages.length < widget.maxImages;
    final hasImages = _selectedImages.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: canAddMore && !_isLoading ? _pickImages : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: canAddMore 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey[300]!,
          ),
        ),
        icon: Icon(
          hasImages ? Icons.add_photo_alternate : Icons.camera_alt,
          color: canAddMore 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey[500],
        ),
        label: Text(
          _getButtonText(),
          style: TextStyle(
            color: canAddMore 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (_selectedImages.isEmpty) {
      return widget.allowMultiple ? 'Add Photos' : 'Add Photo';
    }
    
    if (!widget.allowMultiple) {
      return 'Change Photo';
    }
    
    final remaining = widget.maxImages - _selectedImages.length;
    if (remaining <= 0) {
      return 'Maximum ${widget.maxImages} photos selected';
    }
    
    return 'Add More Photos (${_selectedImages.length}/${widget.maxImages})';
  }
}

/// Simple image thumbnail widget for displaying selected images
class ImageThumbnail extends StatelessWidget {
  final SelectedImage imageFile;
  final VoidCallback? onDelete;
  final double size;
  final bool showDeleteButton;

  const ImageThumbnail({
    super.key,
    required this.imageFile,
    this.onDelete,
    this.size = 60,
    this.showDeleteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              imageFile.bytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        if (showDeleteButton && onDelete != null)
          Positioned(
            top: -2,
            right: -2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
