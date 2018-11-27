import 'dart:async';

import 'package:final_countdown/data/persistence.dart';

class FinalCountdownTimer {
  FinalCountdownTimer(
    this.duration, {
    this.frequency = const Duration(seconds: 1),
  }) {
    _init();
  }

  final Duration duration;
  final Duration frequency;
  final _controller = StreamController<Duration>();

  Duration _remaining;
  Duration get remaining => _remaining;
  Stream<Duration> get stream => _controller.stream;

  void reset([Duration resetDuration]) =>
      _remaining = resetDuration ?? duration;

  _init() {
    _remaining = duration;
    Timer.periodic(frequency, (t) {
      _controller.add(_remaining);
      _remaining -= frequency;
      if (_remaining < const Duration()) {
        t.cancel();
        _controller.close();
      }
    });
  }
}

class FinalCountdown {
  FinalCountdown(
    this.duration, {
    this.frequency = const Duration(seconds: 1),
  });

  final Duration duration;
  final Duration frequency;

  Duration _remaining;
  Duration get remaining => _remaining;

  Stream<Duration> get stream async* {
    _remaining = duration;
    while (_remaining >= const Duration()) {
      yield _remaining;
      _remaining -= frequency;
      await Future.delayed(frequency);
    }
  }
}

class PersistedFinalCountdown {
  PersistedFinalCountdown(
    this.startingDuration, {
    Duration frequency = const Duration(seconds: 1),
  }) {
    _init(startingDuration, frequency);
  }

  _init(Duration startingDuration, Duration frequency) async {
    final duration = await loadDuration(startingDuration);
    _countdown = FinalCountdownTimer(duration, frequency: frequency);

    // Add the countdown stream to the controller and delete cache when finished
    _countdown.stream.pipe(_controller).then((_) => deleteDuration());
    // Persist the countdown
    stream.listen(saveDuration);
  }

  final _controller = StreamController<Duration>.broadcast();
  final Duration startingDuration;
  FinalCountdownTimer _countdown;

  Stream<Duration> get stream => _controller.stream;
  Duration get duration => _countdown.duration;
  Duration get remaining => _countdown.remaining;

  void reset() => _countdown.reset(startingDuration);

  dispose() => _controller?.close();
}
