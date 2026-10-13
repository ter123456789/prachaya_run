import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../athlete/presentation/units.dart';
import '../pages/account_page.dart';

/// Invitations to sign up shown while signed out (Stitch 08 / 09 guest).
/// They only invite: every feature already works without an account, so
/// nothing here is locked and only real account benefits are listed.

void _openAccount(BuildContext context, {bool register = false}) =>
    Navigator.of(context).push(AccountPage.route(register: register));

/// 08 guest hero: Local Only, what an account adds, the sign-up button.
class GuestHeroCard extends StatelessWidget {
  const GuestHeroCard({super.key, this.onWhy});

  /// "ทำไมต้องมีบัญชี?": scrolls to the benefits.
  final VoidCallback? onWhy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 32,
      strong: true,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHigh,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.18),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Icon(
                Icons.phonelink_rounded,
                color: AppColors.lime,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'เข้าสู่ระบบเพื่อสำรองและซิงก์ข้อมูล',
            textAlign: TextAlign.center,
            style: AppText.headlineMd,
          ),
          const SizedBox(height: 6),
          const Text(
            'ตอนนี้คุณใช้งานแบบผู้เยี่ยมชม ทุกฟีเจอร์ใช้ได้ครบ '
            'แต่ข้อมูลการวิ่งถูกบันทึกไว้ในเครื่องนี้เท่านั้น',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _openAccount(context, register: true),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('สมัครสมาชิกหรือเข้าสู่ระบบ')),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
          if (onWhy != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onWhy,
              icon: const Icon(
                Icons.verified_user_outlined,
                color: AppColors.mint,
              ),
              label: const Text('ทำไมต้องมีบัญชี? (ดูสิทธิประโยชน์)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "ข้อมูลบนเครื่องนี้": what an account would take with it.
class DeviceDataCard extends StatelessWidget {
  const DeviceDataCard({
    super.key,
    required this.activityCount,
    required this.distanceMeters,
  });

  final int activityCount;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.save_outlined, color: AppColors.lime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ข้อมูลบนเครื่องนี้', style: AppText.label),
                    Text(
                      activityCount == 0
                          ? 'ยังไม่มีกิจกรรม'
                          : '$activityCount กิจกรรมที่บันทึกไว้ '
                                '(${units.distance(distanceMeters)} '
                                '${units.distanceUnit})',
                      style: AppText.metricSm,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.swap_vert_rounded, color: AppColors.mint),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.lime, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ไม่ต้องกังวล เมื่อเข้าสู่ระบบ คุณเลือกได้ว่าจะโอนประวัติการวิ่ง'
                    'และระยะทางเข้าบัญชี หรือเก็บไว้ในเครื่องนี้ต่อ',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit {
  const _Benefit(this.icon, this.title, this.detail, [this.tag]);

  final IconData icon;
  final String title;
  final String detail;
  final String? tag;
}

/// What an account adds. Only what the app really does with one.
const _benefits = [
  _Benefit(
    Icons.cloud_sync_outlined,
    'ซิงก์ข้อมูลข้ามเครื่อง',
    'กิจกรรม โปรไฟล์ รองเท้า และแผนซ้อม ตามไปทุกเครื่องที่เข้าสู่ระบบ',
    'ไม่สูญหาย',
  ),
  _Benefit(
    Icons.photo_library_outlined,
    'สำรองรูปภาพกิจกรรม',
    'รูปที่แนบกับกิจกรรมเก็บบนเซิร์ฟเวอร์ เปลี่ยนเครื่องก็เปิดดูได้',
  ),
  _Benefit(
    Icons.wifi_off_rounded,
    'บันทึกได้แม้ออฟไลน์',
    'ข้อมูลบันทึกในเครื่องก่อน แล้วซิงก์ให้เองเมื่อกลับมาออนไลน์',
    'Auto-Sync',
  ),
  _Benefit(
    Icons.login_rounded,
    'เข้าสู่ระบบง่าย',
    'ใช้อีเมล หรือบัญชี Apple / Google ลบบัญชีได้เองทุกเมื่อ',
  ),
];

/// 08 guest "สิทธิประโยชน์เมื่อมีบัญชี" 2×2 grid.
class GuestBenefitsGrid extends StatelessWidget {
  const GuestBenefitsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(_Benefit b) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(b.icon, color: AppColors.mint, size: 22),
              ),
              const SizedBox(width: 8),
              if (b.tag != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.limeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        b.tag!,
                        style: AppText.monoLabelSm.copyWith(
                          color: AppColors.lime,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(b.title, style: AppText.headlineSm),
          const SizedBox(height: 4),
          Text(b.detail, style: AppText.caption),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('สิทธิประโยชน์เมื่อมีบัญชี', style: AppText.label),
              ),
              Text(
                '${_benefits.length} อย่าง',
                style: AppText.monoLabel.copyWith(color: AppColors.mint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var r = 0; r < _benefits.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(_benefits[r])),
                const SizedBox(width: 12),
                Expanded(child: tile(_benefits[r + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 09 guest "Prachaya Athletic Pass": the planner works signed out; an
/// account carries the plans to every device.
class SchedulePassCard extends StatelessWidget {
  const SchedulePassCard({super.key});

  static const _points = [
    (
      'ตารางซ้อมตามไปทุกเครื่อง',
      'แผนที่สร้างและแผนที่ซ้อมเสร็จ ซิงก์ข้ามเครื่องอัตโนมัติ',
    ),
    (
      'สำรองกิจกรรมที่ซ้อมตามแผน',
      'ระยะ เพซ และเส้นทางเก็บบนเซิร์ฟเวอร์ เปลี่ยนเครื่องก็ไม่หาย',
    ),
    (
      'ข้อมูลในเครื่องไม่หาย',
      'ตอนเข้าสู่ระบบ เลือกได้ว่าจะโอนแผนที่มีอยู่เข้าบัญชีหรือไม่',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 32,
      strong: true,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: AppColors.lime,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PRACHAYA ATHLETIC PASS',
                  style: AppText.monoLabel.copyWith(color: AppColors.lime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'ซิงก์ตารางซ้อมของคุณข้ามเครื่อง',
            style: AppText.headlineMd,
          ),
          const SizedBox(height: 6),
          const Text(
            'แผนทั้งหมดบันทึกไว้ในเครื่องนี้แล้ว สมัครสมาชิก Prachaya Run ฟรี '
            'เพื่อสำรองไว้และเปิดดูจากเครื่องอื่น',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          for (final (title, detail) in _points)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.limeSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.lime,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.bodyLg),
                        Text(detail, style: AppText.monoLabelSm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openAccount(context, register: true),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: const Text('สมัครสมาชิกเพื่อซิงก์ตารางซ้อม'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openAccount(context),
            icon: const Icon(Icons.login_rounded),
            label: const Text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_rounded, color: AppColors.mint, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'ใช้เวลาไม่ถึง 1 นาที • ใช้ตารางซ้อมต่อได้ทันทีโดยไม่ต้องสมัคร',
                  style: AppText.monoLabelSm,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
