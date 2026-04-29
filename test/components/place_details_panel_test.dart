import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sponty_frontend/components/place_details_panel.dart';
import 'package:sponty_frontend/services/backend_api.dart';

void main() {
  testWidgets('shows loading spinner when isLoading=true', (
    WidgetTester tester,
  ) async {
    const summary = PlacePoint(
      osmId: '1',
      name: 'Golden Bistro',
      location: LatLng(0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsPanel(
            summary: summary,
            details: null,
            isLoading: true,
            error: null,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when error is provided', (
    WidgetTester tester,
  ) async {
    const summary = PlacePoint(
      osmId: '1',
      name: 'Golden Bistro',
      location: LatLng(0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsPanel(
            summary: summary,
            details: null,
            isLoading: false,
            error: 'boom',
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('prefers details.name as title when present', (
    WidgetTester tester,
  ) async {
    const summary = PlacePoint(
      osmId: '1',
      name: 'Summary Name',
      location: LatLng(0, 0),
    );

    final details = PlaceDetails(
      osmId: '1',
      name: 'Details Name',
      location: const LatLng(0, 0),
      imageUrl: null,
      rating: 4.2,
      userRatingsTotal: 10,
      summary: 'Summary',
      address: '1 Example St, Sydney',
      phone: null,
      website: null,
      mapsUrl: null,
      openNow: true,
      priceLevel: 2,
      photoUrls: const <String>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsPanel(
            summary: summary,
            details: details,
            isLoading: false,
            error: null,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Details Name'), findsOneWidget);
    expect(find.text('Summary Name'), findsNothing);
  });

  testWidgets('close button triggers onClose', (WidgetTester tester) async {
    var closed = false;
    const summary = PlacePoint(
      osmId: '1',
      name: 'Golden Bistro',
      location: LatLng(0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsPanel(
            summary: summary,
            details: null,
            isLoading: false,
            error: null,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closed, isTrue);
  });
}
