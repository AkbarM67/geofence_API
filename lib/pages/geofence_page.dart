import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geo_fencing_vat/services/geofence_service.dart';
import 'package:geo_fencing_vat/services/work_timer_service.dart';
import 'package:geo_fencing_vat/widget/timer_countdown_card.dart';
import 'package:geo_fencing_vat/widget/work_action_buttons.dart';
import 'package:geo_fencing_vat/widget/geofence_status_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vibration/vibration.dart';

class GeofencePage extends StatefulWidget {
  final String name;
  final String id;

  const GeofencePage({super.key, required this.name, required this.id});

  @override
  State<GeofencePage> createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final _geoService = GeofenceService();
  final _timerService = WorkTimerService();

  GoogleMapController? _mapController;
  LatLng _initialPos = const LatLng(-4.7635, 105.3251);
  final Set<Polygon> _polygonSet = {};
  final Set<Marker> _markerSet = {};
  List<LatLng> _polygonPoints = [];

  bool _isSatellite = false;
  bool _isInsidePolygon = false;
  bool _canStartWork = true;
  bool _canStartBreak = true;
  bool _canFinishWork = false;
  bool _isPaused = false;
  bool _isWorkingState = false;
  bool _hasLoggedExit = false;

  String _workCountdownText = "";
  int _masukCount = 0;
  int _keluarCount = 0;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _trackingStream;

  Timer? _durationTimer;
  Duration _inAreaDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _entryTime;
  DateTime? _pauseStartTime;

  @override
void initState() {
  super.initState();
  _loadPolygonDetail();
  _startUserLocationTracking();
  _startTrackingCountListener();

  _timerService.onWorkTick = (remaining) {
  setState(() {
    _workCountdownText = _formatDuration(remaining);
    _canStartBreak = remaining > const Duration(seconds: 20);
  });

  if (remaining.inSeconds == 20) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("20 detik terakhir - Tombol istirahat dinonaktifkan."),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }
};

    _timerService.onWorkFinish = () {
    setState(() {
      _canStartWork = true;
      _canStartBreak = false;
      _canFinishWork = true;
      _workCountdownText = "";
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jam kerja sudah beres. Tekan KELUAR untuk menyelesaikan kerja."),
          duration: Duration(seconds: 3),
        ),
      );
    });
  };
}

  Future<void> _loadPolygonDetail() async {
    final data = await _geoService.getPolygonById(widget.id);
    if (data == null) return;

    final coordinates = data['polygon']['coordinates'][0];
    final List<LatLng> points = coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    final center = _getPolygonCenter(points);

    setState(() {
      _polygonSet.add(Polygon(
        polygonId: PolygonId(widget.id),
        points: points,
        strokeColor: Colors.green,
        strokeWidth: 2,
        fillColor: Colors.green.withOpacity(0.3),
      ));
      _markerSet.add(Marker(markerId: MarkerId(widget.name), position: center));
      _initialPos = center;
      _polygonPoints = points;
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
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) async {
      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _markerSet.removeWhere((m) => m.markerId.value == 'user');
        _markerSet.add(Marker(markerId: const MarkerId('user'), position: userLatLng));
      });

      final inside = _isPointInPolygon(userLatLng, _polygonPoints);
      if (inside && !_isInsidePolygon) {
        _isInsidePolygon = true;

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 300);
        }

        if (_pauseStartTime != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartTime!);
          _pauseStartTime = null;
        }

        await _logUserAreaStatus("MASUK", userLatLng);
        } else if (!inside && _isInsidePolygon) {
        _isInsidePolygon = false;

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 300);
        }

        _pauseStartTime = DateTime.now();
        _isPaused = true;

        if (_isWorkingState) {
          _isWorkingState = false;
          _timerService.pauseWork();
          _timerService.startBreak();
        }

        await _logUserAreaStatus("KELUAR", userLatLng);
      }
    });
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

 void _startDurationTimer() {
  _durationTimer?.cancel();
  _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() {
      if (_isWorkingState && !_isPaused) {
        _inAreaDuration += const Duration(seconds: 1);
      } else if (_isPaused) {
        _pausedDuration += const Duration(seconds: 1);
      }
    });
  });
}

  void _stopDurationTimer({bool reset = true}) {
    _durationTimer?.cancel();
    if (reset) {
      _inAreaDuration = Duration.zero;
      _pausedDuration = Duration.zero;
      _entryTime = null;
      _pauseStartTime = null;
    }
  }

    Future<void> saveRemainingTimeToFirestore(String userId) async {
      await FirebaseFirestore.instance.collection('user_timers').doc(userId).set({
        'remaining_seconds': _timerService.remainingTime.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

  Future<void> _logUserAreaStatus(String status, LatLng position) async {
  final data = {
    'timestamp': FieldValue.serverTimestamp(),
    'area_name': widget.name,
    'status': status,
    'position': {
      'latitude': position.latitude,
      'longitude': position.longitude,
    },
  };

  await FirebaseFirestore.instance.collection('user_tracking_logs').add(data);
}

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].longitude < point.longitude && polygon[j].longitude >= point.longitude ||
          polygon[j].longitude < point.longitude && polygon[i].longitude >= point.longitude) &&
          (polygon[i].latitude <= point.latitude || polygon[j].latitude <= point.latitude)) {
        oddNodes ^= (polygon[i].latitude +
                (point.longitude - polygon[i].longitude) /
                    (polygon[j].longitude - polygon[i].longitude) *
                    (polygon[j].latitude - polygon[i].latitude) <
            point.latitude);
      }
      j = i;
    }
    return oddNodes;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  Future<void> _logWorkStatus(String status) async {
      final pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);

      if (status == "KERJA") {
        if (!_timerService.isWorking) {
          _isWorkingState = true;
          _isPaused = false;
          _canStartWork = false;
          _entryTime ??= DateTime.now();

          setState(() {});

          _timerService.startWork();
          _startDurationTimer();
        }
      } else if (status == "ISTIRAHAT") {
        if (_timerService.isWorking) {
          _isWorkingState = false;
          _timerService.pauseWork();
          _isPaused = true;
          _canStartWork = true;
          _canStartBreak = false;

          _pauseStartTime = DateTime.now();
          _timerService.startBreak();
          _startDurationTimer();
        }
      } else if (status == "KELUAR") {
      if (_hasLoggedExit) return;
      _hasLoggedExit = true;

      _isWorkingState = false;
      _timerService.dispose();
      _isPaused = false;
      _canStartWork = true;
      _canStartBreak = false;
      _canFinishWork = false;
      _workCountdownText = "";

      final now = DateTime.now();

      if (_entryTime != null) {
        _inAreaDuration = now.difference(_entryTime!);
      }

      await FirebaseFirestore.instance.collection('user_tracking_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'area_name': widget.name,
        'status': "KELUAR",
        'entry_time': _entryTime,
        'exit_time': now,
        'total_duration': _inAreaDuration.inSeconds,
        'rest_duration': _pausedDuration.inSeconds,
        'position': {
          'latitude': userLatLng.latitude,
          'longitude': userLatLng.longitude,
        },
      });

      _entryTime = null;
      _pauseStartTime = null;
      _pausedDuration = Duration.zero;
      _inAreaDuration = Duration.zero;

      return;
    }
  }



  @override
  void dispose() {
    _positionStream?.cancel();
    _trackingStream?.cancel();
    _timerService.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Area: ${widget.name}"),
        actions: [
          IconButton(
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite),
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(target: _initialPos, zoom: 17),
            polygons: _polygonSet,
            markers: _markerSet,
            mapType: _isSatellite ? MapType.satellite : MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          GeofenceStatusCard(
            inAreaDuration: _inAreaDuration,
            pausedDuration: _pausedDuration,
            masukCount: _masukCount,
            keluarCount: _keluarCount,
          ),
           Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: WorkActionButtons(
              isInsidePolygon: _isInsidePolygon,
              canStartWork: _canStartWork,
              canStartBreak: _canStartBreak,
              canFinishWork: _canFinishWork,
              onStartWork: () => _logWorkStatus("KERJA"),
              onStartBreak: () => _logWorkStatus("ISTIRAHAT"),
              onExit: () => _logWorkStatus("KELUAR"),
            ),
          ),
        ],
      ),
    );
  }
}
