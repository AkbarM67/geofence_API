import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/geofence_controller.dart';

class GeofenceMap extends StatelessWidget {
  final GeofenceController controller;

  const GeofenceMap({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (c) => controller.mapController = c,
      initialCameraPosition: CameraPosition(target: controller.initialPos, zoom: 17),
      mapType: controller.isSatellite ? MapType.satellite : MapType.normal,
      polygons: controller.polygonSet,
      markers: controller.markerSet,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
