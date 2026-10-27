// Bluetooth SIG Heart Rate Service (0x180D), characteristic Heart Rate
// Measurement (0x2A37, notify only). The native side forwards the raw
// bytes; they are decoded here so the format is tested in pure Dart.
//
// byte 0, flags:
//   bit 0    0 = heart rate is uint8 (byte 1), 1 = uint16 little-endian
//   bits 1–2 sensor contact: 0b11 detected, 0b10 not detected,
//            0b0x not supported
//   bit 3    an Energy Expended uint16 follows the heart rate
//   bit 4    RR-intervals follow (uint16 each, 1/1024 s)

/// Lowest and highest bpm accepted from a sensor (and by the API).
const kMinHeartRateBpm = 25;
const kMaxHeartRateBpm = 250;

class HeartRateReading {
  const HeartRateReading({
    required this.bpm,
    this.skinContact,
    this.rrIntervals = const [],
  });

  final int bpm;

  /// Null when the sensor does not report contact.
  final bool? skinContact;

  /// Beat-to-beat intervals, when the sensor sends them.
  final List<Duration> rrIntervals;

  /// Worth keeping: in range and not flagged as off the skin (a strap
  /// that slipped off keeps sending a stale or zero value).
  bool get isUsable =>
      skinContact != false &&
      bpm >= kMinHeartRateBpm &&
      bpm <= kMaxHeartRateBpm;

  @override
  bool operator ==(Object other) =>
      other is HeartRateReading &&
      other.bpm == bpm &&
      other.skinContact == skinContact &&
      _sameDurations(other.rrIntervals, rrIntervals);

  @override
  int get hashCode =>
      Object.hash(bpm, skinContact, Object.hashAll(rrIntervals));

  @override
  String toString() => 'HeartRateReading($bpm, contact: $skinContact)';

  static bool _sameDurations(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Decodes one Heart Rate Measurement value; null when it is malformed.
HeartRateReading? parseHeartRateMeasurement(List<int> bytes) {
  if (bytes.length < 2) return null;
  final flags = bytes[0];
  final wide = flags & 0x01 != 0;
  var i = 1;
  final int bpm;
  if (wide) {
    if (bytes.length < 3) return null;
    bpm = bytes[1] | (bytes[2] << 8);
    i = 3;
  } else {
    bpm = bytes[1];
    i = 2;
  }
  final contactBits = (flags >> 1) & 0x03;
  final bool? contact = contactBits & 0x02 == 0 ? null : contactBits == 0x03;
  if (flags & 0x08 != 0) i += 2; // Energy Expended
  final rr = <Duration>[];
  if (flags & 0x10 != 0) {
    for (; i + 1 < bytes.length; i += 2) {
      final value = bytes[i] | (bytes[i + 1] << 8);
      rr.add(Duration(microseconds: value * 1000000 ~/ 1024));
    }
  }
  return HeartRateReading(bpm: bpm, skinContact: contact, rrIntervals: rr);
}
