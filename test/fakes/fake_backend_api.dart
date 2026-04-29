import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sponty_frontend/services/backend_api.dart';

class FakeBackendApi implements BackendApi {
  FakeBackendApi({
    List<PlacePoint>? points,
    Map<String, PlaceDetails>? detailsById,
    List<PlacesPage>? listPages,
    this.filterPointsByBounds = false,
  }) : _points = points ?? const <PlacePoint>[],
       _detailsById = detailsById ?? <String, PlaceDetails>{},
       _listPages = listPages ?? const <PlacesPage>[];

  final List<PlacePoint> _points;
  final Map<String, PlaceDetails> _detailsById;
  final List<PlacesPage> _listPages;

  /// When true, `fetchMapPlacePoints` will filter points by the requested
  /// bounds. Most widget tests set this to false to avoid coupling UI behavior
  /// to viewport math in the fake map implementation.
  final bool filterPointsByBounds;

  int fetchPointsCalls = 0;
  int fetchDetailsCalls = 0;
  int fetchListCalls = 0;

  Object? fetchPointsError;
  Object? fetchDetailsError;
  Object? fetchListError;

  @override
  Future<List<PlacePoint>> fetchMapPlacePoints({
    required LatLngBounds bounds,
    double? zoom,
    VisibleFilterMode? visibleFilterMode,
  }) async {
    fetchPointsCalls++;
    if (fetchPointsError != null) {
      throw fetchPointsError!;
    }

    if (!filterPointsByBounds) {
      return Future<List<PlacePoint>>.value(
        List<PlacePoint>.unmodifiable(_points),
      );
    }

    final filtered = _points.where((p) {
      final lat = p.location.latitude;
      final lon = p.location.longitude;
      final inLat =
          lat >= bounds.southwest.latitude && lat <= bounds.northeast.latitude;
      final west = bounds.southwest.longitude;
      final east = bounds.northeast.longitude;
      final inLon = west == east
          ? true
          : (west <= east
                ? (lon >= west && lon <= east)
                : (lon >= west || lon <= east));
      return inLat && inLon;
    }).toList();

    return Future<List<PlacePoint>>.value(
      List<PlacePoint>.unmodifiable(filtered),
    );
  }

  @override
  Future<PlaceDetails> fetchPlaceDetails({
    String? osmId,
    String? googlePlaceId,
  }) async {
    fetchDetailsCalls++;
    if (fetchDetailsError != null) {
      throw fetchDetailsError!;
    }
    final key = (osmId != null && osmId.isNotEmpty)
        ? osmId
        : (googlePlaceId != null && googlePlaceId.isNotEmpty)
        ? googlePlaceId
        : null;
    if (key == null) {
      throw const BackendApiException(
        code: 'INVALID_PARAMS',
        message: 'One of osmId or googlePlaceId must be provided',
      );
    }

    final details = _detailsById[key];
    if (details == null) {
      throw Exception('Place not found: $key');
    }
    return Future<PlaceDetails>.value(details);
  }

  @override
  Future<PlacesPage> fetchListPage({
    required double lat,
    required double lon,
    required int radiusMeters,
    int page = 1,
    int pageSize = 20,
    SortMode? sort,
    List<String>? cuisine,
    List<int>? priceLevels,
    bool? openNow,
    bool? takeaway,
    bool? delivery,
  }) async {
    fetchListCalls++;
    if (fetchListError != null) {
      throw fetchListError!;
    }

    final index = page - 1;
    if (index < 0 || index >= _listPages.length) {
      return Future<PlacesPage>.value(
        const PlacesPage(
          items: <PlaceListItem>[],
          pagination: PlacesPagination(
            page: 1,
            pageSize: 20,
            total: 0,
            hasNextPage: false,
          ),
        ),
      );
    }
    return Future<PlacesPage>.value(_listPages[index]);
  }
}

PlacePoint pp(String id, String name, double lat, double lng) {
  return PlacePoint(osmId: id, name: name, location: LatLng(lat, lng));
}

PlaceDetails pd(
  String id,
  String name,
  double lat,
  double lng, {
  String? imageUrl,
  double? rating,
  int? total,
  String? summary,
  String? address,
  bool? openNow,
  int? priceLevel,
  List<String> photoUrls = const <String>[],
}) {
  return PlaceDetails(
    osmId: id,
    name: name,
    location: LatLng(lat, lng),
    imageUrl: imageUrl,
    rating: rating,
    userRatingsTotal: total,
    summary: summary,
    address: address,
    phone: null,
    website: null,
    mapsUrl: null,
    openNow: openNow,
    priceLevel: priceLevel,
    photoUrls: photoUrls,
  );
}
