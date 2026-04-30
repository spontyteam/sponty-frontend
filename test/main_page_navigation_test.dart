import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sponty_frontend/main.dart';
import 'package:sponty_frontend/services/swipe_session_store.dart';

import 'fakes/fake_backend_api.dart';
import 'fakes/fake_google_maps_flutter_platform.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
  });

  setUp(() {
    SwipeSessionStore.instance.clear();
  });

  testWidgets('bottom nav switches between simple screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(backendApiOverride: FakeBackendApi()));
    await tester.pumpAndSettle();

    // Default is List (index 1); ensure app is up.
    expect(find.byType(Scaffold), findsWidgets);

    // Tap nav icons (labels use fontSize=0).
    await tester.tap(find.byType(SvgPicture).at(0));
    await tester.pumpAndSettle();
    expect(find.text('Start swiping'), findsWidgets);

    await tester.tap(find.byType(SvgPicture).at(3));
    await tester.pumpAndSettle();
    expect(find.text('DM'), findsWidgets);

    await tester.tap(find.byType(SvgPicture).at(4));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });
}
