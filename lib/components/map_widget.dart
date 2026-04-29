import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/backend_api.dart';
import '../services/app_log.dart';
import '../services/place_search.dart';
import '../theme/colors.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    required this.backendApi,
    this.selectedPlaceId,
    this.searchQuery,
    this.onVisiblePlacesCountChanged,
    this.onPlaceSelected,
    this.onPlaceDeselected,
    this.onPlacesError,
  });

  final BackendApi backendApi;
  final String? selectedPlaceId;
  final String? searchQuery;
  final ValueChanged<int>? onVisiblePlacesCountChanged;
  final ValueChanged<PlacePoint>? onPlaceSelected;
  final VoidCallback? onPlaceDeselected;
  final ValueChanged<String>? onPlacesError;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;
  String? _mapStyle;
  double _currentZoom = _zoomThreshold;
  bool _isAnimating = false;
  bool _initialLoadStarted = false;
  bool _isLoadingPlaces = false;
  List<PlacePoint> _places = const <PlacePoint>[];
  String? _selectedPlaceId;
  Set<Marker> _lastBuiltMarkers = const <Marker>{};

  LatLngBounds? _lastViewportBounds;

  // Hard cap on total rendered map points (dots + pins).
  // Keep this high enough so zoomed-in views (<=20) still show all as pins.
  static const int _maxPlacesRenderedOnMap = 250;

  static const int _maxAnimatedTransitionsPerRebuild = 40;
  static const Duration _transitionStepDuration = Duration(milliseconds: 70);

  final Map<String, int> _transitionTokenByOsmId = <String, int>{};
  final Map<String, int> _dotTransitionStepByOsmId = <String, int>{};
  final Map<String, List<Timer>> _dotTransitionTimersByOsmId =
      <String, List<Timer>>{};
  Set<String> _lastPinnedOsmIds = const <String>{};

  BitmapDescriptor? _dotIconNormal;
  BitmapDescriptor? _dotIconPop;
  BitmapDescriptor? _dotIconSmall;

  bool _showSearchThisArea = false;
  LatLngBounds? _pendingBounds;
  LatLngBounds? _lastFetchedBounds;
  bool _suppressNextIdleFetch = false;

  int? _lastNotifiedVisibleCount;
  DateTime _lastMarkerTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _ignoreMapTapAfterMarkerMs = 1200;

  DateTime _lastMoveLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastViewportLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastLoggedZoom = -1;

  static const bool _enableMapDebugLogs = bool.fromEnvironment(
    'SPONTY_MAP_LOGS',
    defaultValue: false,
  );
  bool get _mapDebugLogsEnabled =>
      kDebugMode && _enableMapDebugLogs && AppLog.enabled;

  static const LatLng _initialTarget = LatLng(-33.8688, 151.2093);
  static const double _zoomThreshold = 15.5;
  static const double _singleResultZoom = 17.0;

  static final BitmapDescriptor _defaultMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(
        HSVColor.fromColor(AppColors.pinMain).hue,
      );
  static final BitmapDescriptor _selectedMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  final CameraPosition _initialPosition = CameraPosition(
    target: _initialTarget,
    zoom: _zoomThreshold,
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    unawaited(_loadDotMarkerIcon());
  }

  Future<void> _loadDotMarkerIcon() async {
    try {
      final normal = await _buildDotIcon(
        fill: AppColors.pinMain,
        border: AppColors.neutralLightLightest,
        scale: 1.0,
      );
      final pop = await _buildDotIcon(
        fill: AppColors.pinMain,
        border: AppColors.neutralLightLightest,
        scale: 1.35,
      );
      final small = await _buildDotIcon(
        fill: AppColors.pinMain,
        border: AppColors.neutralLightLightest,
        scale: 0.9,
      );
      if (!mounted) return;
      setState(() {
        _dotIconNormal = normal;
        _dotIconPop = pop;
        _dotIconSmall = small;
      });
    } catch (_) {
      // Optional enhancement; ignore failures.
    }
  }

  static Future<BitmapDescriptor> _buildDotIcon({
    required Color fill,
    required Color border,
    required double scale,
  }) async {
    final int size = (24 * scale).round().clamp(18, 40);
    final double radius = (7.0 * scale).clamp(5.0, 14.0);
    final double borderWidth = (2.0 * scale).clamp(1.0, 4.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2.0, size / 2.0);

    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius + borderWidth, borderPaint);
    canvas.drawCircle(center, radius, fillPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Failed to encode dot marker icon');
    }
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  static int _stableHash(String value) {
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static int _targetPinCount(int totalVisiblePlaces) {
    if (totalVisiblePlaces <= 20) return totalVisiblePlaces;
    if (totalVisiblePlaces <= 100) return 30;

    // “Only 15%” => floor.
    final computed = (totalVisiblePlaces * 0.15).floor();
    if (computed < 1) return 1;
    if (computed > totalVisiblePlaces) return totalVisiblePlaces;
    return computed;
  }

  static Set<String> _computePinnedOsmIds({
    required List<PlacePoint> visiblePlaces,
    required String? selectedId,
  }) {
    final total = visiblePlaces.length;
    if (total == 0) return <String>{};

    final requested = _targetPinCount(total);
    final pinBudget = requested > total ? total : requested;

    final pinned = <String>{};
    final hasSelected =
        selectedId != null && visiblePlaces.any((p) => p.osmId == selectedId);
    if (hasSelected) {
      pinned.add(selectedId);
    }

    final remainingBudget = pinBudget - pinned.length;
    if (remainingBudget <= 0) return pinned;

    final candidates =
        visiblePlaces
            .where((p) => p.osmId != selectedId)
            .map((p) => (id: p.osmId, rank: _stableHash(p.osmId)))
            .toList()
          ..sort((a, b) {
            final byRank = a.rank.compareTo(b.rank);
            if (byRank != 0) return byRank;
            return a.id.compareTo(b.id);
          });

    for (var i = 0; i < candidates.length && pinned.length < pinBudget; i++) {
      pinned.add(candidates[i].id);
    }

    return pinned;
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedChanged = oldWidget.selectedPlaceId != widget.selectedPlaceId;
    if (selectedChanged) {
      _selectedPlaceId = widget.selectedPlaceId;
    }

    final queryChanged = oldWidget.searchQuery != widget.searchQuery;
    if (queryChanged) {
      unawaited(_maybeZoomToSingleResult());
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map_style.json');
      if (!mounted) return;
      setState(() {
        _mapStyle = style;
      });
      final controller = _controller;
      if (controller != null) {
        try {
          // ignore: deprecated_member_use
          await controller.setMapStyle(style);
        } catch (_) {
          // Ignore if platform doesn't support applying style here.
        }
      }
    } catch (_) {
      // Style is optional; ignore failures.
    }
  }

  @override
  void dispose() {
    for (final timers in _dotTransitionTimersByOsmId.values) {
      for (final t in timers) {
        t.cancel();
      }
    }
    _dotTransitionTimersByOsmId.clear();
    _controller?.dispose();
    super.dispose();
  }

  String? get _effectiveSelectedPlaceId =>
      widget.selectedPlaceId ?? _selectedPlaceId;

  static List<PlacePoint> _limitPlacesForMap({
    required List<PlacePoint> places,
    required String? selectedId,
  }) {
    if (places.length <= _maxPlacesRenderedOnMap) return places;

    final selected = selectedId == null
        ? null
        : places.where((p) => p.osmId == selectedId);
    final selectedPlace = selected != null && selected.isNotEmpty
        ? selected.first
        : null;

    final candidates =
        places
            .where(
              (p) => selectedPlace == null || p.osmId != selectedPlace.osmId,
            )
            .map((p) => (p: p, rank: _stableHash(p.osmId)))
            .toList()
          ..sort((a, b) {
            final byRank = a.rank.compareTo(b.rank);
            if (byRank != 0) return byRank;
            return a.p.osmId.compareTo(b.p.osmId);
          });

    final out = <PlacePoint>[];
    if (selectedPlace != null) out.add(selectedPlace);
    for (
      var i = 0;
      i < candidates.length && out.length < _maxPlacesRenderedOnMap;
      i++
    ) {
      out.add(candidates[i].p);
    }
    return out;
  }

  void _startDotTransition(String osmId) {
    final next = (_transitionTokenByOsmId[osmId] ?? 0) + 1;
    _transitionTokenByOsmId[osmId] = next;
    final token = next;

    final existingTimers = _dotTransitionTimersByOsmId.remove(osmId);
    if (existingTimers != null) {
      for (final t in existingTimers) {
        t.cancel();
      }
    }

    void setStep(int step) {
      if (!mounted) return;
      if (_transitionTokenByOsmId[osmId] != token) return;
      setState(() {
        _dotTransitionStepByOsmId[osmId] = step;
      });
    }

    void clearStep() {
      if (!mounted) return;
      if (_transitionTokenByOsmId[osmId] != token) return;
      setState(() {
        _dotTransitionStepByOsmId.remove(osmId);
      });
    }

    setStep(1);

    final timers = <Timer>[
      Timer(_transitionStepDuration, () => setStep(2)),
      Timer(_transitionStepDuration * 2, clearStep),
    ];
    _dotTransitionTimersByOsmId[osmId] = timers;
  }

  void _maybeAnimateDotPinTransitions(Set<String> nextPinnedIds) {
    final prev = _lastPinnedOsmIds;
    if (identical(prev, nextPinnedIds)) return;

    final changed = <String>[];
    for (final id in nextPinnedIds) {
      if (!prev.contains(id)) changed.add(id);
    }
    for (final id in prev) {
      if (!nextPinnedIds.contains(id)) changed.add(id);
    }

    if (changed.isEmpty) return;
    changed.sort();

    final limit = changed.length > _maxAnimatedTransitionsPerRebuild
        ? _maxAnimatedTransitionsPerRebuild
        : changed.length;
    for (var i = 0; i < limit; i++) {
      _startDotTransition(changed[i]);
    }
  }

  Marker _markerFor(
    PlacePoint place, {
    required bool isSelected,
    required bool shouldPin,
  }) {
    final step = _dotTransitionStepByOsmId[place.osmId];
    final dotIcon = switch (step) {
      1 => _dotIconPop,
      2 => _dotIconSmall,
      _ => _dotIconNormal,
    };

    final iconOverride = step != null ? dotIcon : null;

    return Marker(
      markerId: MarkerId(place.osmId),
      position: place.location,
      alpha: 1.0,
      zIndexInt: isSelected ? 3 : (shouldPin ? 2 : 1),
      consumeTapEvents: true,
      icon: isSelected
          ? _selectedMarkerIcon
          : (iconOverride ??
                (shouldPin
                    ? _defaultMarkerIcon
                    : (dotIcon ?? _defaultMarkerIcon))),
      onTap: () => _selectPlace(place),
      infoWindow: const InfoWindow(title: ''),
    );
  }

  String get _normalizedSearchQuery =>
      PlaceSearch.normalizeQuery(widget.searchQuery);

  List<PlacePoint> _visiblePlacesForQuery({required String query}) {
    return PlaceSearch.filterPlaces(_places, query);
  }

  void _scheduleVisibleCountReport(int count) {
    final cb = widget.onVisiblePlacesCountChanged;
    if (cb == null) return;
    if (_lastNotifiedVisibleCount == count) return;
    _lastNotifiedVisibleCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cb(count);
    });
  }

  Future<void> _maybeZoomToSingleResult() async {
    final query = _normalizedSearchQuery;
    if (query.isEmpty) return;

    final visiblePlaces = _visiblePlacesForQuery(query: query);
    if (visiblePlaces.length != 1) return;

    final controller = _controller;
    if (!mounted || controller == null) return;

    final target = visiblePlaces.single.location;
    try {
      _isAnimating = true;
      _suppressNextIdleFetch = true;
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(target, _singleResultZoom),
      );
    } catch (e) {
      _logMap('[MapDbg] single-result zoom error: $e');
    } finally {
      _isAnimating = false;
    }
  }

  static final LatLngBounds _fallbackBounds = LatLngBounds(
    // Roughly ~20km box around the initial camera target.
    southwest: LatLng(
      _initialTarget.latitude - 0.18,
      _initialTarget.longitude - 0.22,
    ),
    northeast: LatLng(
      _initialTarget.latitude + 0.18,
      _initialTarget.longitude + 0.22,
    ),
  );

  // Expand a viewport bounds so we fetch markers slightly beyond the screen.
  // This reduces the “marker wall” effect at the edges while panning.
  static LatLngBounds _paddedBounds(
    LatLngBounds b, {
    double padFraction = 0.12,
    double minPadDegrees = 0.002,
  }) {
    double clamp(double v, double min, double max) {
      if (v < min) return min;
      if (v > max) return max;
      return v;
    }

    final latSpan = (b.northeast.latitude - b.southwest.latitude).abs();

    // Longitude span can cross the antimeridian.
    final west = b.southwest.longitude;
    final east = b.northeast.longitude;
    final lngSpan = west <= east
        ? (east - west).abs()
        : (180 - west + east + 180).abs();

    final latPad = (latSpan * padFraction).clamp(minPadDegrees, 90.0);
    final lngPad = (lngSpan * padFraction).clamp(minPadDegrees, 180.0);

    final swLat = clamp(b.southwest.latitude - latPad, -90.0, 90.0);
    final neLat = clamp(b.northeast.latitude + latPad, -90.0, 90.0);
    final swLng = clamp(b.southwest.longitude - lngPad, -180.0, 180.0);
    final neLng = clamp(b.northeast.longitude + lngPad, -180.0, 180.0);

    return LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
  }

  Future<bool> _fetchPlacesForBounds(
    LatLngBounds bounds, {
    required String reason,
  }) async {
    try {
      final last = _lastFetchedBounds;
      if (last != null && _boundsRoughlyEqual(last, bounds)) {
        return false;
      }

      if (_isLoadingPlaces) return false;
      if (mounted) {
        setState(() {
          _isLoadingPlaces = true;
        });
      } else {
        _isLoadingPlaces = true;
      }

      _lastFetchedBounds = bounds;
      final points = await widget.backendApi.fetchMapPlacePoints(
        bounds: bounds,
        zoom: _currentZoom,
        visibleFilterMode: VisibleFilterMode.all,
      );
      if (!mounted) return false;

      setState(() {
        _places = points;
      });

      _scheduleVisibleCountReport(
        PlaceSearch.filterPlaces(points, _normalizedSearchQuery).length,
      );

      unawaited(_maybeZoomToSingleResult());
      unawaited(_logViewportMarkers(reason: reason));
      return true;
    } catch (e) {
      if (!mounted) return false;
      widget.onPlacesError?.call(e.toString());
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      } else {
        _isLoadingPlaces = false;
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _controller = controller;

    final style = _mapStyle;
    if (style != null) {
      try {
        // ignore: deprecated_member_use
        await controller.setMapStyle(style);
      } catch (_) {
        // Ignore if not supported.
      }
    }

    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      unawaited(_refreshMarkersForViewport(reason: 'initial-load'));
    }
  }

  void _onCameraMove(CameraPosition position) {
    // Don't process if we're currently animating.
    if (_isAnimating) return;

    _currentZoom = position.zoom;

    _logCameraMove(position);
  }

  void _onCameraMoveStarted() {
    // Any pending suppression was intended for a programmatic animation.
    // Once the user moves the camera again, the next idle should be treated
    // as user-driven.
    _suppressNextIdleFetch = false;
    _logMap(
      '[MapDbg] camera move started zoom=${_currentZoom.toStringAsFixed(2)}',
    );
  }

  void _onCameraIdle() {
    // Avoid reacting when the camera idle is triggered by our own
    // programmatic animations (e.g. marker focus, single-result zoom, tilt).
    if (_suppressNextIdleFetch) {
      _suppressNextIdleFetch = false;
      return;
    }

    if (_isAnimating) return;

    _logMap('[MapDbg] camera idle zoom=${_currentZoom.toStringAsFixed(2)}');
    unawaited(_logViewportMarkers(reason: 'idle'));

    // Do not auto-fetch on camera idle.
    unawaited(_markSearchThisAreaVisible(reason: 'viewport-idle'));
  }

  Future<void> _markSearchThisAreaVisible({required String reason}) async {
    try {
      final controller = _controller;
      final viewport = controller == null
          ? _fallbackBounds
          : await controller.getVisibleRegion();
      final bounds = _paddedBounds(viewport);

      final last = _lastFetchedBounds;
      final shouldShow = last == null || !_boundsRoughlyEqual(last, bounds);

      if (!mounted) return;
      if (!shouldShow) {
        if (_showSearchThisArea || _pendingBounds != null) {
          setState(() {
            _showSearchThisArea = false;
            _pendingBounds = null;
          });
        }
        return;
      }

      setState(() {
        _lastViewportBounds = viewport;
        _pendingBounds = bounds;
        _showSearchThisArea = true;
      });

      _logMap('[MapDbg] dirty viewport ($reason) -> show CTA');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastViewportBounds = _fallbackBounds;
        _pendingBounds = _paddedBounds(_fallbackBounds);
        _showSearchThisArea = true;
      });
    }
  }

  Future<void> _onSearchThisAreaPressed() async {
    if (_isLoadingPlaces) return;

    LatLngBounds bounds;
    try {
      final controller = _controller;
      if (controller != null) {
        final viewport = await controller.getVisibleRegion();
        if (mounted) {
          setState(() {
            _lastViewportBounds = viewport;
          });
        } else {
          _lastViewportBounds = viewport;
        }
      }
      bounds =
          _pendingBounds ??
          _paddedBounds(
            controller == null
                ? _fallbackBounds
                : await controller.getVisibleRegion(),
          );
    } catch (_) {
      bounds = _pendingBounds ?? _paddedBounds(_fallbackBounds);
    }

    final didFetch = await _fetchPlacesForBounds(
      bounds,
      reason: 'search-this-area',
    );
    if (!mounted) return;

    final last = _lastFetchedBounds;
    final alreadyHaveBounds = last != null && _boundsRoughlyEqual(last, bounds);
    if (didFetch || alreadyHaveBounds) {
      setState(() {
        _showSearchThisArea = false;
        _pendingBounds = null;
      });
    }
  }

  Future<void> _refreshMarkersForViewport({required String reason}) async {
    try {
      final controller = _controller;
      if (!mounted || controller == null) {
        await _fetchPlacesForBounds(
          _paddedBounds(_fallbackBounds),
          reason: reason,
        );
        return;
      }

      final bounds = _paddedBounds(await controller.getVisibleRegion());
      await _fetchPlacesForBounds(bounds, reason: reason);
    } catch (_) {
      // If visible region fails, fall back to a safe bounds.
      await _fetchPlacesForBounds(
        _paddedBounds(_fallbackBounds),
        reason: '$reason(fallback)',
      );
    }
  }

  static bool _boundsRoughlyEqual(LatLngBounds a, LatLngBounds b) {
    // Round to ~3 decimal places (~100m) to reduce chatty calls.
    double r(double v) => double.parse(v.toStringAsFixed(3));
    return r(a.southwest.latitude) == r(b.southwest.latitude) &&
        r(a.southwest.longitude) == r(b.southwest.longitude) &&
        r(a.northeast.latitude) == r(b.northeast.latitude) &&
        r(a.northeast.longitude) == r(b.northeast.longitude);
  }

  Future<void> _focusOn(LatLng target) async {
    final controller = _controller;
    if (!mounted || controller == null) return;

    try {
      _isAnimating = true;
      _suppressNextIdleFetch = true;
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    } catch (e) {
      _logMap('[MapDbg] focus error: $e');
    } finally {
      _isAnimating = false;
    }
  }

  void _selectPlace(PlacePoint place) {
    _lastMarkerTapAt = DateTime.now();
    FocusManager.instance.primaryFocus?.unfocus();
    final prevSelectedId = _effectiveSelectedPlaceId;
    final nextSelectedId = place.osmId;
    if (prevSelectedId == nextSelectedId) {
      unawaited(_focusOn(place.location));
      return;
    }

    setState(() {
      _selectedPlaceId = nextSelectedId;
    });
    unawaited(_focusOn(place.location));
    widget.onPlaceSelected?.call(place);
    unawaited(_logViewportMarkers(reason: 'select'));
  }

  void _onMapTapped() {
    final now = DateTime.now();
    if (now.difference(_lastMarkerTapAt).inMilliseconds <
        _ignoreMapTapAfterMarkerMs) {
      return;
    }
    _clearSelection();
  }

  void _clearSelection() {
    final prevSelectedId = _effectiveSelectedPlaceId;
    if (prevSelectedId == null) return;

    setState(() {
      _selectedPlaceId = null;
    });
    widget.onPlaceDeselected?.call();
    unawaited(_logViewportMarkers(reason: 'deselect'));
  }

  void _logMap(String message) {
    if (!_mapDebugLogsEnabled) return;
    AppLog.d('Map', message);
  }

  void _logCameraMove(CameraPosition position) {
    if (!_mapDebugLogsEnabled) return;
    final now = DateTime.now();
    final zoomDelta = (position.zoom - _lastLoggedZoom).abs();
    final shouldLog =
        zoomDelta >= 0.75 ||
        now.difference(_lastMoveLogAt).inMilliseconds > 1500;
    if (!shouldLog) return;

    _lastMoveLogAt = now;
    _lastLoggedZoom = position.zoom;
    _logMap(
      '[MapDbg] camera move zoom=${position.zoom.toStringAsFixed(2)} '
      'target=${position.target.latitude.toStringAsFixed(5)},${position.target.longitude.toStringAsFixed(5)}',
    );
  }

  Future<void> _logViewportMarkers({required String reason}) async {
    if (!_mapDebugLogsEnabled) return;
    final controller = _controller;
    if (!mounted || controller == null) return;

    final now = DateTime.now();
    if (now.difference(_lastViewportLogAt).inMilliseconds < 2000) return;
    _lastViewportLogAt = now;

    try {
      final bounds = await controller.getVisibleRegion();
      final markers = _lastBuiltMarkers;
      final totalMarkers = markers.length;
      final visibleMarkers = markers
          .where((m) => _boundsContains(bounds, m.position))
          .length;

      _logMap(
        '[MapDbg] $reason zoom=${_currentZoom.toStringAsFixed(2)} '
        'places=${_places.length} markers(total=$totalMarkers visible=$visibleMarkers)',
      );
    } catch (e) {
      _logMap('[MapDbg] $reason visible-region error: $e');
    }
  }

  static bool _boundsContains(LatLngBounds b, LatLng p) {
    final south = b.southwest.latitude;
    final north = b.northeast.latitude;
    final west = b.southwest.longitude;
    final east = b.northeast.longitude;

    final inLat = p.latitude >= south && p.latitude <= north;
    final inLng = west <= east
        ? (p.longitude >= west && p.longitude <= east)
        : (p.longitude >= west || p.longitude <= east);
    return inLat && inLng;
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalizedSearchQuery;
    final selectedId = _effectiveSelectedPlaceId;
    final visiblePlaces = _visiblePlacesForQuery(query: query);

    final viewportBounds = _lastViewportBounds;
    final placesInViewport = viewportBounds == null
        ? visiblePlaces
        : visiblePlaces
              .where((p) => _boundsContains(viewportBounds, p.location))
              .toList(growable: false);

    final renderPlaces = _limitPlacesForMap(
      places: placesInViewport,
      selectedId: selectedId,
    );

    final pinnedIds = _computePinnedOsmIds(
      // Pin budget should be based on what's actually visible on screen.
      visiblePlaces: renderPlaces,
      selectedId: selectedId,
    );

    _maybeAnimateDotPinTransitions(pinnedIds);
    _lastPinnedOsmIds = pinnedIds;

    final markersById = <String, Marker>{
      for (final p in renderPlaces)
        p.osmId: _markerFor(
          p,
          isSelected: selectedId != null && p.osmId == selectedId,
          shouldPin: pinnedIds.contains(p.osmId),
        ),
    };
    final markers = markersById.values.toSet();
    _lastBuiltMarkers = markers;
    // Report actual visible place count (not capped rendered count).
    _scheduleVisibleCountReport(placesInViewport.length);

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          onCameraMoveStarted: _onCameraMoveStarted,
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          onTap: (_) => _onMapTapped(),
          initialCameraPosition: _initialPosition,
          style: _mapStyle,
          mapType: MapType.normal,
          buildingsEnabled: false,
          compassEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: true,
          zoomGesturesEnabled: true,
          zoomControlsEnabled: true,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          markers: markers,
        ),
        if (_showSearchThisArea)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: _isLoadingPlaces ? null : _onSearchThisAreaPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlightDarkest,
                    foregroundColor: AppColors.neutralLightLightest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: _isLoadingPlaces
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Search this area'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
