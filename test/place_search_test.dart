import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sponty_frontend/services/backend_api.dart';
import 'package:sponty_frontend/services/place_search.dart';

void main() {
  group('PlaceSearch.filterPlaces', () {
    test('returns expected matches for query', () {
      final places = <PlacePoint>[
        const PlacePoint(
          osmId: '1',
          name: 'Golden Bistro',
          location: LatLng(0, 0),
        ),
        const PlacePoint(
          osmId: '2',
          name: 'Spicy Kitchen',
          location: LatLng(0, 0),
        ),
        const PlacePoint(
          osmId: '3',
          name: 'Harbour Cafe',
          location: LatLng(0, 0),
        ),
      ];

      expect(PlaceSearch.filterPlaces(places, 'gold').map((p) => p.osmId), [
        '1',
      ]);
      expect(PlaceSearch.filterPlaces(places, 'Kitchen').map((p) => p.osmId), [
        '2',
      ]);
      expect(
        PlaceSearch.filterPlaces(places, 'harbour cafe').map((p) => p.osmId),
        ['3'],
      );
      expect(PlaceSearch.filterPlaces(places, 'zzzz'), isEmpty);
    });

    test('incremental query (1..4 chars) filters correctly', () {
      final places = <PlacePoint>[
        const PlacePoint(osmId: 'a', name: 'a place', location: LatLng(0, 0)),
        const PlacePoint(osmId: 'ab', name: 'ab place', location: LatLng(0, 0)),
        const PlacePoint(
          osmId: 'abc',
          name: 'abc place',
          location: LatLng(0, 0),
        ),
        const PlacePoint(
          osmId: 'abcd',
          name: 'abcd place',
          location: LatLng(0, 0),
        ),
      ];

      final q1 = PlaceSearch.filterPlaces(
        places,
        'a',
      ).map((p) => p.osmId).toList();
      final q2 = PlaceSearch.filterPlaces(
        places,
        'ab',
      ).map((p) => p.osmId).toList();
      final q3 = PlaceSearch.filterPlaces(
        places,
        'abc',
      ).map((p) => p.osmId).toList();
      final q4 = PlaceSearch.filterPlaces(
        places,
        'abcd',
      ).map((p) => p.osmId).toList();

      expect(q1, ['a', 'ab', 'abc', 'abcd']);
      expect(q2, ['ab', 'abc', 'abcd']);
      expect(q3, ['abc', 'abcd']);
      expect(q4, ['abcd']);
    });
  });

  group('PlaceSearch.buildMarkers', () {
    test('marker tap still selects after search filter', () {
      final places = <PlacePoint>[
        const PlacePoint(osmId: 'ab', name: 'ab place', location: LatLng(0, 0)),
        const PlacePoint(
          osmId: 'abc',
          name: 'abc place',
          location: LatLng(0, 0),
        ),
      ];

      String? selected;

      final markersById = PlaceSearch.buildMarkers(
        places: places,
        query: 'ab',
        selectedPlaceId: null,
        markerFactory: (place, isSelected) {
          return Marker(
            markerId: MarkerId(place.osmId),
            position: place.location,
            consumeTapEvents: true,
            onTap: () {
              selected = place.osmId;
            },
          );
        },
      );

      expect(markersById.keys.toSet(), {'ab', 'abc'});

      markersById['abc']!.onTap?.call();
      expect(selected, 'abc');
    });
  });
}
