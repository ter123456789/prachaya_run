import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../activity/domain/services/activity_sync.dart';
import '../../../activity/presentation/activity_refresh.dart';
import '../../../activity/presentation/bloc/sync/sync_cubit.dart';
import '../../domain/services/credentials.dart';
import '../bloc/auth_cubit.dart';

/// Sign in / sign up, or the signed-in account with sync controls.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AccountPage());

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (_, curr) => curr.failure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_failureMessage(state.failure!))),
        ),
      child: Scaffold(
        body: GlowBackground(
          glowHeight: 260,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'กลับ',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'บัญชี',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) => switch (state.status) {
                    AuthStatus.signedIn => _SignedIn(state),
                    AuthStatus.signedOut => const _SignInForm(),
                    AuthStatus.unknown => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _failureMessage(AuthFailure failure) => switch (failure) {
    AuthFailure.invalidEmail => 'รูปแบบอีเมลไม่ถูกต้อง',
    AuthFailure.passwordTooShort =>
      'รหัสผ่านต้องมีอย่างน้อย $kMinPasswordLength ตัวอักษร',
    AuthFailure.invalidCredentials => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    AuthFailure.emailTaken => 'อีเมลนี้มีบัญชีอยู่แล้ว ลองเข้าสู่ระบบแทน',
    AuthFailure.network => 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบอินเทอร์เน็ต',
    AuthFailure.unknown => 'เกิดข้อผิดพลาด ลองอีกครั้ง',
  };
}

enum _Mode { login, register }

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _mode = _Mode.login;
  var _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<AuthCubit>();
    switch (_mode) {
      case _Mode.login:
        cubit.login(_email.text, _password.text);
      case _Mode.register:
        cubit.register(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select((AuthCubit c) => c.state.busy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ซิงก์กิจกรรมข้ามเครื่อง',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        const Text(
          'ใช้แอปได้โดยไม่ต้องมีบัญชี เข้าสู่ระบบเมื่ออยากสำรองข้อมูล'
          'ขึ้นเซิร์ฟเวอร์และเปิดดูจากเครื่องอื่น กิจกรรมที่บันทึกไว้'
          'ก่อนเข้าสู่ระบบจะถูกย้ายเข้าบัญชีที่เข้าสู่ระบบ',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        PillTabs<_Mode>(
          items: _Mode.values,
          selected: _mode,
          onChanged: (mode) => setState(() => _mode = mode),
          labelOf: (mode) => switch (mode) {
            _Mode.login => 'เข้าสู่ระบบ',
            _Mode.register => 'สมัครสมาชิก',
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: _decoration('อีเมล', Icons.mail_outline_rounded),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !busy,
          obscureText: _obscure,
          autofillHints: [
            _mode == _Mode.login
                ? AutofillHints.password
                : AutofillHints.newPassword,
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: _decoration(
            'รหัสผ่าน',
            Icons.lock_outline_rounded,
            helper: _mode == _Mode.register
                ? 'อย่างน้อย $kMinPasswordLength ตัวอักษร'
                : null,
            suffix: IconButton(
              tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onLime,
                  ),
                )
              : Text(_mode == _Mode.login ? 'เข้าสู่ระบบ' : 'สร้างบัญชี'),
        ),
      ],
    );
  }

  static InputDecoration _decoration(
    String label,
    IconData icon, {
    String? helper,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.glassFill,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      helperStyle: const TextStyle(color: AppColors.textMuted),
      enabledBorder: border(AppColors.glassBorder),
      disabledBorder: border(AppColors.glassBorder),
      focusedBorder: border(AppColors.lime),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn(this.auth);

  final AuthState auth;

  Future<void> _confirmLogout(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text(
          'กิจกรรมของบัญชีนี้จะถูกซ่อนไว้ในเครื่อง และกลับมาแสดง'
          'เมื่อเข้าสู่ระบบอีกครั้ง ส่วนที่ยังไม่ได้ซิงก์ก็ยังเก็บไว้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.logout();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.onLime,
                child: Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เข้าสู่ระบบด้วย',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    Text(
                      auth.user!.email,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Row(
            children: [
              Icon(
                _syncIcon(sync),
                color: sync.lastOutcome == SyncOutcome.synced
                    ? AppColors.positive
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_syncText(sync, DateTime.now()))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: sync.syncing ? null : context.syncActivities,
          icon: const Icon(Icons.sync_rounded),
          label: Text(sync.syncing ? 'กำลังซิงก์…' : 'ซิงก์ตอนนี้'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: auth.busy ? null : () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('ออกจากระบบ'),
        ),
      ],
    );
  }

  static IconData _syncIcon(SyncState s) => switch (s.lastOutcome) {
    _ when s.syncing => Icons.sync_rounded,
    SyncOutcome.synced => Icons.cloud_done_outlined,
    SyncOutcome.offline => Icons.cloud_off_outlined,
    _ => Icons.cloud_outlined,
  };

  static String _syncText(SyncState s, DateTime now) {
    if (s.syncing) return 'กำลังซิงก์…';
    final last = s.lastSyncedAt;
    return switch (s.lastOutcome) {
      SyncOutcome.offline => 'ออฟไลน์ จะซิงก์ให้เมื่อต่อเน็ตได้',
      SyncOutcome.failed => 'ซิงก์ไม่สำเร็จ ลองอีกครั้ง',
      _ when last != null => 'ซิงก์ล่าสุด ${formatRelative(last, now)}',
      _ => 'ยังไม่ได้ซิงก์',
    };
  }
}
