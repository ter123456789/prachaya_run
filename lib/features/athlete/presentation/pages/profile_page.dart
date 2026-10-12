import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/units/distance_unit.dart';
import '../../../../core/units/unit_labels.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/bento_stat.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../activity/domain/services/activity_sync.dart';
import '../../../activity/presentation/bloc/history/history_cubit.dart';
import '../../../activity/presentation/bloc/sync/sync_cubit.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../auth/presentation/pages/account_page.dart';
import '../../domain/services/all_time_stats.dart';
import '../../domain/services/body_metrics.dart';
import '../../domain/services/heart_rate_zones.dart';
import '../../domain/services/shoe_usage.dart';
import '../athlete_labels.dart';
import '../bloc/gear_cubit.dart';
import '../bloc/units_cubit.dart';
import '../units.dart';
import '../widgets/heart_rate_zones_card.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/shoe_sheet.dart';

/// Stitch 08 "ข้อมูลผู้ใช้": who the runner is, body data and heart-rate
/// zones, lifetime totals, shoes and settings. Works without an account.
///
/// Left out on purpose (no data source in the app): resting HR, VO2 Max,
/// fitness age, connected sensors, Strava / Apple Health, route privacy.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ProfilePage());

  @override
  Widget build(BuildContext context) {
    final profile = context.select((ProfileCubit c) => c.state.profile);
    final activities = context.select((HistoryCubit c) => c.state.activities);
    final signedIn = context.select(
      (AuthCubit c) => c.state.status == AuthStatus.signedIn,
    );
    final now = DateTime.now();
    final maxHr = resolveMaxHr(
      enteredBpm: profile.maxHrBpm,
      birthYear: profile.birthYear,
      today: now,
    );
    void edit() => ProfileEditSheet.show(context);
    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 60 * i++),
      child: child,
    );
    return Scaffold(
      body: GlowBackground(
        glowHeight: 240,
        child: SafeArea(
          bottom: false,
          child: EdgeFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                AppTopBar(
                  title: 'ข้อมูลผู้ใช้',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 12),
                stagger(
                  _Header(profile: profile, signedIn: signedIn, onEdit: edit),
                ),
                const SizedBox(height: 20),
                stagger(
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'ข้อมูลสรีระ & สภาพร่างกาย',
                      style: AppText.label,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                stagger(
                  _BodyGrid(
                    profile: profile,
                    maxHr: maxHr,
                    now: now,
                    onEdit: edit,
                  ),
                ),
                const SizedBox(height: 16),
                stagger(HeartRateZonesCard(maxHr: maxHr, onSetUp: edit)),
                const SizedBox(height: 16),
                stagger(_AllTimeCard(AllTimeStats.from(activities))),
                const SizedBox(height: 16),
                stagger(const _GearCard()),
                const SizedBox(height: 16),
                stagger(const _SettingsCard()),
                const SizedBox(height: 20),
                stagger(_AccountActions(signedIn: signedIn)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.signedIn,
    required this.onEdit,
  });

  final UserProfile profile;
  final bool signedIn;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final email = context.select((AuthCubit c) => c.state.user?.email);
    final name = profile.displayName;
    final initial = (name ?? email ?? '').trim();
    return GlassCard(
      radius: 28,
      strong: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.mintIce, AppColors.mint],
                  ),
                ),
                alignment: Alignment.center,
                child: initial.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.onLime,
                        size: 30,
                      )
                    : Text(
                        initial.characters.first.toUpperCase(),
                        style: AppText.headlineMd.copyWith(
                          color: AppColors.onLime,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'นักวิ่ง Prachaya',
                      style: AppText.headlineSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email ?? 'ใช้งานในเครื่อง • ยังไม่มีบัญชี',
                      style: AppText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'แก้ไขโปรไฟล์',
                size: 40,
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SyncStrip(signedIn: signedIn),
        ],
      ),
    );
  }
}

class _SyncStrip extends StatelessWidget {
  const _SyncStrip({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncCubit>().state;
    final last = sync.lastSyncedAt;
    final problem =
        sync.lastOutcome == SyncOutcome.offline ||
        sync.lastOutcome == SyncOutcome.failed;
    final (text, color, icon, trailing) = !signedIn
        ? (
            'เก็บข้อมูลในเครื่อง',
            AppColors.textMuted,
            Icons.cloud_off_outlined,
            'เข้าสู่ระบบเพื่อซิงก์',
          )
        : sync.syncing
        ? ('กำลังซิงก์…', AppColors.lime, Icons.sync_rounded, '')
        : problem
        ? (
            sync.lastOutcome == SyncOutcome.offline
                ? 'ออฟไลน์ จะซิงก์เมื่อต่อเน็ตได้'
                : 'ซิงก์ไม่สำเร็จ ลองอีกครั้ง',
            AppColors.negative,
            Icons.cloud_off_outlined,
            '',
          )
        : sync.pending > 0
        ? (
            'รอซิงก์ ${sync.pending} รายการ',
            AppColors.lime,
            Icons.cloud_upload_outlined,
            '',
          )
        : (
            'ซิงก์คลาวด์เรียบร้อยแล้ว',
            AppColors.secondary,
            Icons.cloud_done_outlined,
            last == null ? '' : formatRelative(last, DateTime.now()),
          );
    return Pressable(
      onTap: () => Navigator.of(context).push(AccountPage.route()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            PulseDot(color: color, size: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppText.label.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 16, color: AppColors.textSecondary),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(trailing, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}

class _BodyGrid extends StatelessWidget {
  const _BodyGrid({
    required this.profile,
    required this.maxHr,
    required this.now,
    required this.onEdit,
  });

  final UserProfile profile;
  final MaxHeartRate? maxHr;
  final DateTime now;
  final VoidCallback onEdit;

  static String _num(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final weight = profile.weightKg;
    final height = profile.heightCm;
    final age = ageIn(profile.birthYear, now);
    final index = bmi(weightKg: weight, heightCm: height);
    final tiles = [
      BentoStat(
        label: 'น้ำหนัก',
        icon: Icons.monitor_weight_outlined,
        value: weight == null ? '—' : _num(weight),
        unit: weight == null ? null : 'กก.',
        footer: weight == null ? 'แตะเพื่อกรอก' : 'ใช้คำนวณแคลอรี่',
        onTap: onEdit,
      ),
      BentoStat(
        label: 'ส่วนสูง',
        icon: Icons.height_rounded,
        value: height == null ? '—' : _num(height),
        unit: height == null ? null : 'ซม.',
        footer: index == null
            ? (height == null ? 'แตะเพื่อกรอก' : 'กรอกน้ำหนักเพื่อดู BMI')
            : 'BMI ${index.toStringAsFixed(1)} • ${bmiBand(index).label}',
        onTap: onEdit,
      ),
      BentoStat(
        label: 'อายุ',
        icon: Icons.cake_outlined,
        value: age == null ? '—' : '$age',
        unit: age == null ? null : 'ปี',
        footer: profile.birthYear == null
            ? 'แตะเพื่อกรอกปีเกิด'
            : 'เกิดปี พ.ศ. ${buddhistYear(profile.birthYear!)}',
        onTap: onEdit,
      ),
      BentoStat(
        label: maxHr?.source == MaxHrSource.entered
            ? 'MAX HR (กำหนดเอง)'
            : 'MAX HR (คำนวณ)',
        icon: Icons.speed_rounded,
        value: maxHr == null ? '—' : '${maxHr!.bpm}',
        unit: maxHr == null ? null : 'bpm',
        footer: switch (maxHr?.source) {
          null => 'ต้องมีปีเกิด',
          MaxHrSource.tanaka => 'เกณฑ์ Tanaka Method',
          MaxHrSource.entered => 'ค่าที่คุณกรอก',
        },
        onTap: onEdit,
      ),
    ];
    return Column(
      children: [
        for (var r = 0; r < tiles.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: tiles[r]),
              const SizedBox(width: 12),
              Expanded(child: tiles[r + 1]),
            ],
          ),
        ],
      ],
    );
  }
}

class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard(this.stats);

  final AllTimeStats stats;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final hours = stats.movingTime.inHours;
    final minutes = stats.movingTime.inMinutes.remainder(60);
    final first = stats.firstYear;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'สถิติตลอดกาล (All-Time)',
            icon: Icons.military_tech_outlined,
            action: first == null
                ? null
                : Text(
                    '${buddhistYear(first)} - ปัจจุบัน',
                    style: AppText.monoLabel,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Figure(
                label: 'ระยะทางสะสม',
                value: units
                    .distanceValue(stats.distanceMeters)
                    .toStringAsFixed(1),
                caption: units.unit.long,
                color: AppColors.lime,
              ),
              const SizedBox(width: 12),
              _Figure(
                label: 'เวลาสะสม',
                value: '$hours:${minutes.toString().padLeft(2, '0')}',
                caption: 'ชั่วโมง : นาที',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Figure(
                label: 'จำนวนกิจกรรม',
                value: '${stats.count}',
                caption: stats.count == 0
                    ? 'ครั้ง'
                    : 'ครั้ง (วิ่ง ${(stats.runShare * 100).round()}%)',
              ),
              const SizedBox(width: 12),
              _Figure(
                label: 'เพซเฉลี่ยรวม',
                value: stats.runCount == 0
                    ? '—'
                    : units.paceQuote(stats.runAverageSpeedMps),
                caption: '/ ${units.unit.long}',
                color: AppColors.mint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.label),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppText.metricLg.copyWith(color: color),
              ),
            ),
            Text(caption, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

class _GearCard extends StatelessWidget {
  const _GearCard();

  @override
  Widget build(BuildContext context) {
    final usage = context.select((GearCubit c) => c.state.usage);
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'อุปกรณ์ & รองเท้าวิ่ง',
            icon: Icons.directions_run_rounded,
            action: TextButton.icon(
              onPressed: () => ShoeSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่มอุปกรณ์'),
            ),
          ),
          const SizedBox(height: 8),
          if (usage.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'ยังไม่มีรองเท้า เพิ่มคู่แรกแล้วแอปจะนับระยะใช้งาน'
                'จากทุกการวิ่งให้อัตโนมัติ',
                style: AppText.body,
              ),
            )
          else
            for (final u in usage) _ShoeTile(u),
        ],
      ),
    );
  }
}

class _ShoeTile extends StatelessWidget {
  const _ShoeTile(this.usage);

  final ShoeUsage usage;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final shoe = usage.shoe;
    final barColor = usage.wornOut
        ? AppColors.negative
        : shoe.retired
        ? AppColors.textMuted
        : AppColors.lime;
    return Pressable(
      onTap: () => ShoeSheet.show(context, shoe: shoe),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: shoe.retired
                        ? AppColors.surfaceHighest
                        : AppColors.limeSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_run_rounded,
                    color: shoe.retired ? AppColors.textMuted : AppColors.lime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (shoe.primary || shoe.retired)
                        Text(
                          shoe.primary ? 'รองเท้าคู่หลัก' : 'เลิกใช้แล้ว',
                          style: AppText.label.copyWith(
                            color: shoe.primary
                                ? AppColors.lime
                                : AppColors.textMuted,
                          ),
                        ),
                      Text(
                        shoe.name,
                        style: AppText.headlineSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (shoe.model != null)
                        Text(
                          shoe.model!,
                          style: AppText.monoLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusPill(
                  text: '${usage.percent}% ใช้แล้ว',
                  color: usage.wornOut
                      ? AppColors.negative
                      : AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${units.distanceValue(usage.usedMeters).toStringAsFixed(1)} '
                    '${units.distanceUnit}',
                    style: AppText.monoLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: Text(
                    'อายุใช้งาน '
                    '${units.distanceValue(shoe.lifespanKm * 1000.0).round()} '
                    '${units.distanceUnit}',
                    style: AppText.monoLabel,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: usage.fraction),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: barColor,
                  backgroundColor: AppColors.surfaceHighest,
                ),
              ),
            ),
            if (usage.wornOut)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'ครบอายุใช้งานแล้ว ควรเปลี่ยนคู่ใหม่',
                  style: AppText.caption.copyWith(color: AppColors.negative),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<UnitsCubit>().state;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('การตั้งค่า', icon: Icons.settings_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.straighten_rounded,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('หน่วยวัดระยะทาง', style: AppText.bodyLg),
                    Text(
                      'กิโลเมตร (กม.) หรือ ไมล์ (mi) ใช้ทั้งแอป',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 132,
                child: PillTabs<DistanceUnit>(
                  items: DistanceUnit.values,
                  selected: unit,
                  height: 36,
                  onChanged: context.read<UnitsCubit>().set,
                  labelOf: (u) => u.short,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    void openAccount() => Navigator.of(context).push(AccountPage.route());
    if (!signedIn) {
      return FilledButton.icon(
        onPressed: openAccount,
        icon: const Icon(Icons.cloud_sync_outlined),
        label: const Text('เข้าสู่ระบบเพื่อซิงก์ข้ามเครื่อง'),
      );
    }
    final busy = context.select((AuthCubit c) => c.state.busy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: openAccount,
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('บัญชีและซิงก์ข้อมูล'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : () => confirmLogout(context),
          icon: const Icon(Icons.logout_rounded, color: AppColors.negative),
          label: const Text('ออกจากระบบบัญชีนักวิ่ง'),
        ),
      ],
    );
  }
}
