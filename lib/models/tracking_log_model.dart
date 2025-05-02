import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingLog {
  final DateTime timestamp;
  final String areaName;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int? totalDuration;
  final int? restDuration;

  TrackingLog({
    required this.timestamp,
    required this.areaName,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.entryTime,
    required this.exitTime,
    required this.totalDuration,
    required this.restDuration,
    
  });

  // Convert dari Firestore ke Model
  factory TrackingLog.fromFirestore(Map<String, dynamic> data) {
  final position = data['position'] ?? {};
  return TrackingLog(
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    areaName: data['area_name'] ?? '',
    status: data['status'] ?? '',
    latitude: (position['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (position['longitude'] as num?)?.toDouble() ?? 0.0,
    entryTime: (data['entry_time'] as Timestamp?)?.toDate(),
    exitTime: (data['exit_time'] as Timestamp?)?.toDate(),
    totalDuration: data['total_duration'],
    restDuration: data['rest_duration'],
  );
}

  // Convert dari Model ke Firestore Map
  Map<String, dynamic> toMap() {
  return {
    'timestamp': Timestamp.fromDate(timestamp),
    'area_name': areaName,
    'status': status,
    'entry_time': entryTime != null ? Timestamp.fromDate(entryTime!) : null,
    'exit_time': exitTime != null ? Timestamp.fromDate(exitTime!) : null,
    'total_duration': totalDuration,
    'rest_duration': restDuration,
    'position': {
      'latitude': latitude,
      'longitude': longitude,
    },
  };
}
}
