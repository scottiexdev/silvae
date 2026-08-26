import 'dart:async';

import 'package:silvae_app/features/daily_reports/data/daily_report_repository.dart';

/// Ritenta la sincronizzazione finché la outbox non è vuota, con attesa
/// crescente fino a un massimo.
///
/// Non ascolta la connettività di sistema di proposito: sapere che esiste
/// un'interfaccia di rete non dice che l'API sia raggiungibile, mentre un
/// tentativo riuscito lo dimostra. In cantiere la differenza è concreta,
/// perché una cella agganciata senza traffico utile è la norma.
final class SyncScheduler {
  SyncScheduler(
    this._repository, {
    Duration firstRetry = const Duration(seconds: 15),
    Duration maxRetry = const Duration(minutes: 5),
  }) : _firstRetry = firstRetry,
       _maxRetry = maxRetry;

  final DailyReportRepository _repository;
  final Duration _firstRetry;
  final Duration _maxRetry;

  Timer? _timer;
  Duration? _nextRetry;
  bool _running = false;

  /// Attesa già programmata, esposta per i test.
  Duration? get pendingRetry => _nextRetry;

  /// Sincronizza subito e riarma l'attesa in base a quel che resta in coda.
  /// Una chiamata mentre un ciclo è già in corso viene ignorata: due push
  /// paralleli si contenderebbero le stesse righe della outbox.
  Future<void> syncNow() async {
    if (_running) {
      return;
    }

    _running = true;
    _cancelTimer();
    try {
      await _repository.synchronize();
    } finally {
      _running = false;
    }
    await _rearm();
  }

  Future<void> _rearm() async {
    _cancelTimer();
    if (!await _repository.hasPendingOperations()) {
      _nextRetry = null;
      return;
    }

    final delay = _nextRetry ?? _firstRetry;
    _nextRetry = _capped(delay * 2);
    _timer = Timer(delay, syncNow);
  }

  Duration _capped(Duration delay) => delay > _maxRetry ? _maxRetry : delay;

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _cancelTimer();
}
