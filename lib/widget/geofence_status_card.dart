import 'package:flutter/material.dart';

class GeofenceStatusCard extends StatelessWidget {
  final Duration inAreaDuration;
  final Duration pausedDuration;
  final int masukCount;
  final int keluarCount;

  const GeofenceStatusCard({
    super.key,
    required this.inAreaDuration,
    required this.pausedDuration,
    required this.masukCount,
    required this.keluarCount,
  });

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Kerja: ${_format(inAreaDuration)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Total Istirahat: ${_format(pausedDuration)}"),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _info("MASUK", masukCount, Colors.green),
                _info("KELUAR", keluarCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text("$count kali"),
      ],
    );
  }
}
