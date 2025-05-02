import 'package:flutter/material.dart';

class WorkActionButtons extends StatelessWidget {
  final bool isInsidePolygon;
  final bool canStartWork;
  final bool canStartBreak;
  final bool canFinishWork;
  final VoidCallback onStartWork;
  final VoidCallback onStartBreak;
  final VoidCallback onExit;

  const WorkActionButtons({
    Key? key,
    required this.isInsidePolygon,
    required this.canStartWork,
    required this.canStartBreak,
    required this.canFinishWork,
    required this.onStartWork,
    required this.onStartBreak,
    required this.onExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton(
                onPressed: isInsidePolygon && canStartWork ? onStartWork : null,
                child: const Text("MULAI KERJA"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isInsidePolygon && canStartBreak ? onStartBreak : null,
                child: const Text("ISTIRAHAT"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isInsidePolygon && canFinishWork ? onExit : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("KELUAR"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
