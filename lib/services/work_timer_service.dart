import 'dart:async';

class WorkTimerService {
  Timer? _workTimer;
  Timer? _breakTimer;

  final Duration _workDuration = const Duration(minutes: 2);
  final Duration _breakDuration = const Duration(minutes: 15);

  Duration _remainingWork = const Duration(minutes: 2);
  Duration get remainingTime => _remainingWork;

  bool get isWorking => _workTimer != null && _workTimer!.isActive;
  bool get isOnBreak => _breakTimer != null && _breakTimer!.isActive;

  // Callbacks
  void Function(Duration)? onWorkTick;
  void Function()? onWorkFinish;
  void Function(Duration)? onBreakTick;
  void Function()? onBreakFinish;

  /// Mulai kerja dari awal atau dari durasi tersisa
  void startWork({Duration? from}) {
    stopWork(); // clear timer lama
    _remainingWork = from ?? _workDuration;

    _workTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingWork > Duration.zero) {
        _remainingWork -= const Duration(seconds: 1);
        onWorkTick?.call(_remainingWork);
      } else {
        stopWork();
        onWorkFinish?.call();
      }
    });
  }

  void pauseWork() {
    _workTimer?.cancel();
  }

  void resumeWork() {
    if (_remainingWork > Duration.zero) {
      startWork(from: _remainingWork);
    }
  }

  void stopWork() {
    _workTimer?.cancel();
    _workTimer = null;
  }

  void startBreak() {
    stopBreak(); // reset timer istirahat
    var remaining = _breakDuration;

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remaining > Duration.zero) {
        remaining -= const Duration(seconds: 1);
        onBreakTick?.call(remaining);
      } else {
        stopBreak();
        onBreakFinish?.call();
      }
    });
  }

  void stopBreak() {
    _breakTimer?.cancel();
    _breakTimer = null;
  }

  void dispose() {
    stopWork();
    stopBreak();
  }
}
