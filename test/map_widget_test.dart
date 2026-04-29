import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:sponty_frontend/components/map_widget.dart';
import 'package:sponty_frontend/services/backend_api.dart';

import 'fakes/fake_backend_api.dart';
import 'fakes/fake_google_maps_flutter_platform.dart';

void main() {
  late FakeGoogleMapsFlutterPlatform fakeMaps;

  const sydneyLat = -33.8688;
  const sydneyLng = 151.2093;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeMaps = FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakeMaps;
  });

  testWidgets('loads places and reports visible count', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[
        pp('a', 'Golden Bistro', sydneyLat, sydneyLng),
        pp('b', 'Spicy', sydneyLat + 0.01, sydneyLng + 0.01),
      ],
    );

    int? lastCount;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapWidget(
            backendApi: api,
            onVisiblePlacesCountChanged: (count) => lastCount = count,
          ),
        ),
      ),
    );

    // Let map creation + initial fetch + postframe callback run.
    await tester.pumpAndSettle();
    await tester.pump();

    expect(api.fetchPointsCalls, 1);
    expect(lastCount, 2);
  });

  testWidgets('searchQuery filters markers and updates visible count', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[
        pp('a', 'Golden Bistro', sydneyLat, sydneyLng),
        pp('b', 'Spicy Kitchen', sydneyLat + 0.01, sydneyLng + 0.01),
      ],
    );

    int? lastCount;

    Widget wrap(String query) {
      return MaterialApp(
        home: Scaffold(
          body: MapWidget(
            backendApi: api,
            searchQuery: query,
            onVisiblePlacesCountChanged: (count) => lastCount = count,
          ),
        ),
      );
    }

    await tester.pumpWidget(wrap(''));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(lastCount, 2);

    await tester.pumpWidget(wrap('gold'));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(lastCount, 1);
  });

  testWidgets('marker tap triggers onPlaceSelected', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[pp('a', 'Golden Bistro', sydneyLat, sydneyLng)],
    );

    PlacePoint? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapWidget(
            backendApi: api,
            onPlaceSelected: (p) => selected = p,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final mapId = fakeMaps.lastCreatedMapId;
    expect(mapId, isNotNull);

    fakeMaps.emitMarkerTap(mapId: mapId!, markerId: const MarkerId('a'));
    await tester.pump();

    expect(selected?.osmId, 'a');
  });

  testWidgets('map tap after delay clears selection via onPlaceDeselected', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[pp('a', 'Golden Bistro', sydneyLat, sydneyLng)],
    );

    var deselectedCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapWidget(
            backendApi: api,
            onPlaceDeselected: () => deselectedCalls++,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final mapId = fakeMaps.lastCreatedMapId;
    expect(mapId, isNotNull);

    // Select first.
    fakeMaps.emitMarkerTap(mapId: mapId!, markerId: const MarkerId('a'));
    await tester.pump();

    // Wait real time so MapWidget no longer ignores the map tap.
    // `testWidgets` runs in fake time; `Future.delayed` won't elapse unless
    // wrapped in `runAsync`.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
    });

    fakeMaps.emitMapTap(mapId: mapId, position: const LatLng(0, 0));
    await tester.pump();

    expect(deselectedCalls, 1);
  });

  testWidgets('shows "Search this area" and fetches only on tap', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(points: const <PlacePoint>[]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapWidget(backendApi: api)),
      ),
    );

    await tester.pumpAndSettle();
    expect(api.fetchPointsCalls, 1);

    final mapId = fakeMaps.lastCreatedMapId;
    expect(mapId, isNotNull);

    // Move the viewport and go idle: no fetch should happen automatically.
    fakeMaps.setVisibleRegion(
      LatLngBounds(
        southwest: const LatLng(-33.95, 151.10),
        northeast: const LatLng(-33.75, 151.30),
      ),
    );
    fakeMaps.emitCameraIdle(mapId: mapId!);

    await tester.pumpAndSettle();
    expect(api.fetchPointsCalls, 1);
    expect(find.text('Search this area'), findsOneWidget);

    // Even if the user moves again, it still should not auto-fetch.
    fakeMaps.emitCameraMoveStarted(mapId: mapId);
    fakeMaps.setVisibleRegion(
      LatLngBounds(
        southwest: const LatLng(-34.05, 151.00),
        northeast: const LatLng(-33.85, 151.20),
      ),
    );
    fakeMaps.emitCameraIdle(mapId: mapId);
    await tester.pumpAndSettle();
    expect(api.fetchPointsCalls, 1);
    expect(find.text('Search this area'), findsOneWidget);

    // Fetch happens only when the CTA is tapped.
    await tester.tap(find.text('Search this area'));
    await tester.pumpAndSettle();
    expect(api.fetchPointsCalls, 2);
    expect(find.text('Search this area'), findsNothing);
  });
}
