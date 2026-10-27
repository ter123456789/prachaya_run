import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pill_tabs.dart';
import '../../activity/domain/services/location_tracker.dart';
import '../../activity/presentation/activity_refresh.dart';
import '../../activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import '../../activity/presentation/bloc/sync/sync_cubit.dart';
import '../../activity/presentation/pages/activity_detail_page.dart';
import '../../activity/presentation/pages/record_page.dart';
import '../../auth/presentation/pages/account_page.dart';
import '../../photo_share/presentation/pages/photo_overlay_page.dart';
import '../domain/entities/gps_simulation.dart';
import 'debug_cubit.dart';

/// Developer tools: fake GPS runs, sample data, sync/auth faults and
/// shortcuts to every screen.
class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key});

  static Future<void> show(BuildContext context) {
    context.read<DebugCubit>().refreshPending();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => const DebugPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DebugCubit, DebugState>(
      listenWhen: (_, curr) => curr.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
        context.refreshActivities();
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: const [
            Text(
              'เครื่องมือทดสอบ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            Text(
              'มีเฉพาะ debug build',
              style: TextStyle(color: AppColors.textMuted),
            ),
            SizedBox(height: 16),
            _GpsSection(),
            SizedBox(height: 12),
            _DataSection(),
            SizedBox(height: 12),
            _SyncSection(),
            SizedBox(height: 12),
            _ScreensSection(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(top: 8), child: child),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
  );
}

class _GpsSection extends StatelessWidget {
  const _GpsSection();

  static const _paces = [240, 330, 420, 120, 45];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DebugCubit>();
    final gps = context.select((DebugCubit c) => c.state.gps);
    void set(GpsSimulation g) => cubit.setGps(g);
    return _Section('จำลองการวิ่ง (GPS ปลอม)', [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('ใช้ GPS จำลอง'),
        subtitle: const Text('ปิด = ใช้ GPS จริงของเครื่อง'),
        value: gps.enabled,
        onChanged: (v) => set(gps.copyWith(enabled: v)),
      ),
      if (gps.enabled) ...[
        const _Label('เส้นทาง'),
        PillTabs<SimRoute>(
          items: SimRoute.values,
          selected: gps.route,
          onChanged: (r) => set(gps.copyWith(route: r)),
          labelOf: (r) => switch (r) {
            SimRoute.lumpini => 'ลุมพินี',
            SimRoute.riverside => 'ริมน้ำ',
            SimRoute.doiSuthep => 'ดอยสุเทพ',
          },
        ),
        const _Label('pace (นาที/กม.)'),
        PillTabs<int>(
          items: _paces,
          selected: _paces.contains(gps.paceSecondsPerKm)
              ? gps.paceSecondsPerKm
              : _paces[1],
          onChanged: (p) => set(gps.copyWith(paceSecondsPerKm: p)),
          labelOf: (p) => switch (p) {
            120 => 'ปั่น 30',
            45 => 'รถ 80',
            _ => '${p ~/ 60}:${(p % 60).toString().padLeft(2, '0')}',
          },
        ),
        const _Label('เร่งเวลา (นาฬิกาแอปเร่งตามด้วย)'),
        PillTabs<int>(
          items: const [1, 10, 60],
          selected: gps.speed,
          onChanged: (s) => set(gps.copyWith(speed: s)),
          labelOf: (s) => '×$s',
        ),
        const _Label('ผลขอสิทธิ์ตำแหน่ง'),
        PillTabs<LocationAccess>(
          items: LocationAccess.values,
          selected: gps.access,
          onChanged: (a) => set(gps.copyWith(access: a)),
          labelOf: (a) => switch (a) {
            LocationAccess.granted => 'อนุญาต',
            LocationAccess.denied => 'ปฏิเสธ',
            LocationAccess.deniedForever => 'ถาวร',
            LocationAccess.serviceDisabled => 'ปิด GPS',
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('สัญญาณรบกวน'),
          subtitle: const Text('GPS ส่าย ±3 ม. ความสูงขึ้นลง จุดเสีย 2%'),
          value: gps.noise,
          onChanged: (v) => set(gps.copyWith(noise: v)),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cubit.dropGpsSignal,
                icon: const Icon(Icons.gps_off_rounded),
                label: const Text('ตัดสัญญาณ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context)
                    ..pop()
                    ..push(RecordPage.route());
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('ไปบันทึก'),
              ),
            ),
          ],
        ),
      ],
    ]);
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  Future<void> _confirmClear(BuildContext context) async {
    final cubit = context.read<DebugCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างข้อมูลในเครื่อง?'),
        content: const Text(
          'ลบกิจกรรมทั้งหมดในเครื่องนี้ (ไม่ลบบน server) '
          'กิจกรรมที่ยังไม่ซิงก์จะหายถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ล้าง'),
          ),
        ],
      ),
    );
    if (ok ?? false) await cubit.clearLocal();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DebugCubit>();
    final busy = context.select((DebugCubit c) => c.state.busy);
    return _Section('ข้อมูล', [
      FilledButton.icon(
        onPressed: busy ? null : cubit.seed,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('เพิ่มกิจกรรมตัวอย่าง 10 รายการ'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : () => _confirmClear(context),
        icon: const Icon(Icons.delete_sweep_outlined),
        label: const Text('ล้างข้อมูลในเครื่อง'),
      ),
    ]);
  }
}

class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DebugCubit>();
    final state = context.watch<DebugCubit>().state;
    final sync = context.watch<SyncCubit>().state;
    return _Section('ซิงก์ / บัญชี', [
      Row(
        children: [
          Expanded(
            child: Text(
              'ค้างซิงก์ ${state.pending ?? '–'} รายการ · '
              'ผลล่าสุด ${sync.lastOutcome?.name ?? '–'}',
            ),
          ),
          IconButton(
            tooltip: 'นับใหม่',
            onPressed: cubit.refreshPending,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      FilledButton.icon(
        onPressed: sync.syncing
            ? null
            : () async {
                await context.syncActivities();
                await cubit.refreshPending();
              },
        icon: const Icon(Icons.sync_rounded),
        label: Text(sync.syncing ? 'กำลังซิงก์…' : 'ซิงก์ตอนนี้'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('จำลองออฟไลน์'),
        subtitle: const Text('ทุก request ล้มเหมือนไม่มีเน็ต'),
        value: state.offline,
        onChanged: cubit.setOffline,
      ),
      OutlinedButton.icon(
        onPressed: cubit.expireToken,
        icon: const Icon(Icons.timer_off_outlined),
        label: const Text('ให้ access token หมดอายุ'),
      ),
      OutlinedButton.icon(
        onPressed: cubit.breakSession,
        icon: const Icon(Icons.no_accounts_outlined),
        label: const Text('ทำ session เสีย (บังคับ logout)'),
      ),
    ]);
  }
}

class _ScreensSection extends StatelessWidget {
  const _ScreensSection();

  @override
  Widget build(BuildContext context) {
    final latest = context.select((DashboardCubit c) => c.state.latest);
    void go(Route<void> route) => Navigator.of(context)
      ..pop()
      ..push(route);
    return _Section('ไปหน้า', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.person_outline_rounded, size: 18),
            label: const Text('บัญชี'),
            onPressed: () => go(AccountPage.route()),
          ),
          ActionChip(
            avatar: const Icon(Icons.fiber_manual_record, size: 18),
            label: const Text('บันทึก'),
            onPressed: () => go(RecordPage.route()),
          ),
          ActionChip(
            avatar: const Icon(Icons.route_outlined, size: 18),
            label: const Text('กิจกรรมล่าสุด'),
            onPressed: latest == null
                ? null
                : () => go(ActivityDetailPage.route(latest.id)),
          ),
          ActionChip(
            avatar: const Icon(Icons.photo_outlined, size: 18),
            label: const Text('แชร์รูป'),
            onPressed: latest == null
                ? null
                : () => go(PhotoOverlayPage.route(latest)),
          ),
        ],
      ),
    ]);
  }
}
