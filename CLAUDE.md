# Prachaya Run

Personal Strava-style tracker (run / ride / hike) in Flutter. UI text is Thai.

## Architecture (Clean Architecture, feature-first)

```
lib/
  main.dart                 # composition root: the only place that builds concrete impls
  app.dart                  # providers + MaterialApp
  core/                     # shared helpers (formatters, Thai dates)
    network/                # ApiClient (JSON, gzip, token refresh), TokenStore, API_BASE_URL
    sync/                   # SyncParticipant port, SyncedRecordStore + RecordSyncParticipant
                            #   (generic offline-first records: shoes, planned workouts)
    units/                  # DistanceUnit (km/mi) math + Thai/Latin unit labels
  features/activity/
    domain/                 # PURE DART: entities, ports, use cases
    data/                   # sqflite + geolocator implementations of the ports
      sync/                 # ActivitySyncEngine: push pending changes, pull updatedSince feed
    presentation/           # BLoC/Cubit (flutter_bloc), pages, widgets
  features/auth/            # email + password account (own JWT on rinning_API) + the profile
    domain/                 # AuthUser, UserProfile, Auth/ProfileRepository ports, validation
    data/                   # HttpAuthRepository, LocalFirstProfileRepository, ProfileStore/ProfileSync
    presentation/           # AuthCubit, ProfileCubit, AccountPage (sign in/up, sync, sign out, delete)
  features/athlete/         # Stitch 08 profile: body data, HR zones, all-time stats, shoes, units
    domain/                 # Shoe, ShoeRepository/SettingsRepository ports, heart_rate_zones
                            #   (Tanaka), body_metrics (BMI), all_time_stats, shoe_usage
    data/                   # OfflineFirstShoeRepository, KvSettingsRepository, ShoeJsonMapper
    presentation/           # ProfilePage, GearCubit, UnitsCubit, `context.units` (UnitFormat),
                            #   HeartRateZonesCard, ProfileEditSheet, ShoeSheet
  features/training/        # Stitch 09 schedule + 10 new-workout sheet
    domain/                 # PlannedWorkout, WorkoutRepository port, workout_plan (templates,
                            #   phases, estimate, TrainingWeek, completion), CompleteWorkoutForActivity
    data/                   # OfflineFirstWorkoutRepository, WorkoutJsonMapper
    presentation/           # SchedulePage, WorkoutSheet, TrainingTeaser, TrainingCubit, WorkoutDraftCubit
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
  entities only in `data/models/activity_json_mapper.dart`. Shoes, workouts and the profile have
  their own `*_json_mapper.dart` (the record store keeps their API JSON as-is in `data`).
- Cross-feature hooks go through domain typedefs, composed in `app.dart`: `SaveActivity` takes a
  `DefaultShoe` (primary shoe for runs/hikes) and `onSaved` hooks (CompleteWorkoutForActivity).
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
- DB v4 adds `activities.shoe_id` and the `shoes` / `planned_workouts` tables (id, owner_id,
  data JSON, updated_at, deleted_at, synced — same scoping, LWW and tombstones as activities).
  The profile is in `kv` (`profile:<userId>`, `profile:local` while signed out, `_dirty` flag).
- Sync order: claimUnowned → push → pull → photos → participants (ProfileSync, /shoes, /workouts).
  503 `storage_unavailable` (server photo storage down) keeps photos queued, still syncs the
  participants, and reports the run as `failed` so it is retried.
  ProfileSync PATCHes every field when dirty (so clearing reaches the server), else GETs `/me`;
  a signed-out profile fills the account's empty fields on first sign-in. Multiple primary shoes
  (two offline devices) resolve to the most recently edited one; unknown shoeIds count as none.
- DB v3 adds `activity_photos` (offline-first photos, files named by photo id under app docs `photos/`),
  `activities.photo_count/photos_stale`, and a `kv` JSON cache (profile, challenge, weather).
- DB v2 columns: `updated_at` (last-write-wins), `deleted_at` (tombstone until DELETE succeeds),
  `synced`, `has_track` (pulled activities download their track when first opened).
  The pull cursor (`serverTime`) is stored per user in `sync_state`.
- Account deletion: `DELETE /me` (App Store requirement) from the account screen; 204 or 401 both count
  as done; local rows/files of that owner are purged. The e2e test deletes its user at the end.
- Tokens live in `flutter_secure_storage`; `ApiClient` refreshes single-flight on `token_expired`
  and signs out (AuthCubit listens) when the server says `unauthorized`.

## UI ("Obsidian Kinetic" redesign)
- Design source: Stitch export (DESIGN.md + 6 screens). Obsidian canvas, kinetic lime (`AppColors.lime`),
  mint orb gradient, frosted glass, no reds (warnings/destructive use amber `AppColors.negative`).
- Tokens: `core/theme/app_colors.dart`; type scale `core/theme/app_text.dart` (Prompt for Thai/body,
  JetBrains Mono for telemetry — Be Vietnam Pro from the spec has no Thai glyphs, so Prompt replaces it);
  theme in `core/theme/app_theme.dart` (inputs radius 18, 56 px pill buttons, switches, sheets).
- Shared widgets in `core/widgets/`: GlassCard (tappable cards spring via Pressable), BentoStat,
  CountUpText, ProgressRing, PillTabs (sliding lime thumb), AppChip, StatusPill/PulseDot, AppTopBar,
  AvatarButton, SectionHeader, FloatingDock + OrbButton, Shimmer, EdgeFade, FadeSlideIn, FadeIndexedStack.
  `features/activity/presentation/widgets/route_canvas.dart` draws the self-animating luminescent route.
- Not in the app on purpose: heart rate (no sensor; detail shows estimated calories instead),
  notification bell, place names. Profile 08 hides resting HR, VO2 Max, fitness age, sensors,
  Strava/Apple Health and route privacy; schedule 09 hides multi-week plan names, best-time
  windows and run reminders — no data source. Never show the design's sample values.
- HR zones: Max HR = user value, else Tanaka `208 − 0.7 × age` (birth year typed in พ.ศ. or ค.ศ.);
  zones 1–5 = 50–60 … 90–100 % (ceil of each lower bound, no overlap). Focus zone 2.
- Units: `UnitsCubit` (device setting in `kv`) → `context.units` everywhere (distance, pace, speed,
  splits, wind, share image). Plans store pace per km; shown per the chosen unit.
- Navigation: avatar → ProfilePage (works signed out) → sync strip / buttons → AccountPage.
  Dashboard has a "ตารางซ้อม" teaser below the latest activity → SchedulePage.
- Motion: entrance staggers, count-ups, ring/bar sweeps, sliding tabs, press springs, haptics. Every
  looping animation stops under OS "remove animations" (widget tests run with it on so pumpAndSettle ends).
- Font files in `assets/fonts/` (OFL). Launch: native splash `#0C0D0B`, then `core/splash/SplashPage`.
- Maps use CARTO dark tiles (attribution: OpenStreetMap contributors, CARTO).

## State management
- `flutter_bloc` + `equatable` for states. `RecordBloc` (events), `HistoryCubit`, `ActivityDetailCubit`,
  `SyncCubit` (bumps `revision` when a sync changed data → lists reload), `AuthCubit`.
- `RecordState.segments` is a live view that grows in place; equality uses `revision`.
- `RecordState.failure` is one-shot: `copyWith` clears it unless passed again.
- Photo export: the page rasterizes its `RepaintBoundary` at 1080 px wide and hands the PNG
  render callback to the cubit. The cut-out checkerboard is preview-only (outside the boundary).
- Weather: Open-Meteo direct (`OpenMeteoWeatherService`, no key), cached in `kv`.
- Calories: `estimateCalories` (MET) with the profile weight (`ProfileCubit`), default 65 kg.
- Share image options: logo toggle, (classic Strava-style default, glass, full, statsOnly, routeOnly),
  1–4 stats (distance, avg speed, pace, time, elevation), TH/EN labels. Background is the photo
  (or a branded opaque card without one), or "พื้นใส" cut-out: only text + route, transparent PNG,
  no shadows or glass tiles; it hides (not deletes) a chosen photo. `_render` precaches the photo first
  so a just-picked image is never exported blank.

## Commands
- `flutter analyze` — must be clean
- `flutter test` — domain, mapper, bloc (`bloc_test`), widget and architecture tests; DB migration and
  sync tests run on `sqflite_common_ffi` against an in-memory fake of the API (`test/helpers/fake_server.dart`)
- End to end on a simulator against the real backend (screenshots → `build/e2e_screenshots/`):
  `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_e2e_test.dart -d <id>`
  (add `--dart-define=API_BASE_URL=...` for another server; `--dart-define=E2E_SKIP_PHOTO=true` skips
  only the photo checks when the server's file storage is down; the test account is always deleted)
