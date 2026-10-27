import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/bento_stat.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../athlete/presentation/units.dart';
import '../../domain/entities/guest_data_summary.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/guest_data_repository.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/guest_link_cubit.dart';

/// Stitch 07.1 "ยืนยันการผูกบัญชี": shown once after a sign-in when this
/// device holds data recorded signed out. Merge it into the account, keep
/// it on this device only, or back out (signs out again).
class GuestLinkSheet extends StatelessWidget {
  const GuestLinkSheet({super.key});

  /// Returns once the user has chosen. Asks nothing when there is no
  /// guest data.
  static Future<void> showIfNeeded(
    BuildContext context,
    GuestDataRepository guest,
  ) async {
    final cubit = GuestLinkCubit(guest);
    await cubit.load();
    if (!context.mounted || cubit.state.summary.isEmpty) {
      await cubit.close();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const GuestLinkSheet()),
    );
    await cubit.close();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GuestLinkCubit>().state;
    final auth = context.watch<AuthCubit>().state;
    final user = auth.user;
    final working = state.status == GuestLinkStatus.working;
    return BlocListener<GuestLinkCubit, GuestLinkState>(
      listenWhen: (_, curr) => curr.isDone,
      listener: (context, _) => Navigator.of(context).pop(),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.94,
        maxChildSize: 0.94,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Center(
              child: StatusPill(
                text: 'ตรวจพบข้อมูลในเครื่อง • LOCAL DATA FOUND',
                dotColor: AppColors.lime,
                color: AppColors.lime,
                mono: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ผูกและโอนย้ายข้อมูลเข้าบัญชี',
              textAlign: TextAlign.center,
              style: AppText.headlineLg,
            ),
            const SizedBox(height: 8),
            const Text(
              'เครื่องนี้มีข้อมูลที่บันทึกไว้ตอนยังไม่ได้เข้าสู่ระบบ '
              'เลือกได้ว่าจะรวมเข้าบัญชีนี้ หรือเก็บไว้ในเครื่องนี้ต่อไป',
              textAlign: TextAlign.center,
              style: AppText.bodyLg,
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              child: _Migration(
                provider: auth.method,
                email: user?.email ?? '',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'สรุปข้อมูลที่จะถูกรวม',
                    style: AppText.monoLabel,
                  ),
                ),
                Text(
                  _extras(state.summary),
                  style: AppText.monoLabel.copyWith(color: AppColors.lime),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _Totals(summary: state.summary),
            ),
            const SizedBox(height: 16),
            const _Assurance(),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('guest-merge'),
              onPressed: working || user == null
                  ? null
                  : () => context.read<GuestLinkCubit>().merge(user.id),
              icon: const Icon(Icons.merge_rounded),
              label: const Text('ยืนยันการผูกและรวมข้อมูล'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('guest-keep'),
              onPressed: working
                  ? null
                  : context.read<GuestLinkCubit>().keepOnDevice,
              icon: const Icon(Icons.phonelink_lock_rounded),
              label: const Text('ไม่รวม เก็บไว้ในเครื่องนี้'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: working
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      await context.read<AuthCubit>().logout();
                      navigator.pop();
                    },
              child: const Text('ยกเลิก / ออกจากระบบ'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shoes, plans, routes and profile also move, shown as a short note.
  static String _extras(GuestDataSummary s) => [
    if (s.shoeCount > 0) 'รองเท้า ${s.shoeCount}',
    if (s.workoutCount > 0) 'แผน ${s.workoutCount}',
    if (s.routeCount > 0) 'เส้นทาง ${s.routeCount}',
    if (s.hasProfile) 'โปรไฟล์',
  ].join(' • ');
}

class _Migration extends StatelessWidget {
  const _Migration({required this.provider, required this.email});

  final SocialProvider? provider;
  final String email;

  @override
  Widget build(BuildContext context) {
    final (accountName, accountIcon) = switch (provider) {
      SocialProvider.apple => ('Apple ID', Icons.apple),
      SocialProvider.google => ('Google', Icons.account_circle_outlined),
      null => ('บัญชีอีเมล', Icons.account_circle_outlined),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('ปลายทางของข้อมูล', style: AppText.monoLabelSm),
              ),
              Icon(Icons.verified_outlined, color: AppColors.mint, size: 18),
              SizedBox(width: 4),
              Text('พร้อมเชื่อมต่อ', style: TextStyle(color: AppColors.mint)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: _Endpoint(
                  icon: Icons.smartphone_rounded,
                  caption: 'LOCAL',
                  title: 'Guest Mode',
                  detail: 'ข้อมูลบนเครื่องนี้',
                ),
              ),
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: AppColors.lime,
                ),
              ),
              Expanded(
                child: _Endpoint(
                  icon: accountIcon,
                  caption: 'CLOUD',
                  captionColor: AppColors.lime,
                  title: accountName,
                  detail: email,
                  detailColor: AppColors.mint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.icon,
    required this.caption,
    required this.title,
    required this.detail,
    this.captionColor = AppColors.textMuted,
    this.detailColor = AppColors.textMuted,
  });

  final IconData icon;
  final String caption;
  final String title;
  final String detail;
  final Color captionColor;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const Spacer(),
              Flexible(
                child: Text(
                  caption,
                  style: AppText.monoLabelSm.copyWith(color: captionColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppText.headlineSm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            detail,
            style: AppText.monoLabelSm.copyWith(color: detailColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final GuestDataSummary summary;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final hours = summary.movingTime.inMinutes ~/ 60;
    final minutes = summary.movingTime.inMinutes % 60;
    final bests = summary.bests;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BentoStat(
                label: 'กิจกรรมในเครื่อง',
                icon: Icons.directions_run_rounded,
                value: '${summary.activityCount}',
                unit: 'รายการ',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoStat(
                label: 'ระยะทางสะสม',
                icon: Icons.route_rounded,
                value: units
                    .distanceValue(summary.distanceMeters)
                    .toStringAsFixed(1),
                unit: units.distanceUnit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BentoStat(
                label: 'เวลาวิ่งรวม',
                icon: Icons.timer_outlined,
                value: '$hours:${minutes.toString().padLeft(2, '0')}',
                unit: 'ชม.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoStat(
                label: 'สถิติ PB สูงสุด',
                icon: Icons.military_tech_outlined,
                value: bests.isEmpty ? '—' : '5K ${_time(bests.fiveK)}',
                valueStyle: AppText.metricSm,
                footer: bests.isEmpty
                    ? 'ยังไม่มีวิ่งถึง 5 กม.'
                    : '10K ${_time(bests.tenK)}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _time(Duration? d) => d == null ? '—' : formatDuration(d);
}

class _Assurance extends StatelessWidget {
  const _Assurance();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.mint),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ข้อมูลไม่สูญหาย', style: AppText.label),
                SizedBox(height: 2),
                Text(
                  'รวมแล้วจะซิงก์ขึ้นเซิร์ฟเวอร์ผ่านการเชื่อมต่อที่เข้ารหัส '
                  'และเปิดดูได้จากทุกเครื่องที่เข้าสู่ระบบ ถ้าไม่รวม ข้อมูลจะอยู่'
                  'ในเครื่องนี้และกลับมาแสดงเมื่อออกจากระบบ',
                  style: AppText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
