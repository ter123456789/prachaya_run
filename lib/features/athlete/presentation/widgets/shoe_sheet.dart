import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/units/distance_unit.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../activity/domain/services/uuid.dart';
import '../../domain/entities/shoe.dart';
import '../bloc/gear_cubit.dart';
import '../bloc/units_cubit.dart';
import '../units.dart';

/// Add or edit a shoe. Distances are typed in the app's unit and stored in
/// km / m.
class ShoeSheet extends StatefulWidget {
  const ShoeSheet({super.key, this.shoe, required this.isFirst});

  /// Null to add a new one.
  final Shoe? shoe;

  /// The first shoe is primary by default.
  final bool isFirst;

  static Future<void> show(BuildContext context, {Shoe? shoe}) {
    final gear = context.read<GearCubit>();
    final units = context.read<UnitsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: gear),
          BlocProvider.value(value: units),
        ],
        child: ShoeSheet(shoe: shoe, isFirst: gear.state.usage.isEmpty),
      ),
    );
  }

  @override
  State<ShoeSheet> createState() => _ShoeSheetState();
}

class _ShoeSheetState extends State<ShoeSheet> {
  late final DistanceUnit _unit = context.read<UnitsCubit>().state;
  late final Shoe? _shoe = widget.shoe;
  late final _name = TextEditingController(text: _shoe?.name ?? '');
  late final _model = TextEditingController(text: _shoe?.model ?? '');
  late final _lifespan = TextEditingController(
    text: _unit
        .fromMeters((_shoe?.lifespanKm ?? kDefaultShoeLifespanKm) * 1000.0)
        .round()
        .toString(),
  );
  late final _start = TextEditingController(
    text: _shoe == null || _shoe.startDistanceMeters == 0
        ? ''
        : _unit.fromMeters(_shoe.startDistanceMeters).toStringAsFixed(1),
  );
  late bool _primary = _shoe?.primary ?? widget.isFirst;
  late bool _retired = _shoe?.retired ?? false;
  bool _error = false;

  @override
  void dispose() {
    for (final c in [_name, _model, _lifespan, _start]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final gear = context.read<GearCubit>();
    final navigator = Navigator.of(context);
    final lifespan = _parse(_lifespan.text);
    final start = _start.text.trim().isEmpty ? 0.0 : _parse(_start.text);
    if (lifespan == null || start == null) {
      setState(() => _error = true);
      return;
    }
    final shoe = Shoe(
      id: _shoe?.id ?? uuidV4(),
      name: _name.text,
      model: _model.text,
      lifespanKm: (_unit.toMeters(lifespan) / 1000).round(),
      startDistanceMeters: _unit.toMeters(start),
      primary: _primary,
      retired: _retired,
    );
    try {
      await gear.save(shoe);
      HapticFeedback.selectionClick();
      navigator.pop();
    } on ShoeValidationException {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _delete() async {
    final gear = context.read<GearCubit>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.negative),
        title: const Text('ลบรองเท้าคู่นี้?'),
        content: const Text(
          'กิจกรรมเดิมยังอยู่ครบ แค่จะไม่นับระยะให้รองเท้าคู่นี้อีก',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await gear.delete(_shoe!.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _shoe == null ? 'เพิ่มรองเท้า' : 'แก้ไขรองเท้า',
                  style: AppText.headlineMd,
                ),
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
            'ระยะใช้งานนับจากกิจกรรมวิ่งและเดินป่าที่ผูกกับรองเท้าคู่นี้',
            style: AppText.caption,
          ),
          const SizedBox(height: 18),
          const Text('ชื่อรองเท้า', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'เช่น Nike Pegasus 41',
              counterText: '',
              prefixIcon: const Icon(Icons.directions_run_rounded),
              errorText: _error && _name.text.trim().isEmpty
                  ? 'ใส่ชื่อรองเท้า'
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          const Text('รุ่น / ประเภท (ไม่บังคับ)', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _model,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'เช่น Daily Trainer',
              counterText: '',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('อายุใช้งาน', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _lifespan,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: units.distanceUnit,
                        errorText: _error ? 'ตรวจสอบตัวเลข' : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('วิ่งมาแล้วก่อนเพิ่ม', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _start,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: units.distanceUnit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _primary && !_retired,
            onChanged: _retired ? null : (v) => setState(() => _primary = v),
            title: const Text('รองเท้าคู่หลัก'),
            subtitle: const Text(
              'กิจกรรมใหม่จะนับระยะให้คู่นี้อัตโนมัติ',
              style: AppText.caption,
            ),
          ),
          if (_shoe != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _retired,
              onChanged: (v) => setState(() => _retired = v),
              title: const Text('เลิกใช้แล้ว'),
              subtitle: const Text(
                'เก็บประวัติไว้ แต่ไม่นับกิจกรรมใหม่',
                style: AppText.caption,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_shoe == null ? 'เพิ่มรองเท้า' : 'บันทึก'),
          ),
          if (_shoe != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบรองเท้าคู่นี้'),
            ),
          ],
        ],
      ),
    );
  }
}
