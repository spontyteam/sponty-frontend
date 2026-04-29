import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'backend_api.dart';

typedef PlaceMarkerFactory = Marker Function(PlacePoint place, bool isSelected);

class PlaceSearch {
  static String normalizeQuery(String? query) => (query ?? '').trim();

  static bool matches(PlacePoint place, String query) {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return true;

    final q = normalized.toLowerCase();
    final name = place.name.toLowerCase();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final token in tokens) {
      if (!name.contains(token)) return false;
    }
    return true;
  }

  static List<PlacePoint> filterPlaces(List<PlacePoint> places, String query) {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return places;
    return places.where((p) => matches(p, normalized)).toList(growable: false);
  }

  static Map<String, Marker> buildMarkers({
    required List<PlacePoint> places,
    required String query,
    required String? selectedPlaceId,
    required PlaceMarkerFactory markerFactory,
  }) {
    final visiblePlaces = filterPlaces(places, query);
    return <String, Marker>{
      for (final p in visiblePlaces)
        p.osmId: markerFactory(
          p,
          selectedPlaceId != null && p.osmId == selectedPlaceId,
        ),
    };
  }
}
