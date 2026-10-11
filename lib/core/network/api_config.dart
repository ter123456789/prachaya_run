/// Server address, set at build time:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
/// The default reaches a backend on the dev machine from the iOS simulator;
/// the Android emulator needs `http://10.0.2.2:3000`.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
