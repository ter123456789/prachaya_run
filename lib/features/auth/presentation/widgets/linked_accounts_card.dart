import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/linked_accounts.dart';
import '../bloc/linked_accounts_cubit.dart';

/// "บัญชีนาฬิกา": link a Polar (later Garmin) account and its workouts come
/// in by themselves, the way Strava receives them. Shown signed in, and only
/// for brands the server is set up for.
class LinkedAccountsCard extends StatelessWidget {
  const LinkedAccountsCard({super.key});

  static String name(LinkProvider p) => switch (p) {
    LinkProvider.polar => 'Polar',
    LinkProvider.garmin => 'Garmin',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LinkedAccountsCubit>().state;
    final providers = state.providers;
    if (providers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('บัญชีนาฬิกา', icon: Icons.watch_outlined),
            const SizedBox(height: 4),
            const Text(
              'เชื่อมบัญชีแล้วกิจกรรมที่บันทึกด้วยนาฬิกาจะเข้ามาเอง',
              style: AppText.caption,
            ),
            for (final p in providers)
              _ProviderRow(
                provider: p,
                link: state.accounts.linkOf(p),
                busy: state.busy == p,
              ),
            if (state.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'เชื่อมต่อไม่ได้ตอนนี้ ลองใหม่อีกครั้ง',
                  style: AppText.caption.copyWith(color: AppColors.negative),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.link,
    required this.busy,
  });

  final LinkProvider provider;
  final AccountLink? link;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LinkedAccountsCubit>();
    final l = link;
    final last = l?.lastImportAt;
    final subtitle = switch (l?.status) {
      null => 'ยังไม่ได้เชื่อมต่อ',
      LinkStatus.expired ||
      LinkStatus.revoked => 'การเชื่อมต่อหมดอายุ เชื่อมต่อใหม่',
      LinkStatus.ok when last == null => 'เชื่อมต่อแล้ว · รอกิจกรรมแรก',
      LinkStatus.ok =>
        'เชื่อมต่อแล้ว · นำเข้าล่าสุด ${formatRelative(last!, DateTime.now())}',
    };
    final linked = l != null && l.status == LinkStatus.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            linked ? Icons.link_rounded : Icons.link_off_rounded,
            color: linked ? AppColors.lime : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LinkedAccountsCard.name(provider), style: AppText.bodyLg),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (linked)
            TextButton(
              onPressed: () => _confirmUnlink(context, cubit),
              child: const Text('ยกเลิก'),
            )
          else
            TextButton(
              onPressed: () => cubit.link(provider),
              child: const Text('เชื่อมต่อ'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    LinkedAccountsCubit cubit,
  ) async {
    final name = LinkedAccountsCard.name(provider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.link_off_rounded, color: AppColors.negative),
        title: Text('ยกเลิกการเชื่อมต่อ $name?'),
        content: const Text(
          'กิจกรรมที่นำเข้าแล้วยังอยู่ครบ แค่จะไม่นำเข้ากิจกรรมใหม่',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยกเลิกการเชื่อมต่อ'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.unlink(provider);
  }
}
