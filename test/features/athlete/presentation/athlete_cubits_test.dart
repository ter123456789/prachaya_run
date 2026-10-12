import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/features/athlete/domain/entities/shoe.dart';
import 'package:prachaya_run/features/athlete/domain/services/shoe_usage.dart';
import 'package:prachaya_run/features/athlete/presentation/bloc/gear_cubit.dart';
import 'package:prachaya_run/features/athlete/presentation/bloc/units_cubit.dart';
import 'package:prachaya_run/features/auth/domain/entities/user_profile.dart';
import 'package:prachaya_run/features/auth/domain/services/profile_validation.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/profile_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('ProfileCubit', () {
    const p = UserProfile(displayName: 'ปราชญา', birthYear: 2002);

    blocTest<ProfileCubit, ProfileState>(
      'load works without an account',
      build: () => ProfileCubit(FakeProfileRepository()..profile = p),
      act: (c) => c.load(),
      expect: () => [const ProfileState(profile: p, loaded: true)],
    );

    blocTest<ProfileCubit, ProfileState>(
      'save: saving, then saved',
      build: () => ProfileCubit(FakeProfileRepository()),
      act: (c) => c.save(p),
      expect: () => [
        const ProfileState(loaded: true, saving: true),
        const ProfileState(
          profile: p,
          loaded: true,
          result: ProfileSaveResult.saved,
        ),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'invalid fields are reported and nothing changes',
      build: () => ProfileCubit(FakeProfileRepository()),
      seed: () => const ProfileState(profile: p, loaded: true),
      act: (c) => c.save(const UserProfile(maxHrBpm: 300)),
      expect: () => [
        const ProfileState(profile: p, loaded: true, saving: true),
        const ProfileState(
          profile: p,
          loaded: true,
          result: ProfileSaveResult.invalid,
          invalid: {ProfileField.maxHrBpm},
        ),
      ],
    );
  });

  group('UnitsCubit', () {
    final settings = InMemorySettingsRepository();

    blocTest<UnitsCubit, DistanceUnit>(
      'loads and saves the unit',
      build: () => UnitsCubit(settings..unit = DistanceUnit.mi),
      act: (c) async {
        await c.load();
        await c.set(DistanceUnit.km);
      },
      expect: () => [DistanceUnit.mi, DistanceUnit.km],
      verify: (_) => expect(settings.unit, DistanceUnit.km),
    );
  });

  group('GearCubit', () {
    late InMemoryShoeRepository shoes;
    late InMemoryActivityRepository activities;
    const pegasus = Shoe(id: 's1', name: 'Pegasus', primary: true);

    setUp(() {
      shoes = InMemoryShoeRepository();
      activities = InMemoryActivityRepository();
      final a = sampleActivity();
      activities.store[a.id] = a.withShoe('s1');
    });

    blocTest<GearCubit, GearState>(
      'adding a shoe shows its mileage from linked activities',
      build: () => GearCubit(shoes, activities),
      act: (c) => c.save(pegasus),
      expect: () => [
        GearState(
          usage: [ShoeUsage(pegasus, sampleActivity().distanceMeters)],
          loaded: true,
        ),
      ],
    );

    blocTest<GearCubit, GearState>(
      'a new primary unsets the old one; delete removes it',
      build: () => GearCubit(shoes, activities),
      act: (c) async {
        await c.save(pegasus);
        await c.save(const Shoe(id: 's2', name: 'Zoom', primary: true));
        await c.delete('s2');
      },
      skip: 2,
      expect: () => [
        GearState(
          usage: [
            ShoeUsage(
              pegasus.copyWith(primary: false),
              sampleActivity().distanceMeters,
            ),
          ],
          loaded: true,
        ),
      ],
    );

    test('invalid shoes throw', () {
      final cubit = GearCubit(shoes, activities);
      addTearDown(cubit.close);
      expect(
        () => cubit.save(const Shoe(id: 'x', name: '')),
        throwsA(isA<ShoeValidationException>()),
      );
    });

    test('the state lists shoes in display order', () async {
      final cubit = GearCubit(shoes, activities);
      addTearDown(cubit.close);
      await cubit.save(const Shoe(id: 'b', name: 'B'));
      await cubit.save(pegasus);
      expect([for (final s in cubit.state.shoes) s.id], ['s1', 'b']);
      expect(
        cubit.state.usage.first.usedMeters,
        activities.store.values.first.distanceMeters,
      );
    });
  });
}
