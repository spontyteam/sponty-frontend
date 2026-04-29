import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:sponty_frontend/screens/home_screen.dart';
import 'package:sponty_frontend/services/backend_api.dart';

import '../fakes/fake_backend_api.dart';
import '../fakes/fake_google_maps_flutter_platform.dart';

void main() {
  late FakeGoogleMapsFlutterPlatform fakeMaps;

  const sydneyLat = -33.8688;
  const sydneyLng = 151.2093;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeMaps = FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakeMaps;
  });

  testWidgets('typing search shows visible count pill', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[
        pp('a', 'Golden Bistro', sydneyLat, sydneyLng),
        pp('b', 'Spicy Kitchen', sydneyLat + 0.01, sydneyLng + 0.01),
      ],
      detailsById: <String, PlaceDetails>{},
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(backendApi: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'gold');
    await tester.pumpAndSettle();

    // Count pill is rendered as text with the count.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('marker selection loads details panel', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      points: <PlacePoint>[pp('a', 'Golden Bistro', sydneyLat, sydneyLng)],
      detailsById: <String, PlaceDetails>{
        'a': pd(
          'a',
          'Golden Bistro',
          sydneyLat,
          sydneyLng,
          rating: 4.4,
          total: 123,
          address: '1 Example St, Sydney NSW 2000',
          summary: 'Nice place',
          openNow: true,
        ),
      },
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(backendApi: api)));
    await tester.pumpAndSettle();

    final mapId = fakeMaps.lastCreatedMapId;
    expect(mapId, isNotNull);

    fakeMaps.emitMarkerTap(mapId: mapId!, markerId: const MarkerId('a'));
    await tester.pump();

    // Details load is async; depending on scheduling it may resolve quickly.
    await tester.pumpAndSettle();

    // Details loaded.
    expect(find.text('Golden Bistro'), findsWidgets);
    expect(find.textContaining('Example St'), findsOneWidget);

    // Close returns to search bar.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });
}
