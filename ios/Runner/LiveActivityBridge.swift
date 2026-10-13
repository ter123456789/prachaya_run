import ActivityKit
import Flutter
import Foundation

/// `prachaya/live_activity`: Dart's IosLiveActivityMirror starts, updates
/// and ends the recording's Live Activity; the Live Activity buttons come
/// back as `command` calls.
final class LiveActivityBridge {
  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "prachaya/live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    observer = NotificationCenter.default.addObserver(
      forName: .recordingCommand, object: nil, queue: .main
    ) { [weak self] note in
      guard let command = note.object as? String else { return }
      self?.channel.invokeMethod("command", arguments: command)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else { return result(false) }
    switch call.method {
    case "show":
      guard let args = call.arguments as? [String: Any], let state = Self.state(args) else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      Task { result(await LiveActivityController.shared.show(state)) }
    case "end":
      Task {
        await LiveActivityController.shared.end()
        result(true)
      }
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func state(_ a: [String: Any]) -> RecordingAttributes.ContentState? {
    guard let title = a["title"] as? String, let paused = a["paused"] as? Bool,
      let elapsed = a["elapsedSeconds"] as? Double
    else { return nil }
    func s(_ k: String) -> String { a[k] as? String ?? "" }
    return .init(
      title: title, paused: paused, elapsedSeconds: elapsed, updatedAt: Date(),
      distance: s("distance"), distanceUnit: s("distanceUnit"), paceLabel: s("paceLabel"),
      pace: s("pace"), paceUnit: s("paceUnit"), lapNumber: a["lapNumber"] as? Int ?? 1,
      lapDistance: s("lapDistance"), calories: s("calories"), elevation: s("elevation"))
  }
}

@available(iOS 16.2, *)
actor LiveActivityController {
  static let shared = LiveActivityController()
  private var activity: Activity<RecordingAttributes>?

  /// Starts the Live Activity the first time, then updates it.
  func show(_ state: RecordingAttributes.ContentState) async -> Bool {
    let content = ActivityContent(state: state, staleDate: nil)
    if activity == nil {
      // One recording at a time: drop any left from a crash.
      for old in Activity<RecordingAttributes>.activities {
        await old.end(nil, dismissalPolicy: .immediate)
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
      activity = try? Activity.request(
        attributes: RecordingAttributes(), content: content, pushType: nil)
      return activity != nil
    }
    await activity?.update(content)
    return true
  }

  func end() async {
    for a in Activity<RecordingAttributes>.activities {
      await a.end(nil, dismissalPolicy: .immediate)
    }
    activity = nil
  }
}
