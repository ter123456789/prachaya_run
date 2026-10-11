/// Wall clock that can run faster than real time, so a simulated 30-minute
/// run takes 30 seconds at ×60 while time, pace and splits stay consistent.
/// At speed 1 it is plain `DateTime.now()`.
class VirtualClock {
  DateTime _realAnchor = DateTime.now();
  DateTime _virtualAnchor = DateTime.now();
  int _speed = 1;

  int get speed => _speed;

  DateTime now() =>
      _virtualAnchor.add(DateTime.now().difference(_realAnchor) * _speed);

  set speed(int value) {
    final current = now();
    _realAnchor = DateTime.now();
    _virtualAnchor = current;
    _speed = value;
  }

  /// Back to real time, dropping the time gained while sped up.
  void reset() {
    _realAnchor = _virtualAnchor = DateTime.now();
    _speed = 1;
  }
}
