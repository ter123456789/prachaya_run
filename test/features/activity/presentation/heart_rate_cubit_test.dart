import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_monitor.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/heart_rate/heart_rate_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  const strap = HeartRateSensor(
    id: 'AA:BB',
    name: 'Polar H10',
    advertisesHeartRate: true,
  );
  const watch = HeartRateSensor(id: 'CC:DD', name: 'Band 9');

  test('without a monitor it is unavailable and does nothing', () async {
    final cubit = HeartRateCubit(null);
    addTearDown(cubit.close);
    await cubit.start();
    await cubit.scan();
    expect(cubit.state.available, isFalse);
    expect(cubit.state.scanning, isFalse);
  });

  test('reconnects the remembered sensor on start', () async {
    final monitor = FakeHeartRateMonitor(remembered: strap);
    final cubit = HeartRateCubit(monitor);
    addTearDown(cubit.close);
    await cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect(monitor.connected, strap);
    expect(cubit.state.link, SensorLink.connecting);
    expect(cubit.state.sensor, strap);
  });

  test('scan lists heart-rate sensors first, then stops by itself', () {
    fakeAsync((async) {
      final monitor = FakeHeartRateMonitor();
      final cubit = HeartRateCubit(
        monitor,
        scanFor: const Duration(seconds: 20),
      );
      cubit.scan();
      async.flushMicrotasks();
      expect(cubit.state.access, SensorAccess.granted);
      expect(cubit.state.scanning, isTrue);
      monitor.scanning!.add([watch, strap]);
      async.flushMicrotasks();
      expect(cubit.state.found, [strap, watch]);
      async.elapse(const Duration(seconds: 21));
      expect(cubit.state.scanning, isFalse);
      expect(monitor.scanning, isNull); // cancelled
      cubit.close();
    });
  });

  test('Bluetooth off is reported and nothing is scanned', () async {
    final monitor = FakeHeartRateMonitor()..access = SensorAccess.bluetoothOff;
    final cubit = HeartRateCubit(monitor);
    addTearDown(cubit.close);
    await cubit.scan();
    expect(cubit.state.access, SensorAccess.bluetoothOff);
    expect(cubit.state.scanning, isFalse);
    expect(monitor.scanning, isNull);
  });

  test('connect, live readings, stale after 5 s, then disconnect', () {
    fakeAsync((async) {
      final monitor = FakeHeartRateMonitor();
      final cubit = HeartRateCubit(monitor)..start();
      async.flushMicrotasks();
      cubit.connect(strap);
      async.flushMicrotasks();
      monitor.emitStatus(SensorLink.connected);
      monitor.emitReading(142, contact: true);
      async.flushMicrotasks();
      expect(cubit.state.connected, isTrue);
      expect(cubit.state.bpm, 142);

      monitor.emitReading(150, contact: false);
      async.flushMicrotasks();
      expect(cubit.state.bpm, isNull);
      expect(cubit.state.skinContact, isFalse);

      monitor.emitReading(144, contact: true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 6));
      expect(cubit.state.bpm, isNull); // stale

      cubit.disconnect();
      async.flushMicrotasks();
      expect(cubit.state.sensor, isNull);
      expect(cubit.state.link, SensorLink.disconnected);
      expect(monitor.remembered, isNull);
      cubit.close();
    });
  });
}
