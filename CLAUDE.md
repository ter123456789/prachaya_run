# Prachaya Run

Personal Strava-style tracker (run / ride / hike) in Flutter. UI text is Thai.

## Architecture (Clean Architecture, feature-first)

```
lib/
  main.dart                 # composition root: the only place that builds concrete impls
  app.dart                  # providers + MaterialApp
  core/                     # shared helpers (formatters)
  features/activity/
    domain/                 # PURE DART: entities, ports, use cases
    data/                   # sqflite + geolocator implementations of the ports
    presentation/           # BLoC/Cubit (flutter_bloc), pages, widgets
  features/photo_share/     # put route + stats on a photo / transparent sticker
    domain/                 # RouteShape (track → unit-box polyline), PhotoSource + ImageSink ports
    data/                   # image_picker, gal (save to gallery), share_plus
    presentation/           # PhotoOverlayCubit, overlay widget, RoutePainter, editor page
```

Rules (enforced for every feature by `test/architecture_test.dart`):
- `domain/` imports no packages (not even flutter/equatable) and nothing from `data/` or `presentation/`.
- `presentation/` never imports `data/` or plugin packages (sqflite, geolocator, image_picker, gal,
  share_plus) — it depends on domain ports injected via `RepositoryProvider` from `app.dart`.
- Cross-feature imports go to the same layer or inward (photo_share → activity domain entities
  and activity presentation labels), never outward.
- DB rows ↔ entities mapping lives only in `data/models/activity_row_mapper.dart`.
- Add a use case only when it holds logic (e.g. `SaveActivity` validates distance).
  Simple reads/deletes go straight from cubit to the repository port.

## UI
- Dark theme modelled on the "Strivo" running-app reference: near-black canvas, lime accent
  (`AppColors.lime`), frosted glass cards, top lime glow, pill tabs, centre orb button.
- Tokens in `core/theme/app_colors.dart`; theme in `core/theme/app_theme.dart`; shared widgets in
  `core/widgets/` (GlassCard, GlassStatTile, GlowBackground, CircleIconButton, PillTabs, OrbButton).
- Font: Prompt (Thai + Latin), bundled in `assets/fonts/` (OFL).
- Maps use CARTO dark tiles (attribution: OpenStreetMap contributors, CARTO).

## State management
- `flutter_bloc` + `equatable` for states. `RecordBloc` (events), `HistoryCubit`, `ActivityDetailCubit`.
- `RecordState.segments` is a live view that grows in place; equality uses `revision`.
- `RecordState.failure` is one-shot: `copyWith` clears it unless passed again.
- Photo export: the page rasterizes its `RepaintBoundary` at 1080 px wide and hands the PNG
  render callback to the cubit. With no photo the export is transparent (checkerboard is preview-only).
- Share image options: layouts (classic Strava-style default, glass, full, statsOnly, routeOnly),
  1–4 stats (distance, avg speed, pace, time, elevation), TH/EN labels, and without a photo either
  a branded card background (default, opaque) or transparent. `_render` precaches the photo first
  so a just-picked image is never exported blank.

## Commands
- `flutter analyze` — must be clean
- `flutter test` — domain, mapper, bloc (`bloc_test`), widget and architecture tests
