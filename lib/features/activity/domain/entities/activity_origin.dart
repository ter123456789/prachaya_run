/// Where an activity was recorded (api.md v1.6 `origin`).
enum OriginKind {
  /// Recorded by this app on a phone (every activity before v1.6).
  phone,

  /// Imported on the phone from Apple Health / Health Connect.
  health,

  /// Pulled by the server from a linked Polar account.
  polar,

  /// Pulled by the server from a linked Garmin account.
  garmin,
}

class ActivityOrigin {
  const ActivityOrigin(this.kind, {this.app, this.device});

  static const phone = ActivityOrigin(OriginKind.phone);

  final OriginKind kind;

  /// The app that recorded it, e.g. "Samsung Health".
  final String? app;

  /// The watch, e.g. "Galaxy Watch7".
  final String? device;

  bool get isPhone => kind == OriginKind.phone;

  @override
  bool operator ==(Object other) =>
      other is ActivityOrigin &&
      other.kind == kind &&
      other.app == app &&
      other.device == device;

  @override
  int get hashCode => Object.hash(kind, app, device);

  @override
  String toString() => 'ActivityOrigin(${kind.name}, $app, $device)';
}
