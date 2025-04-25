import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geo_fencing_vat/services/geofence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class GeofencePage extends StatefulWidget {
  final String name;
  const GeofencePage({super.key, required this.name});

  @override
  State<GeofencePage> createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final _geoService = GeofenceService();
  final Set<Polygon> _polygonSet = {};
  final Set<Marker> _markerSet = {};
  final LatLng _fallbackPos = const LatLng(-4.7635, 105.3251);

  LatLng _initialPos = const LatLng(-4.7635, 105.3251);
  GoogleMapController? _mapController;
  bool _isSatellite = false;

  StreamSubscription<Position>? _positionStream;
  Marker? _userMarker;

  @override
  void initState() {
    super.initState();
    _loadPolygonDetail();
    _startUserLocationTracking();
  }

  Future<void> _loadPolygonDetail() async {
    final data = await _geoService.getPolygonByName(widget.name);
    if (data == null) return;

    final coordinates = data['polygon']['coordinates'][0];
    final id = data['id'] ?? 'unknown';

    final List<LatLng> points = coordinates.map<LatLng>((coord) {
      return LatLng(coord[1], coord[0]);
    }).toList();

    final center = _getPolygonCenter(points);

    setState(() {
      _polygonSet.clear();
      _polygonSet.add(
        Polygon(
          polygonId: PolygonId(id),
          points: points,
          strokeColor: Colors.green,
          strokeWidth: 2,
          fillColor: Colors.green.withOpacity(0.3),
        ),
      );

      _markerSet.clear();
      _markerSet.add(
        Marker(
          markerId: MarkerId(widget.name),
          position: center,
          infoWindow: InfoWindow(
            title: widget.name,
            snippet: 'Lat: ${center.latitude}, Lng: ${center.longitude}',
          ),
        ),
      );

      _initialPos = center;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(center, 17));
    });
  }

  LatLng _getPolygonCenter(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (var p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  void _startUserLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      final userLatLng = LatLng(position.latitude, position.longitude);

      final newMarker = Marker(
        markerId: const MarkerId('user'),
        position: userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Posisi Saya'),
      );

      setState(() {
        _markerSet.removeWhere((m) => m.markerId.value == 'user');
        _markerSet.add(newMarker);
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detail ${widget.name}"),
        actions: [
          IconButton(
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite),
            onPressed: () {
              setState(() {
                _isSatellite = !_isSatellite;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              controller.animateCamera(CameraUpdate.newLatLngZoom(_initialPos, 17));
            },
            initialCameraPosition: CameraPosition(target: _initialPos, zoom: 17),
            mapType: _isSatellite ? MapType.satellite : MapType.normal,
            polygons: _polygonSet,
            markers: _markerSet,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          Positioned(
            
            child: FloatingActionButton.small(
              heroTag: "centerBtn",
              onPressed: () {
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialPos, 17),
                  );
                }
              },
              child: const Icon(Icons.center_focus_strong), backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
