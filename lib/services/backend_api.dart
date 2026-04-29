import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

enum VisibleFilterMode { all, openNow }

enum SortMode { distance, rating, reviewCount }

class BackendApiException implements Exception {
  const BackendApiException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'BackendApiException($code): $message';
}

class PlacePoint {
  const PlacePoint({
    required this.osmId,
    this.googlePlaceId,
    required this.name,
    required this.location,
    this.rating,
    this.priceLevel,
    this.primaryPhotoRef,
    this.openNow,
  });

  final String osmId;
  final String? googlePlaceId;
  final String name;
  final LatLng location;
  final double? rating;
  final int? priceLevel;
  final String? primaryPhotoRef;
  final bool? openNow;
}

class PlaceDetails {
  const PlaceDetails({
    required this.osmId,
    this.googlePlaceId,
    required this.name,
    required this.location,
    this.imageUrl,
    this.rating,
    this.userRatingsTotal,
    this.summary,
    this.address,
    this.phone,
    this.website,
    this.mapsUrl,
    this.openNow,
    this.priceLevel,
    this.primaryPhotoRef,
    this.openingHours,
    this.photos,
    this.reviews,
    this.photoUrls = const <String>[],
  });

  final String osmId;
  final String? googlePlaceId;
  final String name;
  final LatLng location;
  final String? imageUrl;
  final double? rating;
  final int? userRatingsTotal;
  final String? summary;
  final String? address;
  final String? phone;
  final String? website;
  final String? mapsUrl;
  final bool? openNow;
  final int? priceLevel;
  final String? primaryPhotoRef;

  /// May be an object/map depending on backend.
  final Object? openingHours;
  final List<Object?>? photos;
  final List<Object?>? reviews;
  final List<String> photoUrls;
}

class PlaceListItem {
  const PlaceListItem({
    required this.details,
    required this.distanceMeters,
    this.reviewCount,
  });

  final PlaceDetails details;
  final double distanceMeters;
  final int? reviewCount;
}

class PlacesPagination {
  const PlacesPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNextPage,
  });

  final int page;
  final int pageSize;
  final int total;
  final bool hasNextPage;
}

class PlacesPage {
  const PlacesPage({required this.items, required this.pagination});

  final List<PlaceListItem> items;
  final PlacesPagination pagination;
}

abstract class BackendApi {
  Future<List<PlacePoint>> fetchMapPlacePoints({
    required LatLngBounds bounds,
    double? zoom,
    VisibleFilterMode? visibleFilterMode,
  });

  Future<PlaceDetails> fetchPlaceDetails({
    String? osmId,
    String? googlePlaceId,
  });

  Future<PlacesPage> fetchListPage({
    required double lat,
    required double lon,
    required int radiusMeters,
    int page,
    int pageSize,
    SortMode? sort,
    List<String>? cuisine,
    List<int>? priceLevels,
    bool? openNow,
    bool? takeaway,
    bool? delivery,
  });
}

class _CacheEntry<T> {
  _CacheEntry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class HttpBackendApi implements BackendApi {
  HttpBackendApi({
    required String baseUrl,
    http.Client? client,
    Duration detailsTtl = const Duration(minutes: 5),
    Duration mapTtl = const Duration(seconds: 10),
    Duration listTtl = const Duration(seconds: 10),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _client = client ?? http.Client(),
       _detailsTtl = detailsTtl,
       _mapTtl = mapTtl,
       _listTtl = listTtl;

  final Uri _baseUri;
  final http.Client _client;
  final Duration _detailsTtl;
  final Duration _mapTtl;
  final Duration _listTtl;

  final Map<String, _CacheEntry<Object>> _cache =
      <String, _CacheEntry<Object>>{};

  // The backend's `place-details` response currently omits coordinates.
  // Cache the last-known location from map/list endpoints so details can
  // still provide a usable PlaceDetails.location.
  final Map<String, LatLng> _lastKnownLocationByOsmId = <String, LatLng>{};
  final Map<String, LatLng> _lastKnownLocationByGooglePlaceId =
      <String, LatLng>{};

  void _rememberLocation({
    required String osmId,
    String? googlePlaceId,
    required LatLng location,
  }) {
    if (osmId.isNotEmpty) {
      _lastKnownLocationByOsmId[osmId] = location;
    }
    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      _lastKnownLocationByGooglePlaceId[googlePlaceId] = location;
    }
  }

  static String? _stringOrNull(Object? v) => v is String ? v : null;
  static int? _intOrNull(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : null);
  static double? _doubleOrNull(Object? v) =>
      v is double ? v : (v is num ? v.toDouble() : null);
  static bool? _boolOrNull(Object? v) => v is bool ? v : null;

  static Map<String, Object?> _asMap(Object? v) {
    if (v is Map) {
      return v.map((k, v) => MapEntry(k.toString(), v));
    }
    throw const BackendApiException(
      code: 'INVALID_RESPONSE',
      message: 'Expected JSON object',
    );
  }

  static List<Object?> _asList(Object? v) {
    if (v is List) return v.cast<Object?>();
    throw const BackendApiException(
      code: 'INVALID_RESPONSE',
      message: 'Expected JSON array',
    );
  }

  BackendApiException _parseError(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      final map = _asMap(body);

      // Common patterns we handle:
      // - { error: { code, message } }
      // - { error: "message" }
      // - { message: "...", error: "Not Found", statusCode: 404 }
      final err = map['error'];
      if (err is Map) {
        final errMap = _asMap(err);
        return BackendApiException(
          code: _stringOrNull(errMap['code']) ?? 'HTTP_${r.statusCode}',
          message:
              _stringOrNull(errMap['message']) ??
              r.reasonPhrase ??
              'Request failed',
        );
      }
      final errString = _stringOrNull(err);
      final msgString = _stringOrNull(map['message']);
      return BackendApiException(
        code: 'HTTP_${r.statusCode}',
        message: errString ?? msgString ?? r.reasonPhrase ?? 'Request failed',
      );
    } catch (_) {
      return BackendApiException(
        code: 'HTTP_${r.statusCode}',
        message: r.reasonPhrase ?? 'Request failed',
      );
    }
  }

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    final uri = _baseUri.resolve(cleaned);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Uri _endpointAll(String path, Map<String, List<String>> queryAll) {
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    final uri = _baseUri.resolve(cleaned);
    final parts = <String>[];
    for (final entry in queryAll.entries) {
      final key = Uri.encodeQueryComponent(entry.key);
      for (final v in entry.value) {
        parts.add('$key=${Uri.encodeQueryComponent(v)}');
      }
    }
    final query = parts.join('&');
    return uri.replace(query: query);
  }

  T? _getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void _setCached<T>(String key, T value, Duration ttl) {
    _cache[key] = _CacheEntry<Object>(value as Object, DateTime.now().add(ttl));
  }

  @override
  Future<List<PlacePoint>> fetchMapPlacePoints({
    required LatLngBounds bounds,
    double? zoom,
    VisibleFilterMode? visibleFilterMode,
  }) async {
    // Round bounds to match the frontend's viewport equality logic (see MapWidget
    // bounds comparison), reducing cache misses caused by tiny float diffs.
    String r3(double v) => v.toStringAsFixed(3);

    final north = r3(bounds.northeast.latitude);
    final south = r3(bounds.southwest.latitude);
    final east = r3(bounds.northeast.longitude);
    final west = r3(bounds.southwest.longitude);

    final visibleFilterModeValue = visibleFilterMode == null
        ? null
        : switch (visibleFilterMode) {
            VisibleFilterMode.all => 'all',
            VisibleFilterMode.openNow => 'open_now',
          };

    final query = <String, String>{
      'north': north,
      'south': south,
      'east': east,
      'west': west,
    };
    if (zoom != null) query['zoom'] = zoom.toString();
    if (visibleFilterModeValue != null) {
      query['visibleFilterMode'] = visibleFilterModeValue;
    }

    // Keep the cache key stable across zoom changes; the backend cache ignores
    // zoom and bounds rounding already reduces noisy key churn.
    final cacheKeyParts = <String>[
      'north=$north',
      'south=$south',
      'east=$east',
      'west=$west',
      if (visibleFilterModeValue != null)
        'visibleFilterMode=$visibleFilterModeValue',
    ];
    final cacheKey = 'map:${cacheKeyParts.join('&')}';

    final cached = _getCached<List<PlacePoint>>(cacheKey);
    if (cached != null) return cached;

    final r = await _client.get(_endpoint('places/map', query));
    if (r.statusCode < 200 || r.statusCode >= 300) throw _parseError(r);

    final body = jsonDecode(r.body);
    final map = _asMap(body);
    final markers = _asList(map['items']);
    final points = <PlacePoint>[];
    for (final raw in markers) {
      final m = _asMap(raw);
      final osmId = _stringOrNull(m['osm_id']);
      final lat = _doubleOrNull(m['lat']);
      final lon = _doubleOrNull(m['lon']);
      if (osmId == null || lat == null || lon == null) {
        // Skip invalid rows.
        continue;
      }
      final name = _stringOrNull(m['name']) ?? 'Unknown';
      points.add(
        PlacePoint(
          osmId: osmId,
          googlePlaceId: _stringOrNull(m['google_place_id']),
          name: name,
          location: LatLng(lat, lon),
          rating: _doubleOrNull(m['rating']),
          priceLevel: _intOrNull(m['price_level']),
          primaryPhotoRef: _stringOrNull(m['primary_photo_ref']),
          openNow: _boolOrNull(m['open_now']),
        ),
      );
      _rememberLocation(
        osmId: osmId,
        googlePlaceId: _stringOrNull(m['google_place_id']),
        location: LatLng(lat, lon),
      );
    }

    final unmodifiable = List<PlacePoint>.unmodifiable(points);
    _setCached(cacheKey, unmodifiable, _mapTtl);
    return unmodifiable;
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
    // Spec: most params are single values; cuisine/priceLevels are comma-separated.
    final query = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radiusMeters.toString(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (sort != null) {
      query['sort'] = switch (sort) {
        SortMode.distance => 'distance',
        SortMode.rating => 'rating',
        SortMode.reviewCount => 'review_count',
      };
    }
    if (cuisine != null && cuisine.isNotEmpty) {
      query['cuisine'] = cuisine.join(',');
    }
    if (priceLevels != null && priceLevels.isNotEmpty) {
      query['priceLevels'] = priceLevels.map((p) => p.toString()).join(',');
    }
    if (openNow != null) query['openNow'] = openNow.toString();
    if (takeaway != null) query['takeaway'] = takeaway.toString();
    if (delivery != null) query['delivery'] = delivery.toString();

    final cacheKey =
        'list:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final cached = _getCached<PlacesPage>(cacheKey);
    if (cached != null) return cached;

    final r = await _client.get(_endpoint('places', query));
    if (r.statusCode < 200 || r.statusCode >= 300) throw _parseError(r);

    final body = jsonDecode(r.body);
    final map = _asMap(body);
    final rawItems = _asList(map['items']);

    final items = <PlaceListItem>[];
    for (final raw in rawItems) {
      final m = _asMap(raw);
      final osmId = _stringOrNull(m['osm_id']);
      final lat = _doubleOrNull(m['lat']);
      final lon = _doubleOrNull(m['lon']);
      final distance = _doubleOrNull(m['distance_meters']);
      if (osmId == null || lat == null || lon == null || distance == null) {
        continue;
      }
      final name = _stringOrNull(m['name']) ?? 'Unknown';
        final imageUrlRelRaw = _stringOrNull(m['image_url']);
        final imageUrlRel = (imageUrlRelRaw == null || imageUrlRelRaw.trim().isEmpty)
          ? null
          : imageUrlRelRaw.trim();
        final imageUrlAbs = _baseUri
          .resolve(imageUrlRel ?? '/assets/place-placeholder.svg')
          .toString();
      final addressShort =
          _stringOrNull(m['address_short']) ?? _stringOrNull(m['suburb']);
      final details = PlaceDetails(
        osmId: osmId,
        googlePlaceId: _stringOrNull(m['google_place_id']),
        name: name,
        location: LatLng(lat, lon),
        imageUrl: imageUrlAbs,
        rating: _doubleOrNull(m['rating']),
        userRatingsTotal: _intOrNull(m['review_count']),
        priceLevel: _intOrNull(m['price_level']),
        primaryPhotoRef: _stringOrNull(m['primary_photo_ref']),
        openNow: _boolOrNull(m['open_now']),
        summary: _stringOrNull(m['summary']),
        address: addressShort,
        phone: null,
        website: null,
        mapsUrl: null,
        openingHours: null,
        photos: null,
        reviews: null,
        photoUrls: const <String>[],
      );
      _rememberLocation(
        osmId: osmId,
        googlePlaceId: _stringOrNull(m['google_place_id']),
        location: LatLng(lat, lon),
      );
      items.add(
        PlaceListItem(
          details: details,
          distanceMeters: distance,
          reviewCount: _intOrNull(m['review_count']),
        ),
      );
    }

    final hasMore = _boolOrNull(map['hasMore']) ?? false;

    final pagination = PlacesPagination(
      page: _intOrNull(map['page']) ?? page,
      pageSize: _intOrNull(map['pageSize']) ?? pageSize,
      total: _intOrNull(map['totalCount']) ?? items.length,
      hasNextPage: hasMore,
    );

    final pageResult = PlacesPage(
      items: List<PlaceListItem>.unmodifiable(items),
      pagination: pagination,
    );
    _setCached(cacheKey, pageResult, _listTtl);
    return pageResult;
  }

  @override
  Future<PlaceDetails> fetchPlaceDetails({
    String? osmId,
    String? googlePlaceId,
  }) async {
    if ((osmId == null || osmId.isEmpty) &&
        (googlePlaceId == null || googlePlaceId.isEmpty)) {
      throw const BackendApiException(
        code: 'INVALID_PARAMS',
        message: 'One of osmId or googlePlaceId must be provided',
      );
    }

    final query = <String, String>{};
    if (osmId != null && osmId.isNotEmpty) query['osm_id'] = osmId;
    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      query['google_place_id'] = googlePlaceId;
    }

    final cacheKey =
        'details:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final cached = _getCached<PlaceDetails>(cacheKey);
    if (cached != null) return cached;

    final r = await _client.get(_endpoint('place-details', query));
    if (r.statusCode < 200 || r.statusCode >= 300) throw _parseError(r);

    final body = jsonDecode(r.body);
    final m = _asMap(body);

    final resolvedOsmId = _stringOrNull(m['osm_id']) ?? osmId ?? '';
    final lat = _doubleOrNull(m['lat']);
    final lon = _doubleOrNull(m['lon']);
    final googleIdFromResponse = _stringOrNull(m['google_place_id']);

    LatLng? location;
    if (lat != null && lon != null) {
      location = LatLng(lat, lon);
    } else {
      if (resolvedOsmId.isNotEmpty) {
        location = _lastKnownLocationByOsmId[resolvedOsmId];
      }
      location ??= (googleIdFromResponse != null)
          ? _lastKnownLocationByGooglePlaceId[googleIdFromResponse]
          : null;
      location ??= (googlePlaceId != null && googlePlaceId.isNotEmpty)
          ? _lastKnownLocationByGooglePlaceId[googlePlaceId]
          : null;
    }

    if (resolvedOsmId.isEmpty || location == null) {
      throw const BackendApiException(
        code: 'INVALID_RESPONSE',
        message: 'Missing required place fields',
      );
    }

    final details = PlaceDetails(
      osmId: resolvedOsmId,
      googlePlaceId: googleIdFromResponse,
      name: _stringOrNull(m['name']) ?? 'Unknown',
      location: location,
      rating: _doubleOrNull(m['rating']),
      userRatingsTotal: _intOrNull(m['review_count']),
      priceLevel: _intOrNull(m['price_level']),
      primaryPhotoRef: _stringOrNull(m['primary_photo_ref']),
      openNow: _boolOrNull(m['open_now']),
      address: _stringOrNull(m['address']),
      phone: _stringOrNull(m['phone']),
      website: _stringOrNull(m['website']),
      openingHours: m['opening_hours'],
      photos: (m['photos'] is List) ? _asList(m['photos']) : null,
      reviews: (m['reviews'] is List) ? _asList(m['reviews']) : null,
      // Keep URL-based photos as an app concern for now.
      photoUrls: const <String>[],
      summary: null,
      mapsUrl: null,
    );

    _rememberLocation(
      osmId: resolvedOsmId,
      googlePlaceId: googleIdFromResponse,
      location: location,
    );

    _setCached(cacheKey, details, _detailsTtl);
    return details;
  }
}

/// Mock backend that simulates a Sydney-wide dataset.
///
/// - Map endpoint returns only points (id, x/y, name)
/// - Details endpoint returns all fields for a single id
/// - List endpoint returns paginated items (25 at a time)
class MockBackendApi implements BackendApi {
  MockBackendApi({
    this.networkDelay = const Duration(milliseconds: 220),
    int seed = 42,
    int totalPlaces = 400,
  }) : _random = math.Random(seed),
       _totalPlaces = totalPlaces {
    _initData();
  }

  final Duration networkDelay;
  final math.Random _random;
  final int _totalPlaces;

  final List<PlacePoint> _points = <PlacePoint>[];
  final Map<String, PlaceDetails> _detailsById = <String, PlaceDetails>{};

  void _initData() {
    // Rough Sydney center.
    const centerLat = -33.8688;
    const centerLng = 151.2093;

    for (var i = 0; i < _totalPlaces; i++) {
      // Spread across ~25km radius-ish.
      final dLat = (_random.nextDouble() - 0.5) * 0.35;
      final dLng = (_random.nextDouble() - 0.5) * 0.45;

      final lat = centerLat + dLat;
      final lng = centerLng + dLng;

      final id = 'osm:${100000 + i}';
      final name = _mockName(i);
      final loc = LatLng(lat, lng);

      _points.add(PlacePoint(osmId: id, name: name, location: loc));
      _detailsById[id] = _mockDetails(id: id, name: name, location: loc);
    }
  }

  String _mockName(int i) {
    const adjectives = <String>[
      'Golden',
      'Spicy',
      'Harbour',
      'Lucky',
      'Coastal',
      'Urban',
      'Green',
      'Midnight',
      'Sunny',
      'Little',
    ];
    const nouns = <String>[
      'Bistro',
      'Kitchen',
      'Diner',
      'Noodles',
      'Cafe',
      'Bar',
      'Grill',
      'Ramen',
      'Pizza',
      'Bakery',
    ];

    final a = adjectives[i % adjectives.length];
    final n = nouns[(i ~/ 3) % nouns.length];
    return '$a $n';
  }

  PlaceDetails _mockDetails({
    required String id,
    required String name,
    required LatLng location,
  }) {
    final rating = (3.2 + _random.nextDouble() * 1.7).clamp(1.0, 5.0);
    final ratingsTotal = 10 + _random.nextInt(2500);
    final priceLevel = _random.nextInt(5); // 0-4
    final openNow = _random.nextBool();

    // Keep these as simple strings for now.
    final address =
        '${(1 + _random.nextInt(200))} Example St, Sydney NSW ${2000 + _random.nextInt(200)}';

    return PlaceDetails(
      osmId: id,
      name: name,
      location: location,
      rating: double.parse(rating.toStringAsFixed(1)),
      userRatingsTotal: ratingsTotal,
      summary: 'Mocked venue details from backend.',
      address: address,
      phone: '+61 2 0000 0000',
      website: 'https://example.com',
      mapsUrl:
          'https://maps.google.com/?q=${location.latitude},${location.longitude}',
      openNow: openNow,
      priceLevel: priceLevel,
      photoUrls: const <String>[],
    );
  }

  @override
  Future<List<PlacePoint>> fetchMapPlacePoints({
    required LatLngBounds bounds,
    double? zoom,
    VisibleFilterMode? visibleFilterMode,
  }) async {
    await Future<void>.delayed(networkDelay);
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
    return List<PlacePoint>.unmodifiable(filtered);
  }

  @override
  Future<PlaceDetails> fetchPlaceDetails({
    String? osmId,
    String? googlePlaceId,
  }) async {
    await Future<void>.delayed(networkDelay);
    final id = osmId;
    if (id == null || id.isEmpty) {
      throw const BackendApiException(
        code: 'INVALID_PARAMS',
        message: 'osmId is required for MockBackendApi',
      );
    }
    final details = _detailsById[id];
    if (details == null) {
      throw Exception('Place not found: $osmId');
    }
    return details;
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
    await Future<void>.delayed(networkDelay);

    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 20 : pageSize;
    final offset = (safePage - 1) * safePageSize;
    final endExclusive = math.min(offset + safePageSize, _points.length);

    final items = <PlaceListItem>[];
    for (var i = offset; i < endExclusive; i++) {
      final p = _points[i];
      final d = _detailsById[p.osmId]!;

      // Mock a "distance" field so the UI can render something.
      final distanceMeters = 150 + _random.nextInt(1500);
      items.add(
        PlaceListItem(
          details: d,
          distanceMeters: distanceMeters.toDouble(),
          reviewCount: d.userRatingsTotal,
        ),
      );
    }

    final pagination = PlacesPagination(
      page: safePage,
      pageSize: safePageSize,
      total: _points.length,
      hasNextPage: endExclusive < _points.length,
    );
    return PlacesPage(
      items: List<PlaceListItem>.unmodifiable(items),
      pagination: pagination,
    );
  }
}
