import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/import_activities.dart';
import '../activity_refresh.dart';
import '../bloc/health_import/health_import_cubit.dart';

/// Imports from Apple Health / Health Connect each time the app comes back
/// to the foreground (watch apps sync in the background), and reloads the
/// lists when something came in.
class HealthImportListener extends StatefulWidget {
  const HealthImportListener({super.key, required this.child});

  final Widget child;

  @override
  State<HealthImportListener> createState() => _HealthImportListenerState();
}

class _HealthImportListenerState extends State<HealthImportListener> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<ImportResult>? _changes;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<HealthImportCubit>();
    _lifecycle = AppLifecycleListener(onResume: cubit.importNow);
    _changes = cubit.changes.listen((_) {
      if (mounted) context.refreshActivities();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
