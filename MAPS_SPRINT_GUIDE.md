# Barkdate Maps Sprint Guide

This guide provides practical examples and code snippets for integrating Google Maps and Places features in Flutter web, based on official documentation. Use these patterns for your sprint tasks!

---

## 1. Nearby Search (Show places around a point)

```dart
// Example: Search for dog-friendly places near user's location
final request = {
  'location': LatLng(-31.93, 115.86), // Perth
  'radius': 5000, // meters
  'type': 'park', // or 'restaurant', 'cafe', etc.
};
service.nearbySearch(request, (results, status, pagination) {
  if (status == PlacesServiceStatus.ok && results != null) {
    for (final place in results) {
      // Add marker for each place
      createMarker(place);
    }
    // Handle pagination if needed
    if (pagination?.hasNextPage ?? false) {
      pagination.nextPage();
    }
  }
});
```

---

## 2. Text Search (Flexible search by query)

```dart
// Example: Search for 'dog friendly cafe' within 10km
final request = {
  'location': LatLng(-31.93, 115.86),
  'radius': 10000,
  'query': 'dog friendly cafe',
};
service.textSearch(request, (results, status, pagination) {
  if (status == PlacesServiceStatus.ok && results != null) {
    for (final place in results) {
      createMarker(place);
    }
  }
});
```

---

## 3. Find Place from Query (Smart search)

```dart
// Example: Find a place by name or address
final request = {
  'query': 'Museum of Contemporary Art Australia',
  'fields': ['name', 'geometry'],
};
service.findPlaceFromQuery(request, (results, status) {
  if (status == PlacesServiceStatus.ok && results != null) {
    for (final place in results) {
      createMarker(place);
    }
    map.setCenter(results[0].geometry.location);
  }
});
```

---

## 4. Place Autocomplete (Type-ahead search)

- Use the Places Autocomplete widget for smart, AI-like search suggestions.
- See: https://developers.google.com/maps/documentation/javascript/places-autocomplete

---

## 5. Search in Area (Map bounds)

```dart
// Example: Search within current map bounds
final bounds = map.getBounds();
final request = {
  'bounds': bounds,
  'type': 'park',
};
service.nearbySearch(request, (results, status, pagination) {
  if (status == PlacesServiceStatus.ok && results != null) {
    for (final place in results) {
      createMarker(place);
    }
  }
});
```

---

## 6. Pagination (Show more results)

```dart
// Example: Handle more than 20 results
service.nearbySearch(request, (results, status, pagination) {
  if (status == PlacesServiceStatus.ok && results != null) {
    addPlaces(results);
    if (pagination?.hasNextPage ?? false) {
      // Call nextPage() to get more results
      pagination.nextPage();
    }
  }
});
```

---

## 7. Place Details (Get more info)

```dart
// Example: Get details for a selected place
final request = {
  'placeId': place.placeId,
  'fields': ['name', 'rating', 'formatted_phone_number', 'geometry'],
};
service.getDetails(request, (place, status) {
  if (status == PlacesServiceStatus.ok && place != null) {
    // Show details in UI
    showPlaceDetails(place);
  }
});
```

---

## 8. Smart Search / AI Suggestions (Nice to have)

- Use Autocomplete for smart suggestions.
- Optionally, integrate with AI APIs to recommend places or queries.
- Example: Suggest "dog friendly cafe near me" or "pet store open now".

---

## 9. UI Patterns for Sprint

- Add a radius selector (slider/dropdown)
- Add a "Search this area" button
- Show results as map markers and in a list
- Support pagination for more results
- Use Autocomplete for smart search
- Show place details on tap/click

---

## References
- [Google Maps JavaScript API Docs](https://developers.google.com/maps/documentation/javascript/places)
- [Places Autocomplete](https://developers.google.com/maps/documentation/javascript/places-autocomplete)
- [Place Search Pagination Example](https://developers.google.com/maps/documentation/javascript/examples/place-search-pagination)
- [Place Details Example](https://developers.google.com/maps/documentation/javascript/examples/place-details)

---

**Use these examples to guide your sprint tasks. Start with Nearby Search, Text Search, and Autocomplete, then add smart features as needed!**
