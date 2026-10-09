import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../domain/services/image_sink.dart';
import '../../domain/services/photo_source.dart';
import '../bloc/photo_overlay_cubit.dart';
import '../widgets/activity_overlay.dart';

/// Lets the user put the route, time and distance on top of their own photo
/// (or a transparent sticker) and save or share it.
class PhotoOverlayPage extends StatefulWidget {
  const PhotoOverlayPage({super.key});

  static Route<void> route(Activity activity) => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => PhotoOverlayCubit(
        photoSource: context.read<PhotoSource>(),
        imageSink: context.read<ImageSink>(),
        activity: activity,
      ),
      child: const PhotoOverlayPage(),
    ),
  );

  @override
  State<PhotoOverlayPage> createState() => _PhotoOverlayPageState();
}

class _PhotoOverlayPageState extends State<PhotoOverlayPage> {
  static const _exportWidth = 1080.0;

  final _canvasKey = GlobalKey();
  final _shareButtonKey = GlobalKey();

  Future<Uint8List> _render() async {
    // A just-picked photo may still be decoding; capturing now would export
    // a blank background. MemoryImage keys on the bytes, so this resolves
    // the same cached image the preview uses.
    final photo = context.read<PhotoOverlayCubit>().state.photo;
    if (photo != null) {
      await precacheImage(MemoryImage(photo), context);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) throw StateError('editor closed during export');
    final boundary =
        _canvasKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: _exportWidth / boundary.size.width,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  ShareAnchor? _shareAnchor() {
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (
      left: topLeft.dx,
      top: topLeft.dy,
      width: box.size.width,
      height: box.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PhotoOverlayCubit>();
    return BlocConsumer<PhotoOverlayCubit, PhotoOverlayState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          (curr.status == PhotoOverlayStatus.saved ||
              curr.status == PhotoOverlayStatus.failure),
      listener: (context, state) {
        final message = switch (state.failure) {
          null => 'บันทึกลงคลังรูปภาพแล้ว',
          PhotoOverlayFailure.permissionDenied =>
            'ไม่ได้รับอนุญาตให้บันทึกรูป กรุณาเปิดสิทธิ์ในการตั้งค่า',
          PhotoOverlayFailure.pickFailed => 'เปิดรูปภาพไม่สำเร็จ',
          PhotoOverlayFailure.exportFailed => 'สร้างรูปไม่สำเร็จ ลองอีกครั้ง',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return Scaffold(
          body: GlowBackground(
            glowHeight: 260,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'กลับ',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Expanded(
                          child: Text(
                            'ใส่ลงรูปภาพ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: state.frame.aspectRatio,
                          child: _Preview(
                            canvasKey: _canvasKey,
                            state: state,
                            cubit: cubit,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _Options(state: state, cubit: cubit),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.isBusy
                                  ? null
                                  : () => cubit.save(_render),
                              icon: const Icon(Icons.download),
                              label: const Text('บันทึกรูป'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: _shareButtonKey,
                              onPressed: state.isBusy
                                  ? null
                                  : () => cubit.share(
                                      _render,
                                      anchor: _shareAnchor(),
                                    ),
                              icon: state.status == PhotoOverlayStatus.exporting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.ios_share),
                              label: const Text('แชร์'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.canvasKey,
    required this.state,
    required this.cubit,
  });

  final GlobalKey canvasKey;
  final PhotoOverlayState state;
  final PhotoOverlayCubit cubit;

  @override
  Widget build(BuildContext context) {
    final photo = state.photo;
    final card = photo == null && state.background == OverlayBackground.card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Outside the boundary: shows transparency without exporting it.
          if (photo == null && !card) const _Checkerboard(),
          RepaintBoundary(
            key: canvasKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  Image(
                    image: MemoryImage(photo),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                else if (card)
                  const _CardBackground(),
                ActivityOverlay(
                  activity: cubit.activity,
                  route: cubit.route,
                  layout: state.layout,
                  stats: state.stats,
                  language: state.language,
                  showHeader: card,
                  color: _tintColor(context, state.tint),
                  // White text with a lime route, like Strava's orange line.
                  routeColor: state.tint == OverlayTint.white
                      ? AppColors.lime
                      : null,
                ),
              ],
            ),
          ),
          if (state.status == PhotoOverlayStatus.picking)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

Color _tintColor(BuildContext context, OverlayTint tint) => switch (tint) {
  OverlayTint.white => Colors.white,
  OverlayTint.black => Colors.black,
  OverlayTint.brand => AppColors.lime,
};

class _Options extends StatelessWidget {
  const _Options({required this.state, required this.cubit});

  final PhotoOverlayState state;
  final PhotoOverlayCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _GlassChip(
                  icon: Icons.photo_library_outlined,
                  label: 'เลือกรูป',
                  onPressed: () => cubit.pickPhoto(PhotoOrigin.gallery),
                ),
                const SizedBox(width: 8),
                _GlassChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'ถ่ายรูป',
                  onPressed: () => cubit.pickPhoto(PhotoOrigin.camera),
                ),
                const SizedBox(width: 8),
                if (state.photo != null)
                  _GlassChip(
                    icon: Icons.hide_image_outlined,
                    label: 'ลบรูป',
                    onPressed: cubit.removePhoto,
                  )
                else
                  _GlassChip(
                    icon: Icons.layers_clear_outlined,
                    label: 'พื้นใส',
                    selected: state.background == OverlayBackground.transparent,
                    onPressed: () => cubit.setBackground(
                      state.background == OverlayBackground.transparent
                          ? OverlayBackground.card
                          : OverlayBackground.transparent,
                    ),
                  ),
                const SizedBox(width: 16),
                for (final tint in OverlayTint.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TintSwatch(
                      color: _tintColor(context, tint),
                      selected: state.tint == tint,
                      onTap: () => cubit.setTint(tint),
                    ),
                  ),
              ],
            ),
          ),
          if (state.layout != OverlayLayout.routeOnly) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _GlassChip(
                    icon: Icons.translate,
                    label: 'EN',
                    selected: state.language == OverlayLanguage.en,
                    onPressed: () => cubit.setLanguage(
                      state.language == OverlayLanguage.en
                          ? OverlayLanguage.th
                          : OverlayLanguage.en,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final stat in OverlayStat.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _GlassChip(
                        icon: state.stats.contains(stat)
                            ? Icons.check
                            : Icons.add,
                        label: _statLabel(stat),
                        selected: state.stats.contains(stat),
                        onPressed: () => cubit.toggleStat(stat),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          PillTabs<OverlayLayout>(
            items: OverlayLayout.values,
            selected: state.layout,
            labelOf: (l) => switch (l) {
              OverlayLayout.classic => 'คลาสสิก',
              OverlayLayout.glass => 'กระจก',
              OverlayLayout.full => 'ครบ',
              OverlayLayout.statsOnly => 'ตัวเลข',
              OverlayLayout.routeOnly => 'เส้นทาง',
            },
            onChanged: cubit.setLayout,
          ),
          const SizedBox(height: 8),
          PillTabs<OverlayFrame>(
            items: OverlayFrame.values,
            selected: state.frame,
            labelOf: (f) => f.label,
            onChanged: cubit.setFrame,
          ),
        ],
      ),
    );
  }
}

String _statLabel(OverlayStat stat) => switch (stat) {
  OverlayStat.distance => 'ระยะทาง',
  OverlayStat.avgSpeed => 'ความเร็วเฉลี่ย',
  OverlayStat.pace => 'เพซ',
  OverlayStat.time => 'เวลา',
  OverlayStat.elevation => 'ขึ้นสะสม',
};

/// Branded dark backdrop for posting without a photo.
class _CardBackground extends StatelessWidget {
  const _CardBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        gradient: RadialGradient(
          center: Alignment(0, -1.3),
          radius: 1.3,
          colors: [Color(0xFFB9D27A), Color(0xFF3F5418), AppColors.background],
          stops: [0, 0.45, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1.1, 1.1),
            radius: 0.9,
            colors: [Color(0x40D4F36B), Color(0x00D4F36B)],
          ),
        ),
      ),
    );
  }
}

class _TintSwatch extends StatelessWidget {
  const _TintSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : outline,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _Checkerboard extends StatelessWidget {
  const _Checkerboard();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _CheckerPainter());
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey.shade300);
    final dark = Paint()..color = Colors.grey.shade400;
    for (var y = 0.0; y < size.height; y += cell) {
      for (
        var x = (y / cell).floor().isEven ? 0.0 : cell;
        x < size.width;
        x += cell * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onLime : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.lime : AppColors.glassFill,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.onLime : AppColors.lime,
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
