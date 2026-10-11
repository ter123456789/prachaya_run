import 'package:prachaya_run/core/network/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}
