/// A photo attached to an activity. Stored on the device first and synced
/// like activities (client-generated UUID [id]).
class ActivityPhoto {
  const ActivityPhoto({
    required this.id,
    required this.activityId,
    required this.takenAt,
    this.localPath,
  });

  final String id;
  final String activityId;
  final DateTime takenAt;

  /// Image file on the device; null while a photo from another device is
  /// still downloading.
  final String? localPath;

  @override
  bool operator ==(Object other) =>
      other is ActivityPhoto &&
      other.id == id &&
      other.activityId == activityId &&
      other.takenAt == takenAt &&
      other.localPath == localPath;

  @override
  int get hashCode => Object.hash(id, activityId, takenAt, localPath);
}
