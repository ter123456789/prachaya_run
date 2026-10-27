import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/content_width.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../athlete/presentation/units.dart';
import '../../domain/entities/planned_route.dart';
import '../bloc/routes_cubit.dart';
import '../route_labels.dart';
import '../widgets/route_thumbnail.dart';
import 'route_draw_page.dart';

/// Saved routes, and the way into drawing a new one.
class RouteListPage extends StatelessWidget {
  const RouteListPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const RouteListPage());

  @override
  Widget build(BuildContext context) {
    final routes = context.watch<RoutesCubit>().state.routes;
    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 60 * i++),
      child: child,
    );
    return Scaffold(
      body: GlowBackground(
        glowHeight: 240,
        child: SafeArea(
          bottom: false,
          child: EdgeFade(
            child: ContentWidth(
              builder: (context, gutters) => ListView(
                padding: gutters.copyWith(top: 4, bottom: 40),
                children: [
                  AppTopBar(
                    title: 'เส้นทางวิ่ง',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 8),
                  stagger(const _Title()),
                  const SizedBox(height: 16),
                  if (routes.isEmpty)
                    stagger(
                      const GlassCard(
                        child: Text(
                          'ยังไม่มีเส้นทาง กด "วาดเส้นทาง" แล้วลากนิ้วเป็นรูป'
                          'อะไรก็ได้บนแผนที่ ระบบจะหาเส้นทางวิ่งบนถนนจริง'
                          'ให้ได้รูปนั้น',
                          style: AppText.body,
                        ),
                      ),
                    )
                  else
                    for (final r in routes) ...[
                      stagger(_RouteTile(r)),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROUTE ART',
                style: AppText.monoLabel.copyWith(color: AppColors.secondary),
              ),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'วาดรูป แล้ววิ่งตามรูป',
                  style: AppText.headlineLg,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => Navigator.of(context).push(RouteDrawPage.route()),
          icon: const Icon(Icons.gesture_rounded, color: AppColors.lime),
          label: const Text('วาดเส้นทาง'),
        ),
      ],
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile(this.route);

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final score = route.score;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () =>
          Navigator.of(context).push(RouteDrawPage.route(route: route)),
      child: Row(
        children: [
          RouteThumbnail(route.path),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  style: AppText.headlineSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${units.distance(route.distanceMeters)} '
                  '${units.distanceUnit}',
                  style: AppText.monoLabel,
                ),
                const SizedBox(height: 2),
                Text(
                  score == null
                      ? RouteLabels.notSnapped
                      : RouteLabels.fit(score),
                  style: AppText.caption.copyWith(
                    color: score == null
                        ? AppColors.textMuted
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
