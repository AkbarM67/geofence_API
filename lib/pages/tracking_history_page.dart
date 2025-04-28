import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrackingHistoryPage extends StatelessWidget {
  const TrackingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Tracking User'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_tracking_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada data riwayat.'));
          }

          final logs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final areaName = data['area_name'] ?? '-';
              final status = data['status'] ?? '-';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final latitude = data['position']?['latitude'] ?? '-';
              final longitude = data['position']?['longitude'] ?? '-';

              return ListTile(
                leading: Icon(
                  status == "MASUK" ? Icons.login : Icons.logout,
                  color: status == "MASUK" ? Colors.green : Colors.red,
                ),
                title: Text("Area: $areaName"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status: $status"),
                    Text("Waktu: ${timestamp != null ? _formatDateTime(timestamp) : 'Unknown'}"),
                    Text("Lokasi: $latitude, $longitude"),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
  }
}
