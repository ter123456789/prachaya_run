import 'dart:math' as math;

final math.Random _random = math.Random.secure();

/// Random (version 4) UUID, e.g. `3f2b8c1e-9d4a-4b7e-8f21-6c0d5e9a1b23`.
/// Activity ids are made on the device so they can be saved offline and
/// synced later without clashing.
String uuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
