import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/data/services/native_heart_rate_monitor.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_monitor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  const methods = MethodChannel('prachaya/heart_rate');
  const events = EventChannel('prachaya/heart_rate/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late KvStore kv;
  late List<MethodCall> calls;
  late MockStreamHandlerEventSink sink;
  String access = 'granted';

  setUp(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    kv = KvStore(db);
    calls = [];
    access = 'granted';
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return call.method == 'access' ? access : null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, s) => sink = s),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('access answers map to SensorAccess', () async {
    final monitor = NativeHeartRateMonitor(kv);
    for (final (answer, expected) in [
      ('granted', SensorAccess.granted),
      ('off', SensorAccess.bluetoothOff),
      ('unsupported', SensorAccess.unsupported),
      ('denied', SensorAccess.denied),
    ]) {
      access = answer;
      expect(await monitor.requestAccess(), expected);
    }
  });

  test('scan collects named devices and stops when cancelled', () async {
    final monitor = NativeHeartRateMonitor(kv);
    final seen = <List<HeartRateSensor>>[];
    final sub = monitor.scan().listen(seen.add);
    await pump();
    expect(calls.last.method, 'startScan');
    sink.success({
      'event': 'found',
      'id': 'A',
      'name': 'Polar H10',
      'hr': true,
    });
    sink.success({'event': 'found', 'id': 'B', 'name': '', 'hr': false});
    sink.success({'event': 'found', 'id': 'C', 'name': 'Band 9', 'hr': false});
    await pump();
    expect(seen.last.map((d) => d.name), ['Polar H10', 'Band 9']);
    expect(seen.last.first.advertisesHeartRate, isTrue);
    await sub.cancel();
    expect(calls.last.method, 'stopScan');
  });

  test('connect remembers the sensor, decodes data, reconnects next '
      'launch and forgets on disconnect', () async {
    final monitor = NativeHeartRateMonitor(kv);
    final statuses = <SensorStatus>[];
    final bpms = <int>[];
    monitor.status.listen(statuses.add);
    monitor.readings.listen((r) => bpms.add(r.bpm));
    const strap = HeartRateSensor(id: 'A', name: 'Polar H10');

    await monitor.connect(strap);
    await pump();
    expect(calls.last.method, 'connect');
    expect(calls.last.arguments, {'id': 'A', 'name': 'Polar H10'});
    sink.success({'event': 'link', 'state': 'connected'});
    sink.success({
      'event': 'data',
      'bytes': Uint8List.fromList([0x06, 142]),
    });
    await pump();
    expect(statuses.map((s) => s.link), [
      SensorLink.disconnected,
      SensorLink.connecting,
      SensorLink.connected,
    ]);
    expect(statuses.last.sensor, strap);
    expect(bpms, [142]);

    // Next launch.
    final next = NativeHeartRateMonitor(kv);
    calls.clear();
    await next.reconnect();
    expect(calls.single.arguments, {'id': 'A', 'name': 'Polar H10'});

    await next.disconnect();
    expect(calls.last.method, 'disconnect');
    expect(await kv.read('settings.hr_sensor'), isNull);
    calls.clear();
    await NativeHeartRateMonitor(kv).reconnect();
    expect(calls, isEmpty);
  });
}
