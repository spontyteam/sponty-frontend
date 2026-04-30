import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponty_frontend/screens/swipe_screen.dart';
import 'package:sponty_frontend/services/backend_api.dart';
import 'package:sponty_frontend/services/swipe_session_store.dart';

import '../fakes/fake_backend_api.dart';

void main() {
  setUp(() {
    SwipeSessionStore.instance.clear();
  });

  testWidgets('shows start view then loads first card', (WidgetTester tester) async {
    final api = FakeBackendApi(
      listPages: <PlacesPage>[
        PlacesPage(
          items: <PlaceListItem>[
            PlaceListItem(
              details: pd(
                'p1',
                'Place 1',
                0,
                0,
                rating: 4.2,
                total: 10,
                address: '1 Example St, Sydney NSW',
                priceLevel: 2,
              ),
              distanceMeters: 120.0,
            ),
            PlaceListItem(
              details: pd(
                'p2',
                'Place 2',
                0,
                0,
                rating: 4.6,
                total: 33,
                address: '2 Example St, Sydney NSW',
                priceLevel: 3,
              ),
              distanceMeters: 240.0,
            ),
          ],
          pagination: const PlacesPagination(
            page: 1,
            pageSize: 25,
            total: 2,
            hasNextPage: false,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: SwipeScreen(backendApi: api)));

    expect(find.text('Start swiping'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('start_swiping_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('swipe_card_p1')), findsOneWidget);
    expect(find.text('Place 1'), findsOneWidget);
  });

  testWidgets('restores swipe progress when rebuilt', (WidgetTester tester) async {
    final api = FakeBackendApi(
      listPages: <PlacesPage>[
        PlacesPage(
          items: <PlaceListItem>[
            PlaceListItem(
              details: pd('p1', 'Place 1', 0, 0, rating: 4.0),
              distanceMeters: 120.0,
            ),
            PlaceListItem(
              details: pd('p2', 'Place 2', 0, 0, rating: 4.5),
              distanceMeters: 240.0,
            ),
          ],
          pagination: const PlacesPagination(
            page: 1,
            pageSize: 25,
            total: 2,
            hasNextPage: false,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: SwipeScreen(backendApi: api)));
    await tester.tap(find.byKey(const ValueKey('start_swiping_button')));
    await tester.pumpAndSettle();

    // Swipe the first card to the right.
    await tester.drag(find.byKey(const ValueKey('swipe_card_p1')), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Rebuild the widget as if we navigated away and came back.
    await tester.pumpWidget(MaterialApp(home: SwipeScreen(backendApi: api)));
    await tester.pumpAndSettle();

    // Should show the second card.
    expect(find.byKey(const ValueKey('swipe_card_p2')), findsOneWidget);
    expect(find.text('Place 2'), findsOneWidget);
  });
}
