import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geo_fencing_vat/services/geofence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';

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
  StreamSubscription<QuerySnapshot>? _trackingStream;

  bool _isInsidePolygon = false;
  bool _showInsideText = false;
  String? _areaStatusText;

  List<LatLng> _polygonPoints = [];

  int _masukCount = 0;
  int _keluarCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPolygonDetail();
    _startUserLocationTracking();
    _startTrackingCountListener();
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

      _polygonPoints = points;
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
        .listen((Position position) async {
      final userLatLng = LatLng(position.latitude, position.longitude);

      final userMarker = Marker(
        markerId: const MarkerId('user'),
        position: userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Posisi Saya'),
      );

      setState(() {
        _markerSet.removeWhere((m) => m.markerId.value == 'user');
        _markerSet.add(userMarker);
      });

      if (_polygonPoints.isNotEmpty) {
        final inside = _isPointInPolygon(userLatLng, _polygonPoints);

        if (inside && !_isInsidePolygon) {
          _isInsidePolygon = true;
          _showInsideText = true;
          _areaStatusText = "Anda berada di dalam area ${widget.name}";

          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 500);
          }

          await _logUserAreaStatus(
            areaName: widget.name,
            status: "MASUK",
            position: userLatLng,
          );
        } else if (!inside && _isInsidePolygon) {
          _isInsidePolygon = false;
          _showInsideText = false;

          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 500);
          }
          

          await _logUserAreaStatus(
            areaName: widget.name,
            status: "KELUAR",
            position: userLatLng,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Kamu telah keluar dari area ${widget.name}."),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        setState(() {});
      }
    });
  }

  Future<void> _logUserAreaStatus({
    required String areaName,
    required String status,
    required LatLng position,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('user_tracking_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'area_name': areaName,
        'status': status,
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });
    } catch (e) {
      print("Gagal mengirim log ke Firestore: $e");
    }
  }

  void _startTrackingCountListener() {
    _trackingStream = FirebaseFirestore.instance
        .collection('user_tracking_logs')
        .where('area_name', isEqualTo: widget.name)
        .snapshots()
        .listen((snapshot) {
      int masuk = 0;
      int keluar = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == "MASUK") masuk++;
        if (data['status'] == "KELUAR") keluar++;
      }

      setState(() {
        _masukCount = masuk;
        _keluarCount = keluar;
      });
    });
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      LatLng a = polygon[j];
      LatLng b = polygon[j + 1];

      if ((a.longitude > point.longitude) != (b.longitude > point.longitude)) {
        double atX = (b.latitude - a.latitude) * (point.longitude - a.longitude) /
            (b.longitude - a.longitude) + a.latitude;
        if (point.latitude < atX) intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _trackingStream?.cancel();
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
          // Button Center Map
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Center Map',
              onPressed: () {
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialPos, 17),
                  );
                }
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

          // Counter MASUK & KELUAR Selalu Muncul
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text(
                        'MASUK',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text('$_masukCount Kali', style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'KELUAR',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      Text('$_keluarCount Kali', style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Teks "Anda berada di dalam area"
          if (_showInsideText)
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Anda berada di dalam area ${widget.name}", // <-- Ganti jadi
                    semanticsLabel: _areaStatusText ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
