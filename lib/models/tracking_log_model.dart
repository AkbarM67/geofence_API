import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingLog {
  final DateTime timestamp;
  final String areaName;
  final String status;
  final double latitude;
  final double longitude;

  TrackingLog({
    required this.timestamp,
    required this.areaName,
    required this.status,
    required this.latitude,
    required this.longitude,
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
    );
  }

  // Convert dari Model ke Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'area_name': areaName,
      'status': status,
      'position': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }
}
