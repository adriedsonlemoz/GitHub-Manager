import 'dart:collection';

// Média móvel temporal: reduz picos artificiais de chunks muito pequenos.
// Janela de 5 s com atualização visual limitada a cerca de 3 Hz.
class DownloadSpeedMeter {
  DownloadSpeedMeter(DateTime at, int bytes) {
    _points.add(_ProgressPoint(at, bytes));
    _lastRefresh = at;
  }

  final ListQueue<_ProgressPoint> _points = ListQueue<_ProgressPoint>();
  late DateTime _lastRefresh;

  bool shouldRefresh(DateTime now, {required bool finished}) =>
      finished || now.difference(_lastRefresh) >=
          const Duration(milliseconds: 350);

  double record(DateTime now, int bytes) {
    _lastRefresh = now;
    // Se a transferência recomeçar do zero, não misture amostras anteriores.
    if (_points.isNotEmpty && bytes < _points.last.bytes) _points.clear();
    _points.add(_ProgressPoint(now, bytes));
    final cutoff = now.subtract(const Duration(seconds: 5));
    // Mantém pelo menos uma amostra antiga para contar também uma pausa
    // prolongada, evitando exibir um pico enganoso na reconexão.
    while (_points.length > 2 && !_points.elementAt(1).at.isAfter(cutoff)) {
      _points.removeFirst();
    }
    final first = _points.first;
    final elapsed = now.difference(first.at).inMicroseconds / 1000000;
    if (elapsed <= 0) return 0;
    return ((bytes - first.bytes) / elapsed).clamp(0, double.infinity).toDouble();
  }
}

class _ProgressPoint {
  const _ProgressPoint(this.at, this.bytes);
  final DateTime at;
  final int bytes;
}
