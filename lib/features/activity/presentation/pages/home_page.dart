import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_indexed_stack.dart';
import '../../../../core/widgets/orb_button.dart';
import '../bloc/record/record_bloc.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'record_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  void _openRecorder() => Navigator.of(context).push(RecordPage.route());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: FadeIndexedStack(
        index: _index,
        children: [
          DashboardPage(
            onSeeAll: () => setState(() => _index = 1),
            onStart: _openRecorder,
          ),
          const HistoryPage(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onTab: (i) => setState(() => _index = i),
        onOrb: _openRecorder,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onTab,
    required this.onOrb,
  });

  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onOrb;

  @override
  Widget build(BuildContext context) {
    final recording = context.select((RecordBloc b) => b.state.isActive);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000C0D0B), Color(0xF00C0D0B), AppColors.background],
          stops: [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                label: 'หน้าหลัก',
                selected: index == 0,
                onTap: () => onTab(0),
              ),
              OrbButton(
                onPressed: onOrb,
                active: recording,
                tooltip: recording ? 'กลับไปที่การบันทึก' : 'เริ่มบันทึก',
              ),
              _NavIcon(
                icon: Icons.bar_chart_rounded,
                label: 'ประวัติ',
                selected: index == 1,
                onTap: () => onTab(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        iconSize: 28,
        icon: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: selected ? AppColors.lime : AppColors.textSecondary,
            ),
            duration: const Duration(milliseconds: 220),
            builder: (context, color, _) => Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}
