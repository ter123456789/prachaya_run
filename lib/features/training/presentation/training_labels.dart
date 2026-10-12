import 'package:flutter/material.dart';

import '../../athlete/presentation/units.dart';
import '../domain/entities/planned_workout.dart';
import '../domain/services/workout_plan.dart';

extension WorkoutTypeLabels on WorkoutType {
  String get label => switch (this) {
    WorkoutType.easy => 'Easy Run',
    WorkoutType.tempo => 'Tempo Run',
    WorkoutType.interval => 'Interval',
    WorkoutType.long => 'Long Run',
    WorkoutType.rest => 'Rest Day (วันพักผ่อนฟื้นฟู)',
  };

  String get subtitle => switch (this) {
    WorkoutType.easy => 'วิ่งสบายฟื้นฟู',
    WorkoutType.tempo => 'วิ่งพัฒนาความเร็ว',
    WorkoutType.interval => 'วิ่งสลับความเร็ว',
    WorkoutType.long => 'ระยะไกลฝึกความอึด',
    WorkoutType.rest => 'ฟื้นสภาพกล้ามเนื้อ',
  };

  IconData get icon => switch (this) {
    WorkoutType.easy => Icons.self_improvement_rounded,
    WorkoutType.tempo => Icons.speed_rounded,
    WorkoutType.interval => Icons.bolt_rounded,
    WorkoutType.long => Icons.route_rounded,
    WorkoutType.rest => Icons.bed_outlined,
  };
}

extension PhaseLabels on PhaseKind {
  String get label => switch (this) {
    PhaseKind.warmUp => 'อุ่นเครื่อง (Warm-up)',
    PhaseKind.main => 'ซ้อมหลัก (Main Set)',
    PhaseKind.coolDown => 'คลายกล้ามเนื้อ (Cool-down)',
  };

  String get paceHint => switch (this) {
    PhaseKind.warmUp => 'เพซเบาๆ',
    PhaseKind.main => 'เพซเป้าหมาย',
    PhaseKind.coolDown => 'จ็อกช้าๆ',
  };

  /// Short verb for the one-line plan summary.
  String get verb => switch (this) {
    PhaseKind.warmUp => 'อุ่นเครื่อง',
    PhaseKind.main => 'วิ่งคงที่',
    PhaseKind.coolDown => 'ผ่อนคลายกล้ามเนื้อ',
  };
}

/// `โซน 3-4` / `โซน 2`
String zonesLabel(int low, int high) =>
    low == high ? 'โซน $low' : 'โซน $low-$high';

/// `5'15"-5'30"` in the app's unit.
String paceRange(UnitFormat units, PlannedWorkout w) {
  final min = w.paceMinSecPerKm;
  final max = w.paceMaxSecPerKm;
  if (min == null || max == null) return '—';
  return '${units.paceFromPerKm(min)}-${units.paceFromPerKm(max)}';
}

/// `อุ่นเครื่อง 1 กม. วิ่งคงที่ 5 กม. ผ่อนคลายกล้ามเนื้อ 1 กม.`
String phaseSummary(UnitFormat units, List<WorkoutPhase> phases) => [
  for (final p in phases)
    '${p.kind.verb} ${_short(units.distanceValue(p.distanceMeters))} '
        '${units.distanceUnit}',
].join(' ');

/// `7` / `7.5` / `4.35`
String _short(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Distance as typed in plans: up to two decimals without trailing zeros.
String planDistance(UnitFormat units, double meters) =>
    _short(units.distanceValue(meters));

/// `เพซเบาๆ 6'30" • โซน 1-2`
String phaseLine(UnitFormat units, WorkoutPhase p) =>
    '${p.kind.paceHint} ${units.paceFromPerKm(p.paceSecPerKm)} • '
    '${zonesLabel(p.zoneLow, p.zoneHigh)}';
