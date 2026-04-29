import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponty_frontend/screens/list_screen.dart';
import 'package:sponty_frontend/services/backend_api.dart';

import '../fakes/fake_backend_api.dart';

void main() {
  testWidgets('shows skeletons then renders first page', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(
      listPages: <PlacesPage>[
        PlacesPage(
          items: <PlaceListItem>[
            PlaceListItem(
              details: pd(
                'p1',
                'Golden Bistro',
                0,
                0,
                rating: 4.3,
                total: 10,
                address: '1 Example St, Sydney NSW 2000',
                priceLevel: 2,
              ),
              distanceMeters: 120.0,
            ),
          ],
          pagination: const PlacesPagination(
            page: 1,
            pageSize: 25,
            total: 1,
            hasNextPage: false,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: ListScreen(backendApi: api)));

    // Initial frame is loading state.
    expect(find.byKey(const ValueKey('list_screen_vertical_list')), findsOne);

    // Allow async load to complete.
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    expect(find.text('Golden Bistro'), findsOneWidget);
  });

  testWidgets('shows error state when backend throws', (
    WidgetTester tester,
  ) async {
    final api = FakeBackendApi(listPages: const <PlacesPage>[])
      ..fetchListError = Exception('nope');

    await tester.pumpWidget(MaterialApp(home: ListScreen(backendApi: api)));

    await tester.pumpAndSettle();

    expect(find.textContaining('nope'), findsOneWidget);
  });

  testWidgets('scrolling near bottom loads next page', (
    WidgetTester tester,
  ) async {
    final page1Items = List<PlaceListItem>.generate(100, (i) {
      final id = 'p$i';
      return PlaceListItem(
        details: pd(
          id,
          'Place $i',
          0,
          0,
          rating: 4.0,
          total: 10,
          address: '1 Example St, Sydney NSW 2000',
          priceLevel: 1,
        ),
        distanceMeters: 120.0,
      );
    });

    final page2Items = List<PlaceListItem>.generate(10, (i) {
      final id = 'n$i';
      return PlaceListItem(
        details: pd(
          id,
          'Next $i',
          0,
          0,
          rating: 4.1,
          total: 11,
          address: '2 Example St, Sydney NSW 2000',
          priceLevel: 2,
        ),
        distanceMeters: 220.0,
      );
    });

    final api = FakeBackendApi(
      listPages: <PlacesPage>[
        PlacesPage(
          items: page1Items,
          pagination: const PlacesPagination(
            page: 1,
            pageSize: 25,
            total: 110,
            hasNextPage: true,
          ),
        ),
        PlacesPage(
          items: page2Items,
          pagination: const PlacesPagination(
            page: 2,
            pageSize: 25,
            total: 110,
            hasNextPage: false,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: ListScreen(backendApi: api)));
    await tester.pumpAndSettle();

    expect(api.fetchListCalls, 1);
    expect(find.byKey(const ValueKey('p0')), findsOneWidget);

    // Deterministically scroll to the end; ListScreen loads the next page
    // when we get close to the bottom.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('p99')),
      500,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();

    expect(api.fetchListCalls, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('n0')), findsOneWidget);
  });
}
