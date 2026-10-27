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

/// Namespace for imported activities (api.md v1.6 "Stable ids").
const kImportNamespace = 'b5d2c6c4-7a3e-4f1b-9d8e-2f6a1c3b4e5d';

/// Name-based (version 5, SHA-1) UUID: the same [name] always gives the
/// same id, so importing a workout twice updates it instead of adding a
/// copy. [name] is `<source>:<external id>`.
String uuidV5(String name, {String namespace = kImportNamespace}) {
  final ns = namespace.replaceAll('-', '');
  final bytes = <int>[
    for (var i = 0; i < 32; i += 2)
      int.parse(ns.substring(i, i + 2), radix: 16),
    ..._utf8(name),
  ];
  final hash = _sha1(bytes).sublist(0, 16);
  hash[6] = (hash[6] & 0x0f) | 0x50; // version 5
  hash[8] = (hash[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// UTF-8 without dart:convert's codec classes (kept tiny and pure).
List<int> _utf8(String s) {
  final out = <int>[];
  for (final rune in s.runes) {
    if (rune < 0x80) {
      out.add(rune);
    } else if (rune < 0x800) {
      out
        ..add(0xc0 | (rune >> 6))
        ..add(0x80 | (rune & 0x3f));
    } else if (rune < 0x10000) {
      out
        ..add(0xe0 | (rune >> 12))
        ..add(0x80 | ((rune >> 6) & 0x3f))
        ..add(0x80 | (rune & 0x3f));
    } else {
      out
        ..add(0xf0 | (rune >> 18))
        ..add(0x80 | ((rune >> 12) & 0x3f))
        ..add(0x80 | ((rune >> 6) & 0x3f))
        ..add(0x80 | (rune & 0x3f));
    }
  }
  return out;
}

/// SHA-1 (FIPS 180-4), only for name-based UUIDs.
List<int> _sha1(List<int> message) {
  int rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xffffffff;
  final bitLength = message.length * 8;
  final data = [...message, 0x80];
  while (data.length % 64 != 56) {
    data.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    data.add((bitLength >> (8 * i)) & 0xff);
  }
  var h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe;
  var h3 = 0x10325476, h4 = 0xc3d2e1f0;
  final w = List<int>.filled(80, 0);
  for (var chunk = 0; chunk < data.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunk + i * 4;
      w[i] =
          (data[j] << 24) |
          (data[j + 1] << 16) |
          (data[j + 2] << 8) |
          data[j + 3];
    }
    for (var i = 16; i < 80; i++) {
      w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4;
    for (var i = 0; i < 80; i++) {
      final int f, k;
      if (i < 20) {
        f = (b & c) | (~b & d);
        k = 0x5a827999;
      } else if (i < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (i < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }
      final temp = (rotl(a, 5) + (f & 0xffffffff) + e + k + w[i]) & 0xffffffff;
      e = d;
      d = c;
      c = rotl(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
  }
  return [
    for (final h in [h0, h1, h2, h3, h4])
      for (var i = 3; i >= 0; i--) (h >> (8 * i)) & 0xff,
  ];
}
