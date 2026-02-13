import 'package:flutter/material.dart';
import 'package:barkdate/services/places_service.dart'; // Includes PlacesSessionTokenManager

/// A text field with Google Places autocomplete for selecting locations
class LocationPickerField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final ValueChanged<PlaceAutocomplete>? onPlaceSelected;
  
  const LocationPickerField({
    super.key,
    required this.controller,
    this.hintText = 'Search for a location...',
    this.validator,
    this.onPlaceSelected,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  List<PlaceAutocomplete> _suggestions = [];
  bool _isLoading = false;
  PlaceAutocomplete? _selectedPlace;
  
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.length < 2) {
      _hideOverlay();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final predictions = await PlacesService.autocomplete(query);
      if (mounted) {
        setState(() {
          _suggestions = predictions;
          _isLoading = false;
        });
        if (predictions.isNotEmpty) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey.shade600,
                          ),
                          title: Text(
                            suggestion.structuredFormatting.mainText,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            suggestion.structuredFormatting.secondaryText,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onSuggestionTap(suggestion),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _onSuggestionTap(PlaceAutocomplete suggestion) {
    _hideOverlay();
    _focusNode.unfocus();
    
    widget.controller.text = suggestion.structuredFormatting.mainText;
    setState(() => _selectedPlace = suggestion);
    widget.onPlaceSelected?.call(suggestion);
    
    // COST OPTIMIZATION: Reset session token after selection
    // This ends the current billing session so next search starts fresh
    PlacesSessionTokenManager.resetToken();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.location_on_outlined),
          suffixIcon: _selectedPlace != null
              ? Icon(Icons.check_circle, color: Colors.green.shade600)
              : (_isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: widget.validator,
      ),
    );
  }
}
