import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sponty_frontend/services/backend_api.dart';
import 'package:sponty_frontend/services/place_search.dart';

void main() {
  group('PlaceSearch.matches', () {
    test('empty/whitespace query matches everything', () {
      const p = PlacePoint(
        osmId: '1',
        name: 'Golden Bistro',
        location: LatLng(0, 0),
      );
      expect(PlaceSearch.matches(p, ''), isTrue);
      expect(PlaceSearch.matches(p, '   '), isTrue);
      expect(PlaceSearch.matches(p, '\n\t'), isTrue);
    });

    test('tokenized matching requires all tokens', () {
      const p = PlacePoint(
        osmId: '1',
        name: 'Golden Spicy Bistro',
        location: LatLng(0, 0),
      );

      expect(PlaceSearch.matches(p, 'gold'), isTrue);
      expect(PlaceSearch.matches(p, 'gold spicy'), isTrue);
      expect(PlaceSearch.matches(p, 'gold sushi'), isFalse);
    });

    test('matching is case-insensitive', () {
      const p = PlacePoint(
        osmId: '1',
        name: 'Harbour Cafe',
        location: LatLng(0, 0),
      );

      expect(PlaceSearch.matches(p, 'HARBOUR'), isTrue);
      expect(PlaceSearch.matches(p, 'cafe'), isTrue);
      expect(PlaceSearch.matches(p, 'HarBouR CaFe'), isTrue);
    });
  });
}
