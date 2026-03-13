import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/map/presentation/providers/map_provider.dart';
import 'package:barkdate/services/places_service.dart';

/// Search bar for map places with autocomplete support
class MapSearchBar extends ConsumerStatefulWidget {
  const MapSearchBar({super.key});

  @override
  ConsumerState<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends ConsumerState<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay to allow tap on suggestion to register
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 64,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    title: Text(
                      _suggestions[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _selectSuggestion(_suggestions[index]),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onSearchChanged(String value) {
    // Clear AI suggestions when user manually searches
    ref.read(mapFiltersProvider.notifier).clearAiSuggestions();

    // Cancel previous debounce
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      _removeOverlay();
      ref.read(mapFiltersProvider.notifier).setSearchQuery('');
      return;
    }

    // Debounce autocomplete requests (300ms)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(value);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final viewport = ref.read(mapViewportProvider);
      final suggestions = await PlacesService.getAutocompleteSuggestions(
        input: query,
        apiKey: '', // Uses the already loaded Google Maps API
        latitude: viewport.center.latitude,
        longitude: viewport.center.longitude,
      );

      if (mounted && _controller.text == query) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });

        if (suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    _removeOverlay();
    _focusNode.unfocus();
    _executeSearch(suggestion);
  }

  void _executeSearch(String query) {
    ref.read(mapFiltersProvider.notifier).setSearchQuery(query);
    // Trigger a refresh of map data
    ref.invalidate(mapDataProvider);
  }

  void _onSubmitted(String value) {
    _removeOverlay();
    if (value.trim().isNotEmpty) {
      _executeSearch(value.trim());
    }
  }

  void _clearSearch() {
    _controller.clear();
    _removeOverlay();
    ref.read(mapFiltersProvider.notifier).setSearchQuery('');
    ref.invalidate(mapDataProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Watch mapFiltersProvider to trigger rebuilds when filters change
    ref.watch(mapFiltersProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search dog-friendly places...',
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.primary,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
