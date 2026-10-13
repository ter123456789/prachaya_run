import ActivityKit
import Foundation

/// The recording shown on the lock screen and in the Dynamic Island.
/// Compiled into Runner and RecordingWidget; the app sends ContentState
/// from Dart (LiveSnapshot in lib/features/activity/domain/services).
struct RecordingAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var title: String
    var paused: Bool
    /// Moving time when this state was sent; the clock counts on from
    /// `updatedAt` while not paused.
    var elapsedSeconds: Double
    var updatedAt: Date
    var distance: String
    var distanceUnit: String
    var paceLabel: String
    var pace: String
    var paceUnit: String
    var lapNumber: Int
    var lapDistance: String
    var calories: String
    var elevation: String

    /// Start of the running clock (moving time), for Text(timerInterval:).
    var clockStart: Date { updatedAt.addingTimeInterval(-elapsedSeconds) }

    var elapsedText: String {
      let s = Int(elapsedSeconds)
      let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
      return h > 0
        ? String(format: "%d:%02d:%02d", h, m, sec)
        : String(format: "%02d:%02d", m, sec)
    }
  }
}

extension Notification.Name {
  /// Posted by the Live Activity buttons (in the app's process); the app
  /// forwards the command ("pause" / "resume" / "lap") to Flutter.
  static let recordingCommand = Notification.Name("prachaya.recordingCommand")
}
