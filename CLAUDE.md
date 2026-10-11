# Prachaya Run

Personal Strava-style tracker (run / ride / hike) in Flutter. UI text is Thai.

## Architecture (Clean Architecture, feature-first)

```
lib/
  main.dart                 # composition root: the only place that builds concrete impls
  app.dart                  # providers + MaterialApp
  core/                     # shared helpers (formatters)
    network/                # ApiClient (JSON, gzip, token refresh), TokenStore, API_BASE_URL
  features/activity/
    domain/                 # PURE DART: entities, ports, use cases
    data/                   # sqflite + geolocator implementations of the ports
      sync/                 # ActivitySyncEngine: push pending changes, pull updatedSince feed
    presentation/           # BLoC/Cubit (flutter_bloc), pages, widgets
  features/auth/            # email + password account (own JWT on rinning_API)
    domain/                 # AuthUser, AuthRepository port, credential checks
    data/                   # HttpAuthRepository
    presentation/           # AuthCubit, AccountPage (sign in/up, sync now, sign out)
  features/debug/           # debug builds only (kDebugMode in main.dart): floating bug button
    domain/                 # GpsSimulation, RouteSimulator (pure route → GPS fixes), DebugTools port
    data/                   # SimulatedLocationTracker, VirtualClock (sped-up time), DebugHttpClient
    presentation/           # DebugOverlay (draggable button), DebugPanel, DebugCubit
  features/photo_share/     # put route + stats on a photo / transparent sticker
    domain/                 # RouteShape (track → unit-box polyline), PhotoSource + ImageSink ports
    data/                   # image_picker, gal (save to gallery), share_plus
    presentation/           # PhotoOverlayCubit, overlay widget, RoutePainter, editor page
```

Rules (enforced for every feature by `test/architecture_test.dart`):
- `domain/` imports no packages (not even flutter/equatable) and nothing from `data/` or `presentation/`.
- `presentation/` never imports `data/`, `core/network/` or plugin packages (sqflite, geolocator,
  image_picker, gal, share_plus, http, flutter_secure_storage) — it depends on domain ports
  injected via `RepositoryProvider` from `app.dart`.
- Cross-feature imports go to the same layer or inward (photo_share → activity domain entities
  and activity presentation labels), never outward.
- DB rows ↔ entities mapping lives only in `data/models/activity_row_mapper.dart`; API JSON ↔
  entities only in `data/models/activity_json_mapper.dart`.
- Add a use case only when it holds logic (e.g. `SaveActivity` validates distance).
  Simple reads/deletes go straight from cubit to the repository port.

## Backend sync
- Server: `rinning_API` (Hono). Contract source of truth: `../rinning_API/docs/api.md` — change it
  first, then both sides. Base URL via `--dart-define=API_BASE_URL=...` (default
  `http://localhost:3000`; Android emulator: `http://10.0.2.2:3000`, cleartext allowed in debug only).
- Offline-first: `OfflineFirstActivityRepository` always writes SQLite, then schedules a sync.
  Activity ids are client UUIDs (`uuidV4`). An account is optional; signed out, nothing is sent.
- Rows are scoped by `owner_id`: an account sees its own rows plus unclaimed ones (recorded signed
  out, `owner_id IS NULL`), which its next sync claims. Other accounts' rows stay on disk, hidden.
- DB v2 columns: `updated_at` (last-write-wins), `deleted_at` (tombstone until DELETE succeeds),
  `synced`, `has_track` (pulled activities download their track when first opened).
  The pull cursor (`serverTime`) is stored per user in `sync_state`.
- Tokens live in `flutter_secure_storage`; `ApiClient` refreshes single-flight on `token_expired`
  and signs out (AuthCubit listens) when the server says `unauthorized`.

## UI
- Dark theme modelled on the "Strivo" running-app reference: near-black canvas, lime accent
  (`AppColors.lime`), frosted glass cards, top lime glow, pill tabs, centre orb button.
- Tokens in `core/theme/app_colors.dart`; theme in `core/theme/app_theme.dart`; shared widgets in
  `core/widgets/` (GlassCard, GlassStatTile, GlowBackground, CircleIconButton, PillTabs, OrbButton,
  FadeSlideIn, FadeIndexedStack).
- Font: Prompt (Thai + Latin), bundled in `assets/fonts/` (OFL).
- Launch: native splash is plain `#0C0D0B` (`flutter_native_splash` config in pubspec), then the
  animated `core/splash/SplashPage` (icon pop + ripple, route line draws, ~1.7 s) fades into
  `HomePage`. App icon from `assets/icon/app_icon.png` (`flutter_launcher_icons`).
- Motion: Android routes use `FadeForwardsPageTransitionsBuilder` (iOS keeps Cupertino swipe-back);
  home tabs cross-fade via `FadeIndexedStack` (keeps state, inactive tab goes offstage);
  dashboard sections stagger in with `FadeSlideIn`. All honour OS "remove animations".
- Maps use CARTO dark tiles (attribution: OpenStreetMap contributors, CARTO).

## State management
- `flutter_bloc` + `equatable` for states. `RecordBloc` (events), `HistoryCubit`, `ActivityDetailCubit`,
  `SyncCubit` (bumps `revision` when a sync changed data → lists reload), `AuthCubit`.
- `RecordState.segments` is a live view that grows in place; equality uses `revision`.
- `RecordState.failure` is one-shot: `copyWith` clears it unless passed again.
- Photo export: the page rasterizes its `RepaintBoundary` at 1080 px wide and hands the PNG
  render callback to the cubit. The cut-out checkerboard is preview-only (outside the boundary).
- Share image options: layouts (classic Strava-style default, glass, full, statsOnly, routeOnly),
  1–4 stats (distance, avg speed, pace, time, elevation), TH/EN labels. Background is the photo
  (or a branded opaque card without one), or "พื้นใส" cut-out: only text + route, transparent PNG,
  no shadows or glass tiles; it hides (not deletes) a chosen photo. `_render` precaches the photo first
  so a just-picked image is never exported blank.

## Commands
- `flutter analyze` — must be clean
- `flutter test` — domain, mapper, bloc (`bloc_test`), widget and architecture tests; DB migration and
  sync tests run on `sqflite_common_ffi` against an in-memory fake of the API (`test/helpers/fake_server.dart`)
