import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/colors.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.initialLocation,
  });

  final LatLng initialLocation;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _controller;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
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
          // Style is optional.
        }
      }
    } catch (_) {
      // Style is optional.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose location'),
        backgroundColor: AppColors.neutralLightLightest,
        foregroundColor: AppColors.neutralDarkest,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15.5,
              tilt: 0,
              bearing: 0,
            ),
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) async {
              _controller = c;
              final style = _mapStyle;
              if (style != null) {
                try {
                  // ignore: deprecated_member_use
                  await c.setMapStyle(style);
                } catch (_) {
                  // Ignore.
                }
              }
            },
            onTap: (latLng) {
              Navigator.of(context).pop<LatLng>(latLng);
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.neutralLightLightest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Tap on the map to set a new search area.',
                style: TextStyle(
                  color: AppColors.neutralDarkLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Icon(
                Icons.place,
                size: 36,
                color: AppColors.pinMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
