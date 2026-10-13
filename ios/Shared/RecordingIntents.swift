import AppIntents
import Foundation

// LiveActivityIntent runs in the app's process when the app is running
// (it is while recording), so a notification reaches the Flutter bridge.

@available(iOS 17.0, *)
struct PauseRecordingIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "หยุดชั่วคราว"
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .recordingCommand, object: "pause")
    return .result()
  }
}

@available(iOS 17.0, *)
struct ResumeRecordingIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "ทำต่อ"
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .recordingCommand, object: "resume")
    return .result()
  }
}

@available(iOS 17.0, *)
struct LapRecordingIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "เพิ่ม Lap"
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .recordingCommand, object: "lap")
    return .result()
  }
}
