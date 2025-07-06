import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatefulWidget {
  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController _controller;

  static const LatLng _initialTarget = LatLng(-33.8688, 151.2093);

  final CameraPosition _initialPosition = CameraPosition(
    target: _initialTarget,
    zoom: 17.0,
    tilt: 60.0,
    bearing: 45.0,
  );

  void _onMapCreated(GoogleMapController controller) async {
    _controller = controller;

    final style = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_style.json');

    _controller.setMapStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: _initialPosition,
      mapType: MapType.normal,
      buildingsEnabled: true,
      compassEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      markers: <Marker>{},
    );
  }
}
