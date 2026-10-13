import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/auth/domain/entities/guest_data_summary.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/guest_link_cubit.dart';

import '../../helpers/fakes.dart';

void main() {
  const data = GuestDataSummary(activityCount: 3, distanceMeters: 12000);

  blocTest<GuestLinkCubit, GuestLinkState>(
    'loads what the device holds',
    build: () => GuestLinkCubit(FakeGuestData(data)),
    act: (c) => c.load(),
    expect: () => [
      const GuestLinkState(status: GuestLinkStatus.ready, summary: data),
    ],
  );

  late FakeGuestData guest;
  blocTest<GuestLinkCubit, GuestLinkState>(
    'merge gives it to the account',
    build: () => GuestLinkCubit(guest = FakeGuestData(data)),
    act: (c) async {
      await c.load();
      await c.merge('u1');
    },
    skip: 1,
    expect: () => [
      const GuestLinkState(status: GuestLinkStatus.working, summary: data),
      const GuestLinkState(status: GuestLinkStatus.merged, summary: data),
    ],
    verify: (_) => expect(guest.calls, ['merge:u1']),
  );

  blocTest<GuestLinkCubit, GuestLinkState>(
    'keep on device, and a second tap does nothing',
    build: () => GuestLinkCubit(guest = FakeGuestData(data)),
    act: (c) async {
      await c.load();
      await c.keepOnDevice();
      await c.merge('u1');
    },
    skip: 2,
    expect: () => [
      const GuestLinkState(status: GuestLinkStatus.kept, summary: data),
    ],
    verify: (_) => expect(guest.calls, ['keep']),
  );
}
