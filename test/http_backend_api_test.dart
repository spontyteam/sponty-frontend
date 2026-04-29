import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponty_frontend/services/backend_api.dart';

void main() {
  group('HttpBackendApi', () {
    test('fetchMapPlacePoints calls /places/map with bounds params', () async {
      late Uri requested;

      final client = MockClient((req) async {
        requested = req.url;
        return http.Response(
          jsonEncode({
            'count': 1,
            'cachedAt': '2026-04-11T00:00:00.000Z',
            'items': [
              {
                'osm_id': 'node/1',
                'google_place_id': null,
                'name': 'Test Place',
                'lat': 1.0,
                'lon': 2.0,
                'rating': 4.2,
                'price_level': 2,
                'primary_photo_ref': null,
                'open_now': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = HttpBackendApi(
        baseUrl: 'https://example.com',
        client: client,
      );

      final bounds = LatLngBounds(
        southwest: LatLng(-10, -20),
        northeast: LatLng(10, 20),
      );

      final points = await api.fetchMapPlacePoints(bounds: bounds, zoom: 12);
      expect(points, hasLength(1));
      expect(points.single.osmId, 'node/1');
      expect(points.single.name, 'Test Place');
      expect(points.single.location, const LatLng(1.0, 2.0));

      expect(requested.path, '/places/map');
      expect(requested.queryParameters['north'], '10.000');
      expect(requested.queryParameters['south'], '-10.000');
      expect(requested.queryParameters['east'], '20.000');
      expect(requested.queryParameters['west'], '-20.000');
      expect(requested.queryParameters['zoom'], '12.0');
    });

    test('fetchListPage parses pagination and items', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/places');
        expect(req.url.queryParameters['lat'], isNotNull);
        expect(req.url.queryParameters['lon'], isNotNull);
        expect(req.url.queryParameters['radius'], isNotNull);

        return http.Response(
          jsonEncode({
            'items': [
              {
                'osm_id': 'node/1',
                'google_place_id': 'g1',
                'name': null,
                'lat': 1.0,
                'lon': 2.0,
                'rating': null,
                'review_count': 11,
                'price_level': 1,
                'primary_photo_ref': null,
                'open_now': null,
                'distance_meters': 123.0,
                'address': '1 Example St',
              },
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 1,
            'hasMore': false,
            'cachedAt': '2026-04-11T00:00:00.000Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = HttpBackendApi(
        baseUrl: 'https://example.com',
        client: client,
      );
      final page = await api.fetchListPage(
        lat: 0,
        lon: 0,
        radiusMeters: 1000,
        page: 1,
        pageSize: 20,
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.details.name, 'Unknown');
      expect(page.items.single.distanceMeters, 123.0);
      expect(page.pagination.hasNextPage, isFalse);
    });

    test(
      'fetchPlaceDetails throws BackendApiException on error response',
      () async {
        final client = MockClient((req) async {
          return http.Response(
            jsonEncode({'error': 'bad input'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        });

        final api = HttpBackendApi(
          baseUrl: 'https://example.com',
          client: client,
        );

        expect(
          () => api.fetchPlaceDetails(osmId: 'osm:1'),
          throwsA(
            isA<BackendApiException>()
                .having((e) => e.code, 'code', 'HTTP_400')
                .having((e) => e.message, 'message', 'bad input'),
          ),
        );
      },
    );

    test('fetchPlaceDetails requires one identifier', () async {
      final api = HttpBackendApi(
        baseUrl: 'https://example.com',
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      expect(
        () => api.fetchPlaceDetails(),
        throwsA(
          isA<BackendApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_PARAMS',
          ),
        ),
      );
    });

    test(
      'fetchPlaceDetails falls back to cached location when lat/lon missing',
      () async {
        final client = MockClient((req) async {
          if (req.url.path == '/places/map') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'osm_id': 'node/1',
                    'google_place_id': 'g1',
                    'name': 'Test Place',
                    'lat': 1.0,
                    'lon': 2.0,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (req.url.path == '/place-details') {
            // Real backend omits lat/lon here.
            return http.Response(
              jsonEncode({
                'osm_id': 'node/1',
                'google_place_id': 'g1',
                'name': 'Test Place',
                'rating': 4.9,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('{}', 404);
        });

        final api = HttpBackendApi(
          baseUrl: 'https://example.com',
          client: client,
        );

        // Prime last-known location cache.
        await api.fetchMapPlacePoints(
          bounds: LatLngBounds(
            southwest: LatLng(0, 0),
            northeast: LatLng(1, 1),
          ),
        );

        final details = await api.fetchPlaceDetails(osmId: 'node/1');
        expect(details.osmId, 'node/1');
        expect(details.location, const LatLng(1.0, 2.0));
      },
    );
  });
}
