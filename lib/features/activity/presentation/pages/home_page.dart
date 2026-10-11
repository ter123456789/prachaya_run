import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/fade_indexed_stack.dart';
import '../../../../core/widgets/floating_dock.dart';
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
    final recording = context.select((RecordBloc b) => b.state.isActive);
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
      bottomNavigationBar: FloatingDock(
        items: const [
          DockItem(icon: Icons.home_outlined, label: 'หน้าหลัก'),
          DockItem(icon: Icons.bar_chart_rounded, label: 'ประวัติ'),
        ],
        index: _index,
        onTab: (i) => setState(() => _index = i),
        onOrb: _openRecorder,
        orbActive: recording,
        orbTooltip: recording ? 'กลับไปที่การบันทึก' : 'เริ่มบันทึก',
      ),
    );
  }
}
