import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../activity/domain/services/calories.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/domain/services/profile_validation.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../domain/services/heart_rate_zones.dart';
import '../athlete_labels.dart';

/// Bottom sheet to edit name and body data. Saves on the device straight
/// away (works signed out) and syncs when signed in.
class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: context.read<ProfileCubit>(),
      child: const ProfileEditSheet(),
    ),
  );

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final UserProfile _initial = context.read<ProfileCubit>().state.profile;
  late final _name = TextEditingController(text: _initial.displayName ?? '');
  late final _weight = TextEditingController(text: _num(_initial.weightKg));
  late final _height = TextEditingController(text: _num(_initial.heightCm));
  late final _birthYear = TextEditingController(
    text: _initial.birthYear == null
        ? ''
        : '${buddhistYear(_initial.birthYear!)}',
  );
  late final _maxHr = TextEditingController(
    text: _initial.maxHrBpm?.toString() ?? '',
  );
  Set<ProfileField> _invalid = const {};

  static String _num(double? v) =>
      v == null ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  static double? _parseDouble(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  /// Thai users usually think in พ.ศ.; both eras are accepted.
  static int? _parseYear(String s) {
    final y = int.tryParse(s.trim());
    if (y == null) return null;
    return y > 2400 ? y - 543 : y;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_birthYear, _maxHr]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _weight, _height, _birthYear, _maxHr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<ProfileCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    await cubit.save(
      UserProfile(
        displayName: name.isEmpty ? null : name,
        weightKg: _parseDouble(_weight.text),
        heightCm: _parseDouble(_height.text),
        birthYear: _parseYear(_birthYear.text),
        maxHrBpm: int.tryParse(_maxHr.text.trim()),
      ),
    );
    final state = cubit.state;
    if (state.result == ProfileSaveResult.saved) {
      HapticFeedback.selectionClick();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์แล้ว')));
    } else if (mounted) {
      setState(() => _invalid = state.invalid);
    }
  }

  String? _error(ProfileField field, String message) =>
      _invalid.contains(field) ? message : null;

  @override
  Widget build(BuildContext context) {
    final saving = context.select((ProfileCubit c) => c.state.saving);
    final now = DateTime.now();
    final year = _parseYear(_birthYear.text);
    final entered = int.tryParse(_maxHr.text.trim());
    final estimate = year == null || entered != null
        ? null
        : resolveMaxHr(birthYear: year, today: now);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('แก้ไขข้อมูลผู้ใช้', style: AppText.headlineMd),
              ),
              CircleIconButton(
                icon: Icons.close_rounded,
                tooltip: 'ปิด',
                size: 44,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Text(
            'เก็บไว้ในเครื่อง ใช้ได้แม้ไม่มีบัญชี ซิงก์ขึ้นคลาวด์เมื่อเข้าสู่ระบบ',
            style: AppText.caption,
          ),
          const SizedBox(height: 18),
          _Field(
            label: 'ชื่อที่แสดง',
            controller: _name,
            icon: Icons.badge_outlined,
            hint: 'เช่น ปราชญา',
            maxLength: 40,
            error: _error(
              ProfileField.displayName,
              'ยาวได้ไม่เกิน 40 ตัวอักษร',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'น้ำหนัก',
                  controller: _weight,
                  icon: Icons.monitor_weight_outlined,
                  hint: '${kDefaultWeightKg.round()}',
                  suffix: 'กก.',
                  decimal: true,
                  error: _error(ProfileField.weightKg, '20–300 กก.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'ส่วนสูง',
                  controller: _height,
                  icon: Icons.height_rounded,
                  hint: '170',
                  suffix: 'ซม.',
                  decimal: true,
                  error: _error(ProfileField.heightCm, '100–250 ซม.'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'ปีเกิด (พ.ศ.)',
                  controller: _birthYear,
                  icon: Icons.cake_outlined,
                  hint: '2540',
                  error: _error(ProfileField.birthYear, 'ปีเกิดไม่ถูกต้อง'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Max HR (ถ้ารู้)',
                  controller: _maxHr,
                  icon: Icons.favorite_border_rounded,
                  hint: estimate == null ? 'bpm' : '${estimate.bpm}',
                  suffix: 'bpm',
                  error: _error(ProfileField.maxHrBpm, '100–230 bpm'),
                ),
              ),
            ],
          ),
          Text(
            estimate != null
                ? 'เว้น Max HR ว่างไว้ แอปจะใช้ ${estimate.bpm} bpm '
                      'จากสูตร Tanaka (208 − 0.7 × อายุ ${ageIn(year, now)} ปี)'
                : entered != null
                ? 'ใช้ Max HR ที่คุณกรอกแทนค่าคำนวณจากอายุ'
                : 'กรอกปีเกิดเพื่อคำนวณ Max HR และโซนหัวใจ',
            style: AppText.caption.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('บันทึกโปรไฟล์'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.suffix,
    this.maxLength,
    this.decimal = false,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final String? suffix;
  final int? maxLength;
  final bool decimal;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final numeric = maxLength == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLength: maxLength,
            keyboardType: numeric
                ? TextInputType.numberWithOptions(decimal: decimal)
                : TextInputType.name,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              prefixIcon: Icon(icon),
              suffixText: suffix,
              errorText: error,
            ),
          ),
        ],
      ),
    );
  }
}
