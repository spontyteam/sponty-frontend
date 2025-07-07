import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class MapWidget extends StatefulWidget {
  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController _controller;
  bool _locationPermissionGranted = false;
  String mapStyle = "";

  static const LatLng _initialTarget = LatLng(-33.8688, 151.2093);

  final CameraPosition _initialPosition = CameraPosition(
    target: _initialTarget,
    zoom: 17.0,
    tilt: 60.0,
    bearing: 45.0,
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
      _goToUserLocation();
    }
  }

  Future<void> _goToUserLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final userLatLng = LatLng(position.latitude, position.longitude);
    _controller.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 17));
  }

  void _onMapCreated(GoogleMapController controller) async {
    _controller = controller;

    mapStyle = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_style.json');

    _controller.setMapStyle(mapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: _initialPosition,
      mapType: MapType.normal,
      buildingsEnabled: false,
      compassEnabled: true,
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
