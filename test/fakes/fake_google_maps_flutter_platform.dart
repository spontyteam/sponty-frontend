import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Minimal fake for widget tests.
///
/// `google_maps_flutter` relies on [GoogleMapsFlutterPlatform] to build a
/// platform view and to receive camera/tap streams.
///
/// In widget tests we don't have real platform views, so this fake:
/// - Builds an empty widget (via the platform's `buildViewWithConfiguration`)
/// - Immediately triggers `onPlatformViewCreated`
/// - No-ops all imperative map commands
/// - Exposes empty streams for events
class FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  final Map<int, Completer<void>> _inits = <int, Completer<void>>{};
  final Set<int> _createdViews = <int>{};

  int? lastCreatedMapId;

  final StreamController<MarkerTapEvent> _markerTapController =
      StreamController<MarkerTapEvent>.broadcast();
  final StreamController<MapTapEvent> _mapTapController =
      StreamController<MapTapEvent>.broadcast();

    final StreamController<CameraMoveStartedEvent> _cameraMoveStartedController =
      StreamController<CameraMoveStartedEvent>.broadcast();
    final StreamController<CameraMoveEvent> _cameraMoveController =
      StreamController<CameraMoveEvent>.broadcast();
    final StreamController<CameraIdleEvent> _cameraIdleController =
      StreamController<CameraIdleEvent>.broadcast();

    LatLngBounds _visibleRegion = LatLngBounds(
      southwest: const LatLng(-90, -180),
      northeast: const LatLng(90, 180),
    );

  /// Emit a marker-tap event for widget tests.
  void emitMarkerTap({required int mapId, required MarkerId markerId}) {
    _markerTapController.add(MarkerTapEvent(mapId, markerId));
  }

  /// Emit a map-tap event for widget tests.
  void emitMapTap({required int mapId, required LatLng position}) {
    _mapTapController.add(MapTapEvent(mapId, position));
  }

  /// Set what [getVisibleRegion] should return.
  void setVisibleRegion(LatLngBounds bounds) {
    _visibleRegion = bounds;
  }

  /// Emit a camera-move-started event for widget tests.
  void emitCameraMoveStarted({required int mapId}) {
    _cameraMoveStartedController.add(CameraMoveStartedEvent(mapId));
  }

  /// Emit a camera-move event for widget tests.
  void emitCameraMove({required int mapId, required CameraPosition position}) {
    _cameraMoveController.add(CameraMoveEvent(mapId, position));
  }

  /// Emit a camera-idle event for widget tests.
  void emitCameraIdle({required int mapId}) {
    _cameraIdleController.add(CameraIdleEvent(mapId));
  }

  @override
  Future<void> init(int mapId) async {
    final completer = _inits.putIfAbsent(mapId, Completer<void>.new);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    // Pretend the platform view is created exactly once per id.
    lastCreatedMapId = creationId;
    if (_createdViews.add(creationId)) {
      scheduleMicrotask(() => onPlatformViewCreated(creationId));
    }
    return const SizedBox.expand();
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    // no-op
  }

  @override
  Future<void> setMapStyle(String? mapStyle, {required int mapId}) async {
    // no-op
  }

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async {
    return _visibleRegion;
  }

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _cameraMoveStartedController.stream.where((e) => e.mapId == mapId);

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _cameraMoveController.stream.where((e) => e.mapId == mapId);

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _cameraIdleController.stream.where((e) => e.mapId == mapId);

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      _markerTapController.stream.where((e) => e.mapId == mapId);

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream<InfoWindowTapEvent>.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream<MarkerDragStartEvent>.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream<MarkerDragEvent>.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream<MarkerDragEndEvent>.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream<PolylineTapEvent>.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream<PolygonTapEvent>.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream<CircleTapEvent>.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) =>
      _mapTapController.stream.where((e) => e.mapId == mapId);

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream<MapLongPressEvent>.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream<ClusterTapEvent>.empty();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      const Stream<GroundOverlayTapEvent>.empty();

  @override
  void dispose({required int mapId}) {
    _inits.remove(mapId);
    _createdViews.remove(mapId);
  }
}
