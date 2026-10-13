import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/units/unit_labels.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../athlete/presentation/bloc/units_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../../domain/entities/planned_workout.dart';
import '../../domain/services/workout_plan.dart';
import '../../../reminders/presentation/bloc/reminders_cubit.dart';
import '../bloc/training_cubit.dart';
import '../bloc/workout_draft_cubit.dart';
import '../training_labels.dart';

/// Stitch 10 "สร้างตารางซ้อมใหม่": type, name and place, day and time,
/// distance and pace, and the phases derived from them.
class WorkoutSheet extends StatelessWidget {
  const WorkoutSheet({super.key});

  /// A new session on [day], or [existing] to edit it.
  static Future<void> show(
    BuildContext context, {
    DateTime? day,
    PlannedWorkout? existing,
  }) {
    final training = context.read<TrainingCubit>();
    final units = context.read<UnitsCubit>();
    final reminders = context.read<RemindersCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: training),
          BlocProvider.value(value: units),
          BlocProvider.value(value: reminders),
          BlocProvider(
            create: (_) => WorkoutDraftCubit(
              day: day ?? training.state.selectedDay,
              existing: existing,
            ),
          ),
        ],
        child: const WorkoutSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<WorkoutDraftCubit>().state;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, scroll) => Column(
          children: [
            _Header(isNew: draft.isNew),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const _Label(
                    'ประเภทการฝึกซ้อม (WORKOUT TYPES)',
                    icon: Icons.directions_run_rounded,
                  ),
                  _TypeGrid(selected: draft.workout.type),
                  const SizedBox(height: 20),
                  const _Label(
                    'ชื่อเซสชัน & สถานที่วิ่ง',
                    icon: Icons.edit_note_rounded,
                  ),
                  _NameAndPlace(workout: draft.workout, error: draft.error),
                  const SizedBox(height: 20),
                  const _Label(
                    'กำหนดวัน & เวลาซ้อม',
                    icon: Icons.edit_calendar_outlined,
                  ),
                  _When(at: draft.workout.scheduledAt),
                  if (!draft.workout.isRest) ...[
                    const SizedBox(height: 10),
                    const _ReminderRow(),
                    const SizedBox(height: 20),
                    const _Label(
                      'เป้าหมายระยะทาง & เพซ (TARGET BENTO)',
                      icon: Icons.straighten_rounded,
                    ),
                    _Targets(draft: draft),
                    const SizedBox(height: 20),
                    _Label(
                      'โครงสร้างช่วงการซ้อม (WORKOUT PHASES)',
                      icon: Icons.timeline_rounded,
                      trailing: '${draft.phases.length} ช่วงต่อเนื่อง',
                    ),
                    for (final (i, p) in draft.phases.indexed)
                      _PhaseTile(index: i + 1, phase: p),
                  ],
                  if (!draft.isNew) ...[
                    const SizedBox(height: 16),
                    const _DeleteButton(),
                  ],
                ],
              ),
            ),
            const _Actions(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
      child: Row(
        children: [
          const PulseDot(color: AppColors.lime, size: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNew ? 'สร้างตารางซ้อมใหม่' : 'แก้ไขตารางซ้อม',
                  style: AppText.headlineMd,
                ),
                const Text(
                  'กำหนดเป้าหมาย แผนระยะทาง และเพซความเร็ว',
                  style: AppText.caption,
                ),
              ],
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
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.icon, this.trailing});

  final String text;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.lime),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.monoLabel)),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.label.copyWith(color: AppColors.secondary),
            ),
        ],
      ),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected});

  final WorkoutType selected;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutDraftCubit>();
    Widget tile(WorkoutType t) => _TypeTile(
      type: t,
      selected: t == selected,
      onTap: () {
        HapticFeedback.selectionClick();
        cubit.setType(t);
      },
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(WorkoutType.easy)),
            const SizedBox(width: 10),
            Expanded(child: tile(WorkoutType.tempo)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: tile(WorkoutType.interval)),
            const SizedBox(width: 10),
            Expanded(child: tile(WorkoutType.long)),
          ],
        ),
        const SizedBox(height: 10),
        _RestTile(
          selected: selected == WorkoutType.rest,
          onTap: () => cubit.setType(WorkoutType.rest),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final WorkoutType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onLime : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.onLime.withValues(alpha: 0.12)
                      : AppColors.surface,
                ),
                child: Icon(
                  type.icon,
                  size: 22,
                  color: selected ? AppColors.onLime : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        type.label,
                        style: AppText.bodyLg.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      type.subtitle,
                      style: AppText.caption.copyWith(
                        color: selected
                            ? AppColors.onLime
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.onLime,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestTile extends StatelessWidget {
  const _RestTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onLime : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: WorkoutType.rest.label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(WorkoutType.rest.icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(
                  WorkoutType.rest.label,
                  style: AppText.bodyLg.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  WorkoutType.rest.subtitle,
                  style: AppText.label.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameAndPlace extends StatefulWidget {
  const _NameAndPlace({required this.workout, required this.error});

  final PlannedWorkout workout;
  final bool error;

  @override
  State<_NameAndPlace> createState() => _NameAndPlaceState();
}

class _NameAndPlaceState extends State<_NameAndPlace> {
  late final _title = TextEditingController(text: widget.workout.title);
  late final _place = TextEditingController(
    text: widget.workout.location ?? '',
  );

  @override
  void didUpdateWidget(_NameAndPlace old) {
    super.didUpdateWidget(old);
    // A type switch can replace the default title.
    if (widget.workout.title != _title.text) {
      _title.text = widget.workout.title;
    }
    if ((widget.workout.location ?? '') != _place.text) {
      _place.text = widget.workout.location ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutDraftCubit>();
    final recent = context.select((TrainingCubit c) => c.state.recentLocations);
    final location = widget.workout.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          maxLength: 80,
          onChanged: cubit.setTitle,
          decoration: InputDecoration(
            hintText: 'ชื่อเซสชัน',
            counterText: '',
            prefixIcon: const Icon(Icons.flag_outlined),
            errorText: widget.error && widget.workout.title.trim().isEmpty
                ? 'ใส่ชื่อเซสชัน'
                : null,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _place,
          maxLength: 80,
          onChanged: (v) => cubit.setLocation(v.trim().isEmpty ? null : v),
          decoration: const InputDecoration(
            hintText: 'สถานที่วิ่ง (ไม่บังคับ)',
            counterText: '',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final place in recent) ...[
                  AppChip(
                    label: place,
                    icon: Icons.location_on_outlined,
                    pill: true,
                    selected: place == location,
                    onTap: () => cubit.setLocation(place),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _When extends StatelessWidget {
  const _When({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutDraftCubit>();
    Future<void> pickDay() async {
      final today = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: at,
        firstDate: DateTime(today.year - 1),
        lastDate: DateTime(today.year + 2),
        helpText: 'เลือกวันซ้อม',
        cancelText: 'ยกเลิก',
        confirmText: 'ตกลง',
      );
      if (picked != null) cubit.setDay(picked);
    }

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(at),
        helpText: 'เลือกเวลาเริ่ม',
        cancelText: 'ยกเลิก',
        confirmText: 'ตกลง',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked != null) cubit.setTime(picked.hour, picked.minute);
    }

    return Row(
      children: [
        Expanded(
          child: _PickerTile(
            label: 'วันที่',
            value: formatLongDate(at),
            icon: Icons.calendar_today_outlined,
            onTap: pickDay,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PickerTile(
            label: 'เวลาเริ่ม',
            value: '${formatClock(at)} น.',
            icon: Icons.schedule_rounded,
            mono: true,
            onTap: pickTime,
          ),
        ),
      ],
    );
  }
}

/// Stitch 10 "แจ้งเตือนก่อนวิ่ง": the device-wide reminder setting, so it
/// applies to every plan on this device.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow();

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<RemindersCubit>();
    final lead = reminders.state.settings.workoutLeadMinutes;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            lead == null
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            color: lead == null ? AppColors.textMuted : AppColors.lime,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead == null
                      ? 'แจ้งเตือนก่อนวิ่ง (ปิดอยู่)'
                      : 'แจ้งเตือนก่อนวิ่ง $lead นาที',
                  style: AppText.bodyLg,
                ),
                const Text(
                  'ใช้กับทุกแผนในเครื่องนี้ ปรับได้ที่ข้อมูลผู้ใช้',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: lead != null,
            onChanged: (on) => reminders.setWorkoutLead(on ? 30 : null),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.mono = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value',
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.lime, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.caption),
                    Text(
                      value,
                      style: mono ? AppText.metricSm : AppText.bodyLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.draft});

  final WorkoutDraftState draft;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutDraftCubit>();
    final units = context.units;
    final estimate = draft.estimate;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TargetBox(
              label: 'ระยะทาง',
              tag: units.unit.latin,
              value: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    units.distance(draft.workout.distanceMeters),
                    style: AppText.metricHero.copyWith(color: AppColors.lime),
                  ),
                  const SizedBox(width: 4),
                  Text(units.distanceUnit, style: AppText.caption),
                ],
              ),
              footer: _Stepper(
                minusLabel: 'ลดระยะทาง',
                plusLabel: 'เพิ่มระยะทาง',
                onMinus: () => cubit.stepDistance(-1),
                onPlus: () => cubit.stepDistance(1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TargetBox(
              label: 'เพซเป้าหมาย',
              tag: 'PACE',
              value: Text(
                paceRange(units, draft.workout),
                style: AppText.metricMd,
              ),
              unit: 'นาที ${units.paceUnit}',
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (estimate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      color: AppColors.background,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'เวลาคาดการณ์ ',
                                style: AppText.caption,
                              ),
                              TextSpan(
                                text: '~${formatDuration(estimate)}',
                                style: AppText.metricSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _Stepper(
                    minusLabel: 'เพซเร็วขึ้น',
                    plusLabel: 'เพซช้าลง',
                    onMinus: () => cubit.stepPace(-1),
                    onPlus: () => cubit.stepPace(1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetBox extends StatelessWidget {
  const _TargetBox({
    required this.label,
    required this.tag,
    required this.value,
    this.unit,
    required this.footer,
  });

  final String label;
  final String tag;
  final Widget value;

  /// Shown under the value (the distance shows its unit inline instead).
  final String? unit;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.label)),
              Text(
                tag,
                style: AppText.monoLabel.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value,
          ),
          if (unit != null) Text(unit!, style: AppText.caption),
          const Spacer(),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String minusLabel;
  final String plusLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              height: 40,
              color: AppColors.surfaceHighest,
              child: Icon(icon, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        button(Icons.remove_rounded, minusLabel, onMinus),
        const SizedBox(width: 8),
        button(Icons.add_rounded, plusLabel, onPlus),
      ],
    );
  }
}

class _PhaseTile extends StatelessWidget {
  const _PhaseTile({required this.index, required this.phase});

  final int index;
  final WorkoutPhase phase;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: Text('$index', style: AppText.metricSm),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phase.kind.label, style: AppText.bodyLg),
                Text(
                  phaseLine(units, phase),
                  style: AppText.monoLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${units.distance(phase.distanceMeters)} ${units.distanceUnit}',
            style: AppText.metricSm,
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColors.negative),
      icon: const Icon(Icons.delete_outline),
      label: const Text('ลบตารางนี้'),
      onPressed: () async {
        final training = context.read<TrainingCubit>();
        final id = context.read<WorkoutDraftCubit>().state.workout.id;
        final navigator = Navigator.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.delete_outline, color: AppColors.negative),
            title: const Text('ลบตารางซ้อมนี้?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.negative,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ลบ'),
              ),
            ],
          ),
        );
        if (!(confirmed ?? false)) return;
        await training.delete(id);
        navigator.pop();
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final isNew = context.select((WorkoutDraftCubit c) => c.state.isNew);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(isNew ? 'บันทึกและเพิ่มลงตาราง' : 'บันทึก'),
              onPressed: () async {
                final draft = context.read<WorkoutDraftCubit>();
                final training = context.read<TrainingCubit>();
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final workout = draft.submit();
                if (workout == null) return;
                try {
                  await training.save(workout);
                } on WorkoutValidationException {
                  draft.submit();
                  return;
                }
                HapticFeedback.mediumImpact();
                navigator.pop();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        isNew ? 'เพิ่มลงตารางซ้อมแล้ว' : 'บันทึกตารางซ้อมแล้ว',
                      ),
                    ),
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}
