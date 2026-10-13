import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/bento_stat.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../activity/domain/services/activity_sync.dart';
import '../../../activity/presentation/activity_refresh.dart';
import '../../../activity/presentation/bloc/history/history_cubit.dart';
import '../../../activity/presentation/bloc/sync/sync_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/credentials.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/profile_cubit.dart';

/// Sign in / sign up, or the signed-in account with profile and sync.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.register = false});

  /// Opens on the sign-up tab instead of sign-in.
  final bool register;

  static Route<void> route({bool register = false}) =>
      MaterialPageRoute(builder: (_) => AccountPage(register: register));

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  void initState() {
    super.initState();
    context.read<SyncCubit>().refreshPending();
    context.read<AuthCubit>().refreshProviders();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select((AuthCubit c) => c.state.status);
    final sync = context.watch<SyncCubit>().state;
    final online = sync.lastOutcome != SyncOutcome.offline;
    return Scaffold(
      body: GlowBackground(
        glowHeight: 240,
        child: SafeArea(
          child: EdgeFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                AppTopBar(
                  title: 'บัญชี',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    StatusPill(
                      text: 'CLOUD ENGINE',
                      mono: true,
                      dotColor: status == AuthStatus.signedIn && online
                          ? AppColors.lime
                          : AppColors.negative,
                      pulse: sync.syncing,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: switch (status) {
                    AuthStatus.signedIn => const _SignedIn(key: ValueKey('in')),
                    AuthStatus.signedOut => _SignInForm(
                      key: const ValueKey('out'),
                      register: widget.register,
                    ),
                    AuthStatus.unknown => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  },
                ),
                const SizedBox(height: 16),
                _StatusBar(signedIn: status == AuthStatus.signedIn, sync: sync),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      strong: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.devices_rounded,
              color: AppColors.lime,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ซิงก์กิจกรรมข้ามเครื่อง', style: AppText.headlineMd),
                SizedBox(height: 4),
                Text(
                  'ใช้แอปได้โดยไม่ต้องมีบัญชี เข้าสู่ระบบเมื่ออยากสำรองข้อมูล'
                  'ขึ้นเซิร์ฟเวอร์และเปิดดูจากเครื่องอื่น กิจกรรมที่บันทึกไว้'
                  'ก่อนหน้าย้ายเข้าบัญชีได้ทันทีเมื่อคุณยืนยัน',
                  style: AppText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Mode { login, register }

class _SignInForm extends StatefulWidget {
  const _SignInForm({super.key, this.register = false});

  final bool register;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late var _mode = widget.register ? _Mode.register : _Mode.login;
  var _obscure = true;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

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
    final auth = context.watch<AuthCubit>().state;
    final busy = auth.busy;
    final activities = context.select((HistoryCubit c) => c.state.activities);
    final localMeters = activities.fold<double>(
      0,
      (s, a) => s + a.distanceMeters,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FadeSlideIn(child: _Hero()),
        const SizedBox(height: 20),
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
        const Text('อีเมล', style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            suffixIcon: _email.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'ล้าง',
                    onPressed: _email.clear,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        const Text('รหัสผ่าน', style: AppText.label),
        const SizedBox(height: 6),
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
          decoration: InputDecoration(
            hintText: _mode == _Mode.register
                ? 'อย่างน้อย $kMinPasswordLength ตัวอักษร'
                : null,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: busy
                ? const SizedBox.square(
                    key: ValueKey('busy'),
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.onLime,
                    ),
                  )
                : Row(
                    key: ValueKey(_mode),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_mode == _Mode.login ? 'เข้าสู่ระบบ' : 'สร้างบัญชี'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
          ),
        ),
        if (auth.providers.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _OrDivider(),
          const SizedBox(height: 16),
          for (final p in SocialProvider.values)
            if (auth.providers.contains(p))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SocialButton(provider: p, busy: busy),
              ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: auth.failure == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _FailureCard(auth.failure!),
                ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: BentoStat(
                label: 'กิจกรรมในเครื่อง',
                icon: Icons.directions_run_rounded,
                value: '${activities.length}',
                numeric: activities.length.toDouble(),
                format: (v) => '${v.round()}',
                unit: 'รายการ',
                footer: 'พร้อมเชื่อมข้อมูล',
                footerColor: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoStat(
                label: 'ระยะสะสมค้างซิงก์',
                icon: Icons.schedule_rounded,
                value: context.units
                    .distanceValue(localMeters)
                    .toStringAsFixed(1),
                numeric: context.units.distanceValue(localMeters),
                format: (v) => v.toStringAsFixed(1),
                unit: context.units.distanceUnit,
                footer: 'บันทึกออฟไลน์ปลอดภัย',
                footerColor: AppColors.lime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Flexible(
          flex: 4,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'หรือเข้าสู่ระบบด้วย (SOCIAL SIGN-IN)',
              style: AppText.monoLabelSm,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

/// Apple's black button / a neutral Google button. The Google mark is drawn
/// as a plain "G" so no brand reds enter the palette.
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.provider, required this.busy});

  final SocialProvider provider;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final apple = provider == SocialProvider.apple;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        key: Key('social-${provider.name}'),
        style: OutlinedButton.styleFrom(
          backgroundColor: apple ? AppColors.ink : AppColors.surfaceHigh,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        onPressed: busy
            ? null
            : () {
                FocusScope.of(context).unfocus();
                context.read<AuthCubit>().signInWith(provider);
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (apple)
              const Icon(Icons.apple, size: 26)
            else
              Text(
                'G',
                style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w800),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                apple ? 'เข้าสู่ระบบด้วย Apple' : 'เข้าสู่ระบบด้วย Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard(this.failure);

  final AuthFailure failure;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (failure) {
      AuthFailure.invalidEmail => (
        'การแจ้งเตือนรูปแบบ',
        'รูปแบบอีเมลไม่ถูกต้อง กรุณาตรวจสอบชื่อผู้ใช้และโดเมนอีกครั้ง',
      ),
      AuthFailure.passwordTooShort => (
        'รหัสผ่านสั้นเกินไป',
        'รหัสผ่านต้องมีอย่างน้อย $kMinPasswordLength ตัวอักษร',
      ),
      AuthFailure.invalidCredentials => (
        'เข้าสู่ระบบไม่สำเร็จ',
        'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
      ),
      AuthFailure.emailTaken => (
        'อีเมลนี้มีบัญชีอยู่แล้ว',
        'ลองเข้าสู่ระบบแทนการสมัครสมาชิก',
      ),
      AuthFailure.network => (
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
        'ตรวจสอบอินเทอร์เน็ตแล้วลองอีกครั้ง กิจกรรมยังบันทึกในเครื่องได้ตามปกติ',
      ),
      AuthFailure.providerUnavailable => (
        'ยังเข้าสู่ระบบด้วยวิธีนี้ไม่ได้',
        'เซิร์ฟเวอร์ยังไม่ได้เปิดใช้ ลองใช้อีเมลและรหัสผ่านแทน',
      ),
      AuthFailure.unknown => ('เกิดข้อผิดพลาด', 'ลองอีกครั้งภายหลัง'),
    };
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.negative.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.negative,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.label.copyWith(color: AppColors.negative),
                ),
                Text(message, style: AppText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({super.key});

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  /// Kept so the card can still render while it fades out after sign-out.
  String _email = '';

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.negative,
        ),
        title: const Text('ลบบัญชีถาวร?'),
        content: const Text(
          'บัญชี กิจกรรม และรูปทั้งหมดจะถูกลบจากเซิร์ฟเวอร์และเครื่องนี้ '
          'กู้คืนไม่ได้',
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
            child: const Text('ลบบัญชี'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await cubit.deleteAccount();
    final failure = cubit.state.failure;
    if (failure != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              failure == AuthFailure.network
                  ? 'ต้องเชื่อมต่ออินเทอร์เน็ตเพื่อลบบัญชี'
                  : 'ลบบัญชีไม่สำเร็จ ลองอีกครั้ง',
            ),
          ),
        );
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ลบบัญชีแล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final sync = context.watch<SyncCubit>().state;
    final name = context.select(
      (ProfileCubit c) => c.state.profile.displayName,
    );
    final email = _email = auth.user?.email ?? _email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: GlassCard(
            radius: 28,
            strong: true,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.mintIce, AppColors.mint],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (name ?? email).isEmpty
                        ? '·'
                        : (name ?? email).characters.first.toUpperCase(),
                    style: AppText.headlineMd.copyWith(color: AppColors.onLime),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'นักวิ่ง Prachaya',
                        style: AppText.headlineSm,
                      ),
                      Text(
                        email,
                        style: AppText.monoLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Row(
            children: [
              Expanded(
                child: BentoStat(
                  label: 'ค้างซิงก์',
                  icon: Icons.cloud_upload_outlined,
                  value: '${sync.pending}',
                  unit: 'รายการ',
                  footer: sync.pending == 0
                      ? 'ข้อมูลตรงกับคลาวด์'
                      : 'จะส่งขึ้นเมื่อออนไลน์',
                  footerColor: sync.pending == 0
                      ? AppColors.secondary
                      : AppColors.lime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoStat(
                  label: 'ซิงก์ล่าสุด',
                  icon: Icons.history_rounded,
                  value: sync.lastSyncedAt == null
                      ? '—'
                      : formatRelative(sync.lastSyncedAt!, DateTime.now()),
                  valueStyle: AppText.metricMd,
                  footer: switch (sync.lastOutcome) {
                    SyncOutcome.offline => 'ออฟไลน์',
                    SyncOutcome.failed => 'ล้มเหลว ลองใหม่',
                    _ => 'อัตโนมัติทุกครั้งที่บันทึก',
                  },
                  footerColor:
                      sync.lastOutcome == SyncOutcome.offline ||
                          sync.lastOutcome == SyncOutcome.failed
                      ? AppColors.negative
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: sync.syncing ? null : context.syncActivities,
          icon: AnimatedRotation(
            turns: sync.syncing ? 1 : 0,
            duration: const Duration(milliseconds: 800),
            child: const Icon(Icons.sync_rounded),
          ),
          label: Text(sync.syncing ? 'กำลังซิงก์…' : 'ซิงก์ตอนนี้'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: auth.busy ? null : () => confirmLogout(context),
          icon: const Icon(Icons.logout_rounded, color: AppColors.negative),
          label: const Text('ออกจากระบบ'),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.negative),
          onPressed: auth.busy ? null : () => _confirmDelete(context),
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('ลบบัญชี'),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.signedIn, required this.sync});

  final bool signedIn;
  final SyncState sync;

  @override
  Widget build(BuildContext context) {
    final offline = sync.lastOutcome == SyncOutcome.offline;
    final (text, color, icon) = !signedIn
        ? (
            'สถานะ: ออฟไลน์ (บันทึกข้อมูลในเครื่องพร้อมซิงก์เมื่อเข้าสู่ระบบ)',
            AppColors.textMuted,
            Icons.cloud_off_outlined,
          )
        : offline
        ? (
            'สถานะ: ออฟไลน์ (บันทึกในเครื่อง จะซิงก์เมื่อต่อเน็ตได้)',
            AppColors.negative,
            Icons.cloud_off_outlined,
          )
        : (
            'สถานะ: ออนไลน์ (ซิงก์อัตโนมัติ)',
            AppColors.secondary,
            Icons.cloud_done_outlined,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          PulseDot(color: color, size: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.monoLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }
}

/// Asks before signing out, then signs out.
Future<void> confirmLogout(BuildContext context) async {
  final cubit = context.read<AuthCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.logout_rounded, color: AppColors.negative),
      title: const Text('ออกจากระบบ?'),
      content: const Text(
        'กิจกรรมของบัญชีนี้จะถูกซ่อนไว้ในเครื่อง และกลับมาแสดง'
        'เมื่อเข้าสู่ระบบอีกครั้ง ส่วนที่ยังไม่ได้ซิงก์ก็ยังเก็บไว้',
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
          child: const Text('ออกจากระบบ'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await cubit.logout();
}
