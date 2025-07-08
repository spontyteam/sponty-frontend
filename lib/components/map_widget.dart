import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class MapWidget extends StatefulWidget {
  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;
  bool _locationPermissionGranted = false;
  String mapStyle = "";
  double _currentZoom = 0.0;
  bool _tiltApplied = false;
  bool _isAnimating = false; // Add this flag to prevent conflicts
  CameraPosition? _lastCameraPosition; // Store the last camera position

  static const LatLng _initialTarget = LatLng(-33.8688, 151.2093);
  static const double _desiredTilt = 67.5;
  static const double _zoomThreshold = 15.5;

  final CameraPosition _initialPosition = CameraPosition(
    target: _initialTarget,
    zoom: _zoomThreshold,
    tilt: _desiredTilt,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
      // Don't call _goToUserLocationWithTilt here - wait for map to be ready
    }
  }

  Future<void> _goToUserLocationWithTilt() async {
    if (_controller == null) return; // Safety check

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final userLatLng = LatLng(position.latitude, position.longitude);

    _isAnimating = true;
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userLatLng,
          zoom: _zoomThreshold,
          tilt: _desiredTilt,
        ),
      ),
    );
    _tiltApplied = true;
    _isAnimating = false;
  }

  void _onMapCreated(GoogleMapController controller) async {
    _controller = controller;

    mapStyle = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_style.json');

    _controller!.setMapStyle(mapStyle);

    // Now that the map is ready, go to user location if permission is granted
    if (_locationPermissionGranted) {
      _goToUserLocationWithTilt();
    }
  }

  void _onCameraMove(CameraPosition position) {
    // Don't process if we're currently animating
    if (_isAnimating) return;

    _currentZoom = position.zoom;
    _lastCameraPosition = position; // Store the current position

    print("Zoom level: ${position.zoom}");
    print("Tilt level: ${position.tilt}");
    print("Tilt Applied: ${_tiltApplied}");

    // Reset flag if user zooms out below threshold
    if (_currentZoom < _zoomThreshold) {
      _tiltApplied = false;
    }
  }

  void _onCameraIdle() {
    // This is called when camera movement stops
    // This is a better place to apply tilt adjustments
    if (_controller != null &&
        _currentZoom >= _zoomThreshold &&
        !_tiltApplied &&
        !_isAnimating) {
      _applyTiltAdjustment();
    }
  }

  Future<void> _applyTiltAdjustment() async {
    if (_controller == null || _lastCameraPosition == null) return;

    _isAnimating = true;
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _lastCameraPosition!.target,
          zoom: _currentZoom,
          tilt: _desiredTilt,
          bearing: _lastCameraPosition!.bearing,
        ),
      ),
    );
    _tiltApplied = true;
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle, // Add this callback
      initialCameraPosition: _initialPosition,
      mapType: MapType.normal,
      buildingsEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      zoomGesturesEnabled: true,
      zoomControlsEnabled: true,
      myLocationEnabled: _locationPermissionGranted,
      myLocationButtonEnabled: _locationPermissionGranted,
      markers: <Marker>{},
    );
  }
}
