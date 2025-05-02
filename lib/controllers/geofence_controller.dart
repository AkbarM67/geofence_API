import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';

import '../services/geofence_service.dart';
import '../services/work_timer_service.dart';

class GeofenceController extends ChangeNotifier {
  final BuildContext context;
  final String name;
  final String id;

  final GeofenceService _geoService = GeofenceService();
  final WorkTimerService _timerService = WorkTimerService();

  GoogleMapController? mapController;
  bool isSatellite = false;
  final Set<Polygon> polygonSet = {};
  final Set<Marker> markerSet = {};
  List<LatLng> polygonPoints = [];
  LatLng initialPos = const LatLng(-4.7635, 105.3251);
  bool isInsidePolygon = false;
  bool isPaused = false;
  bool canStartWork = true;
  bool canStartBreak = true;
  bool canFinishWork = false;
  String workCountdownText = "";
  String breakCountdownText = "";

  int masukCount = 0;
  int keluarCount = 0;
  Duration inAreaDuration = Duration.zero;
  Duration pausedDuration = Duration.zero;
  DateTime? entryTime;
  DateTime? pauseStartTime;

  Timer? _durationTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _trackingStream;

  bool get isWorking => _timerService.isWorking;

  GeofenceController({
    required this.context,
    required this.name,
    required this.id,
  });

  void init() {
    _loadPolygonDetail();
    _startUserLocationTracking();
    _startTrackingCountListener();

    _timerService.onWorkTick = (remaining) {
      workCountdownText = _formatDuration(remaining);
      canStartBreak = remaining > const Duration(minutes: 20);
      notifyListeners();
    };

    _timerService.onWorkFinish = () {
      canStartWork = true;
      workCountdownText = "";
      canFinishWork = true;
      notifyListeners();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waktu kerja selesai. Tekan KELUAR untuk menyelesaikan kerja.")),
        );
      });
    };
  }

  void toggleMapType() {
    isSatellite = !isSatellite;
    notifyListeners();
  }

  Future<void> _loadPolygonDetail() async {
    final data = await _geoService.getPolygonById(id);
    if (data == null) return;

    final coordinates = data['polygon']['coordinates'][0];
    final polygonId = data['id'] ?? 'unknown';

    final points = coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    final center = _getPolygonCenter(points);

    polygonSet.clear();
    polygonSet.add(Polygon(
      polygonId: PolygonId(polygonId),
      points: points,
      strokeColor: Colors.green,
      strokeWidth: 2,
      fillColor: Colors.green.withOpacity(0.3),
    ));

    markerSet.clear();
    markerSet.add(Marker(
      markerId: MarkerId(name),
      position: center,
      infoWindow: InfoWindow(title: name),
    ));

    polygonPoints = points;
    initialPos = center;

    notifyListeners();

    Future.delayed(const Duration(milliseconds: 400), () {
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(center, 17));
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
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10);

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) async {
      final userLatLng = LatLng(position.latitude, position.longitude);
      markerSet.removeWhere((m) => m.markerId.value == 'user');
      markerSet.add(Marker(
        markerId: const MarkerId('user'),
        position: userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Posisi Saya'),
      ));

      final inside = _isPointInPolygon(userLatLng, polygonPoints);

      if (inside && !isInsidePolygon) {
        isInsidePolygon = true;

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 300);
        }

        if (pauseStartTime != null) {
          pausedDuration += DateTime.now().difference(pauseStartTime!);
          pauseStartTime = null;
        }


        await _logUserAreaStatus("MASUK", userLatLng);
      } else if (!inside && isInsidePolygon) {
        isInsidePolygon = false;

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 500);
        }

        if (_timerService.isWorking) {
          isPaused = true;
          pauseStartTime = DateTime.now();
          _timerService.pauseWork();
          _timerService.startBreak();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Kamu keluar area, waktu kerja dijeda untuk istirahat."),
                duration: Duration(seconds: 3),
              ),
            );
          });
        }

        if (entryTime != null) {
          await _logUserAreaStatusWithDuration("KELUAR", userLatLng);
        }
      }

      notifyListeners();
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

  void _startDurationTimer() {
    entryTime = DateTime.now();
    _durationTimer?.cancel();
    inAreaDuration = Duration.zero;
    pausedDuration = Duration.zero;
    pauseStartTime = null;
    isPaused = false;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused && entryTime != null) {
        inAreaDuration = DateTime.now().difference(entryTime!);
        notifyListeners();
      }
    });
  }

  void _stopDurationTimer({bool reset = true}) {
    _durationTimer?.cancel();
    if (reset) {
      pauseStartTime = null;
      entryTime = null;
      isPaused = false;
      inAreaDuration = Duration.zero;
      pausedDuration = Duration.zero;
    }
  }

  Future<void> _logUserAreaStatus(String status, LatLng position) async {
    try {
      await FirebaseFirestore.instance.collection('user_tracking_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'area_name': name,
        'status': status,
        'entry_time': entryTime,
        'exit_time': DateTime.now(),
        'total_duration': inAreaDuration.inSeconds,
        'rest_duration': pausedDuration.inSeconds,
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });
    } catch (_) {}
  }

  Future<void> _logUserAreaStatusWithDuration(String status, LatLng position) async {
    try {
      await FirebaseFirestore.instance.collection('user_tracking_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'area_name': name,
        'status': status,
        'entry_time': entryTime,
        'exit_time': DateTime.now(),
        'total_duration': inAreaDuration.inSeconds,
        'rest_duration': pausedDuration.inSeconds,
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });
    } catch (_) {}
  }

  Future<void> logWorkStatus(String status) async {
    if (status == "KERJA" && !isInsidePolygon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak bisa mulai kerja di luar area.")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    final userLatLng = LatLng(position.latitude, position.longitude);

    if (status == "KERJA") {
      _timerService.stopBreak();
      isPaused = false;
      canStartWork = false;
      _timerService.startWork(from: _timerService.remainingTime);
    }

    if (status == "ISTIRAHAT") {
      isPaused = true;
      canStartWork = true;
      _timerService.pauseWork();
      _timerService.startBreak();
      pauseStartTime = DateTime.now();
    }

    if (status == "KELUAR") {
      _timerService.dispose();
      isPaused = false;
      canStartWork = true;
      canStartBreak = false;
      workCountdownText = "";
      breakCountdownText = "";
      _stopDurationTimer(reset: true);
    }

    notifyListeners();

    await FirebaseFirestore.instance.collection('user_tracking_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
        'area_name': name,
        'status': status,
        'entry_time': entryTime,
        'exit_time': DateTime.now(),
        'total_duration': inAreaDuration.inSeconds,
        'rest_duration': pausedDuration.inSeconds,
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
      },
    });
  }

  void _startTrackingCountListener() {
    _trackingStream = FirebaseFirestore.instance
        .collection('user_tracking_logs')
        .where('area_name', isEqualTo: name)
        .snapshots()
        .listen((snapshot) {
      int masuk = 0;
      int keluar = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == "MASUK") masuk++;
        if (data['status'] == "KELUAR") keluar++;
      }
      masukCount = masuk;
      keluarCount = keluar;
      notifyListeners();
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _trackingStream?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}
