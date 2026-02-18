import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/services/places_service.dart';

/// Selection state for map markers
class MapSelection {
  final PlaceResult? selectedPlace;
  final Event? selectedEvent;
  final bool showAiAssistant;

  const MapSelection({
    this.selectedPlace,
    this.selectedEvent,
    this.showAiAssistant = false,
  });

  MapSelection copyWith({
    PlaceResult? selectedPlace,
    Event? selectedEvent,
    bool? showAiAssistant,
    bool clearPlace = false,
    bool clearEvent = false,
  }) {
    return MapSelection(
      selectedPlace: clearPlace ? null : (selectedPlace ?? this.selectedPlace),
      selectedEvent: clearEvent ? null : (selectedEvent ?? this.selectedEvent),
      showAiAssistant: showAiAssistant ?? this.showAiAssistant,
    );
  }

  bool get hasSelection =>
      selectedPlace != null || selectedEvent != null || showAiAssistant;

  void clear() {
    // This is handled by the controller
  }
}

/// Controller for map selection
class MapSelectionController extends StateNotifier<MapSelection> {
  MapSelectionController() : super(const MapSelection());

  void selectPlace(PlaceResult place) {
    state = MapSelection(selectedPlace: place);
  }

  void selectEvent(Event event) {
    state = MapSelection(selectedEvent: event);
  }

  void showAiAssistant() {
    state = const MapSelection(showAiAssistant: true);
  }

  void clearSelection() {
    state = const MapSelection();
  }
}

/// Provider for map selection
final mapSelectionProvider =
    StateNotifierProvider<MapSelectionController, MapSelection>((ref) {
  return MapSelectionController();
});
