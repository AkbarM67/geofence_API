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
              final latitude = data['position']?['latitude'];
              final longitude = data['position']?['longitude'];
              final durasiIstirahat = data['rest_duration'];
              final totalKerja = data['total_duration'];
              final entryTime = (data['entry_time'] as Timestamp?)?.toDate();
              final exitTime = (data['exit_time'] as Timestamp?)?.toDate();

              return ListTile(
                leading: Icon(
                  status == "MASUK"
                      ? Icons.login
                      : status == "ISTIRAHAT"
                          ? Icons.free_breakfast
                          : Icons.logout,
                  color: status == "MASUK"
                      ? Colors.green
                      : status == "ISTIRAHAT"
                          ? Colors.orange
                          : Colors.blue,
                ),
                title: Text("Status: $status"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Area: $areaName"),
                    
                    if (entryTime != null)
                      Text("Waktu Masuk: ${_formatDateTime(entryTime)}"),

                    if (exitTime != null)
                      Text("Waktu Keluar: ${_formatDateTime(exitTime)}"),

                    if (totalKerja != null && totalKerja is int)
                      Text("Durasi Kerja: ${_formatDuration(Duration(seconds: totalKerja))}"),

                    if (durasiIstirahat != null && durasiIstirahat is int)
                      Text("Durasi Istirahat: ${_formatDuration(Duration(seconds: durasiIstirahat))}"),

                    if (latitude != null && longitude != null)
                      Text("Lokasi: $latitude, $longitude"),

                    if (timestamp != null)
                      Text("Waktu Dicatat: ${_formatDateTime(timestamp)}"),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:" 
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
