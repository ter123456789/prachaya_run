import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveActivity: LiveActivityBridge?
  private var heartRate: HeartRateBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Reminders show while the app is open too (flutter_local_notifications).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene lifecycle (required by the iOS 27 SDK): the engine is created by
  // FlutterSceneDelegate after launch, so plugins and channels attach here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    liveActivity = LiveActivityBridge(messenger: engineBridge.applicationRegistrar.messenger())
    heartRate = HeartRateBridge(messenger: engineBridge.applicationRegistrar.messenger())
  }
}
