import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sponty_frontend/services/backend_api.dart';

void main() {
  group('MockBackendApi', () {
    test('fetchMapPlacePoints returns unmodifiable list', () async {
      final api = MockBackendApi(networkDelay: Duration.zero, totalPlaces: 5);
      var bounds = LatLngBounds(
        southwest: LatLng(-90, -180),
        northeast: LatLng(90, 180),
      );
      final points = await api.fetchMapPlacePoints(bounds: bounds);

      expect(points, hasLength(5));
      expect(points.first.osmId, startsWith('osm:'));

      expect(
        () => (points).add(
          const PlacePoint(osmId: 'x', name: 'x', location: LatLng(0, 0)),
        ),
        throwsUnsupportedError,
      );
    });

    test('fetchPlaceDetails returns matching osmId and location', () async {
      final api = MockBackendApi(networkDelay: Duration.zero, totalPlaces: 3);
      var bounds = LatLngBounds(
        southwest: LatLng(-90, -180),
        northeast: LatLng(90, 180),
      );
      final points = await api.fetchMapPlacePoints(bounds: bounds);

      final target = points[1];
      final details = await api.fetchPlaceDetails(osmId: target.osmId);

      expect(details.osmId, target.osmId);
      expect(details.name, target.name);
      expect(details.location, target.location);
    });

    test('fetchPlaceDetails throws for unknown place', () async {
      final api = MockBackendApi(networkDelay: Duration.zero, totalPlaces: 1);

      expect(
        () => api.fetchPlaceDetails(osmId: 'does-not-exist'),
        throwsA(isA<Exception>()),
      );
    });

    test('fetchListPage paginates with cursor until null', () async {
      final api = MockBackendApi(networkDelay: Duration.zero, totalPlaces: 60);

      final p1 = await api.fetchListPage(
        lat: 0,
        lon: 0,
        radiusMeters: 1000,
        page: 1,
        pageSize: 25,
      );
      expect(p1.items, hasLength(25));
      expect(p1.pagination.hasNextPage, isTrue);

      final p2 = await api.fetchListPage(
        lat: 0,
        lon: 0,
        radiusMeters: 1000,
        page: 2,
        pageSize: 25,
      );
      expect(p2.items, hasLength(25));
      expect(p2.pagination.hasNextPage, isTrue);

      final p3 = await api.fetchListPage(
        lat: 0,
        lon: 0,
        radiusMeters: 1000,
        page: 3,
        pageSize: 25,
      );
      expect(p3.items, hasLength(10));
      expect(p3.pagination.hasNextPage, isFalse);
    });
  });
}
