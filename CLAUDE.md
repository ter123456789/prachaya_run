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
  features/auth/            # account (email + password, Sign in with Apple / Google; own JWT) + profile
    domain/                 # AuthUser, UserProfile, GuestDataSummary, Auth/Profile/GuestDataRepository
    data/                   # HttpAuthRepository, SocialCredentialSource (plugins), LocalFirstProfileRepository,
                            #   ProfileStore/ProfileSync
    presentation/           # AuthCubit, ProfileCubit, GuestLinkCubit, AccountPage (07), GuestLinkSheet (07.1),
                            #   guest_widgets (08/09 guest invites)
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
  features/reminders/       # local notifications: plan reminders, weekly goal, 06:00 weather
    domain/                 # Reminder(Target), ReminderSettings, ReminderScheduler/SettingsRepository ports,
                            #   reminder_plan (due times, ids, goal crossing, next morning)
    data/                   # LocalNotificationScheduler (flutter_local_notifications), KvReminderSettingsRepository
    presentation/           # RemindersCubit, ReminderCoordinator + ReminderTexts, ReminderListeners (app-level)
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
- Plugin wrappers stay in `data/` (architecture_test also bans flutter_local_notifications, timezone,
  flutter_tts, sign_in_with_apple and google_sign_in from presentation).
- Add a use case only when it holds logic (e.g. `SaveActivity` validates distance).
  Simple reads/deletes go straight from cubit to the repository port.

## Backend sync
- Server: `rinning_API` (Hono). Contract source of truth: `../rinning_API/docs/api.md` — change it
  first, then both sides. Base URL via `--dart-define=API_BASE_URL=...` (default
  `http://localhost:3000`; Android emulator: `http://10.0.2.2:3000`, cleartext allowed in debug only).
- Offline-first: `OfflineFirstActivityRepository` always writes SQLite, then schedules a sync.
  Activity ids are client UUIDs (`uuidV4`). An account is optional; signed out, nothing is sent.
- Rows are scoped by `owner_id`: an account sees its own rows plus unclaimed ones (recorded signed
  out, `owner_id IS NULL`). Other accounts' rows stay on disk, hidden.
- Sync never claims unowned rows by itself. After a sign-in with data on the device, `app.dart` shows
  `GuestLinkSheet` (Stitch 07.1, `DeviceGuestData`). **Merge** calls `ActivitySyncEngine.claimGuestData`
  (activities, photos, profile, shoes, plans) and syncs. **Keep** parks the rows under
  `owner_id = '~device'` and the profile under `profile:device-only`, so the account doesn't see or
  send them; signing out restores them. **Cancel** signs out. The summary shows count, distance,
  time and PB 5K/10K (`best_efforts.dart`, from the tracks).
- Sign in with Apple / Google (api.md v1.3): `POST /auth/apple` / `/auth/google` with the provider's ID token.
  A button shows only when the device supports the provider and the server answers a junk-token probe
  with 401, not 503 `provider_not_configured`. The probe runs on launch and when AccountPage opens.
  Google also needs `--dart-define=GOOGLE_CLIENT_ID` / `GOOGLE_SERVER_CLIENT_ID`. Production has no
  client ids yet (`APPLE_CLIENT_IDS` / `GOOGLE_CLIENT_IDS` on Railway), so no buttons show.
  - To enable Apple: set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` for Runner. It is left
    out because a team without the capability can't sign device builds.
  - For Google on iOS: also add `GIDClientID` and the reversed-client-id URL scheme to Info.plist.
  - 503 `provider_not_configured` shows as "not available"; 503 `provider_unavailable` is retryable.
- DB v4 adds `activities.shoe_id` and the `shoes` / `planned_workouts` tables (id, owner_id,
  data JSON, updated_at, deleted_at, synced — same scoping, LWW and tombstones as activities).
  The profile is in `kv` (`profile:<userId>`, `profile:local` while signed out, `_dirty` flag).
- Sync order: push → pull → photos → participants (ProfileSync, /shoes, /workouts).
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
  Strava/Apple Health and route privacy; schedule 09 hides multi-week plan names and best-time
  windows — no data source. Never show the design's sample values.
- HR zones: Max HR = user value, else Tanaka `208 − 0.7 × age` (birth year typed in พ.ศ. or ค.ศ.);
  zones 1–5 = 50–60 … 90–100 % (ceil of each lower bound, no overlap). Focus zone 2.
- Units: `UnitsCubit` (device setting in `kv`) → `context.units` everywhere (distance, pace, speed,
  splits, wind, share image). Plans store pace per km; shown per the chosen unit.
- Navigation: avatar → ProfilePage (works signed out) → sync strip / buttons → AccountPage.
  Signed out, ProfilePage is Stitch 08 guest (LOCAL ONLY, invite, device data, real account benefits) and
  SchedulePage ends with the 09 "Athletic Pass" invite. Nothing is locked; only real benefits are listed
  (no VO2 Max, watch sync, Strava/Apple Health, "+18.4%").
- Reminders (all local, device settings in `kv` `settings.reminders`):
  - **Plan reminder:** fires 15/30/60 min before each plan still ahead (not rest, not done), capped at 40
    for iOS's 64-notification limit.
  - **When they're re-planned:** ReminderListeners re-plans when TrainingCubit's plans change (save,
    delete, sync pull, account switch, launch), on settings or unit changes, and when the latest activity
    changes (weather place).
  - **Weekly goal:** shown once when the week passes `kWeeklyGoalMeters`.
  - **Weather:** next 06:00 Open-Meteo forecast where the last activity started (`WeatherService.forecast`).
  - **Taps:** the payload is `<kind>|schedule:YYYY-MM-DD` or `home`; a schedule tap opens
    `SchedulePage.route(day:)`. The OS asks for permission the first time one is turned on, or when a
    plan exists.
- Recording outside the app (`RecordingCompanion` in app.dart): every whole km/mi it speaks a Thai cue
  (`TtsVoiceCoach`; "Audio Cues" setting; iOS `audio` background mode).
  - **iOS Live Activity / Dynamic Island:** it mirrors `RecordState` (throttled 3 s, immediate on
    pause/lap; the clock runs itself with `Text(timerInterval:)`).
    - Native code: `ios/RecordingWidget` (widget extension, iOS 16.2+, Obsidian tokens mirrored in Swift)
      and `ios/Shared` (attributes, LiveActivityIntents, compiled into both targets).
    - Bridge: `Runner/LiveActivityBridge.swift` on channel `prachaya/live_activity`.
    - Buttons: Pause/Resume/Lap post `.recordingCommand` in the app process, which comes back to Dart
      as `LiveCommand`.
  - **Android:** an ongoing notification with the same buttons (`AndroidRecordingNotification`).
  - **Laps:** live only (`RecordingSession.lap`, `RecordLapped`); activities and the API keep no laps.
  Dashboard has a "ตารางซ้อม" teaser below the latest activity → SchedulePage.
- Motion: entrance staggers, count-ups, ring/bar sweeps, sliding tabs, press springs, haptics. Every
  looping animation stops under OS "remove animations" (widget tests run with it on so pumpAndSettle ends).
- Font files in `assets/fonts/` (OFL). Launch: native splash `#0C0D0B`, then `core/splash/SplashPage`.
- Logo (Stitch "Modern Luxury Kinetic"):
  - `assets/icon/app_icon.png`: full-bleed monogram, no wordmark; used for the launcher icons.
  - `app_icon_foreground.png`: Android adaptive icon and Android 12 splash.
  - `logo.png`: squircle with the wordmark, on SplashPage.
  - Regenerate with `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
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
  only the photo checks when the server's file storage is down; the test accounts are always deleted).
  - It covers both 07.1 choices: merge, where profile, shoe and plan reach the server; and keep, where
    a second account gets nothing and the plan returns after sign-out.
  - It turns plan reminders off on the test device, so no OS permission prompt waits for a tap.
