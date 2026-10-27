import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/presentation/bloc/sync/sync_cubit.dart';
import '../bloc/linked_accounts_cubit.dart';

/// Coming back to the app (often from linking in the browser): reload the
/// links, ask the server for new workouts, then pull what it has.
class LinkedAccountsListener extends StatefulWidget {
  const LinkedAccountsListener({super.key, required this.child});

  final Widget child;

  @override
  State<LinkedAccountsListener> createState() => _LinkedAccountsListenerState();
}

class _LinkedAccountsListenerState extends State<LinkedAccountsListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  Future<void> _onResume() async {
    final links = context.read<LinkedAccountsCubit>();
    final sync = context.read<SyncCubit>();
    await links.refresh();
    if (links.state.accounts.links.isNotEmpty) await sync.sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
