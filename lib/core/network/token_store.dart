import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens and account of the signed-in user.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  factory StoredSession.fromAuthJson(Map<String, Object?> json) {
    final user = json['user']! as Map<String, Object?>;
    return StoredSession(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
      userId: user['id']! as String,
      email: user['email']! as String,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'email': email,
  };

  static StoredSession fromJson(Map<String, Object?> json) => StoredSession(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    userId: json['userId']! as String,
    email: json['email']! as String,
  );
}

abstract interface class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

/// Keeps the session in the Keychain / Android Keystore, cached in memory.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';

  final FlutterSecureStorage _storage;
  StoredSession? _cached;
  bool _loaded = false;

  @override
  Future<StoredSession?> read() async {
    if (_loaded) return _cached;
    final raw = await _storage.read(key: _key);
    _cached = raw == null
        ? null
        : StoredSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> write(StoredSession session) async {
    _cached = session;
    _loaded = true;
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
