import Flutter
import Foundation
import HealthKit

/// `prachaya/health`: workouts other apps (Apple Workout, Garmin Connect,
/// Strava…) wrote to Apple Health, for Dart's NativeHealthSource. Read only.
///
/// - Needs the HealthKit capability (`com.apple.developer.healthkit` in
///   Runner.entitlements, wired through CODE_SIGN_ENTITLEMENTS) and
///   NSHealthShareUsageDescription. Without the entitlement every call
///   answers `unavailable` / empty.
/// - HealthKit never says whether reading was allowed; a refused type just
///   returns nothing. So `granted` means "the user has been asked".
/// - Times cross the channel as epoch milliseconds.
final class HealthBridge {
  private let channel: FlutterMethodChannel
  private let store = HKHealthStore()
  private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
  private let bpm = HKUnit.count().unitDivided(by: .minute())

  private var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = [
      HKObjectType.workoutType(), HKSeriesType.workoutRoute(), heartRateType,
    ]
    for id in [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling] {
      if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
    }
    return types
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "prachaya/health", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    guard HKHealthStore.isHealthDataAvailable() else {
      return result(call.method == "availability" || call.method == "requestAccess"
        ? "unavailable" : [])
    }
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "availability":
      store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
        if error != nil { return reply("unavailable") }
        reply(status == .unnecessary ? "granted" : "denied")
      }
    case "requestAccess":
      store.requestAuthorization(toShare: [], read: readTypes) { ok, error in
        reply(error != nil ? "unavailable" : (ok ? "granted" : "denied"))
      }
    case "workouts":
      guard let (from, to) = span(args) else { return result([]) }
      workouts(from: from, to: to, reply: reply)
    case "detail":
      guard let raw = args["id"] as? String, let id = UUID(uuidString: raw) else {
        return result(nil)
      }
      detail(id: id, reply: reply)
    case "heartRate":
      guard let (from, to) = span(args) else { return result([]) }
      heartRate(from: from, to: to) { reply($0) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Queries

  private func workouts(from: Date, to: Date, reply: @escaping (Any?) -> Void) {
    let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let ownBundle = Bundle.main.bundleIdentifier
    let query = HKSampleQuery(
      sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit,
      sortDescriptors: [sort]
    ) { _, samples, _ in
      let items: [[String: Any]] = (samples as? [HKWorkout] ?? []).compactMap { w in
        guard let kind = Self.kind(w.workoutActivityType),
          w.sourceRevision.source.bundleIdentifier != ownBundle
        else { return nil }
        var item: [String: Any] = [
          "id": w.uuid.uuidString, "source": "healthkit", "kind": kind,
          "start": Self.ms(w.startDate), "end": Self.ms(w.endDate),
          "activeMs": Int(w.duration * 1000),
          "app": w.sourceRevision.source.name,
        ]
        if let meters = w.totalDistance?.doubleValue(for: .meter()) { item["distanceM"] = meters }
        if let up = w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
          item["elevationM"] = up.doubleValue(for: .meter())
        }
        if let device = w.device?.name { item["device"] = device }
        return item
      }
      reply(items)
    }
    store.execute(query)
  }

  private func detail(id: UUID, reply: @escaping (Any?) -> Void) {
    let query = HKSampleQuery(
      sampleType: .workoutType(), predicate: HKQuery.predicateForObject(with: id),
      limit: 1, sortDescriptors: nil
    ) { [weak self] _, samples, _ in
      guard let self, let workout = samples?.first as? HKWorkout else { return reply(nil) }
      let group = DispatchGroup()
      var route: [[String: Any]] = []
      var heart: [[String: Any]] = []
      group.enter()
      self.route(of: workout) { points in
        route = points
        group.leave()
      }
      group.enter()
      self.heartRate(from: workout.startDate, to: workout.endDate) { samples in
        heart = samples
        group.leave()
      }
      group.notify(queue: .main) { reply(["route": route, "heartRate": heart]) }
    }
    store.execute(query)
  }

  /// Every location of the workout's routes, oldest first.
  private func route(of workout: HKWorkout, done: @escaping ([[String: Any]]) -> Void) {
    let query = HKSampleQuery(
      sampleType: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout),
      limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { [weak self] _, samples, _ in
      guard let self, let routes = samples as? [HKWorkoutRoute], !routes.isEmpty else {
        return done([])
      }
      let lock = NSLock()
      let group = DispatchGroup()
      var points: [(Date, [String: Any])] = []
      for route in routes {
        group.enter()
        let q = HKWorkoutRouteQuery(route: route) { _, locations, finished, _ in
          let batch = (locations ?? []).map { l -> (Date, [String: Any]) in
            var p: [String: Any] = [
              "lat": l.coordinate.latitude, "lng": l.coordinate.longitude,
              "t": Self.ms(l.timestamp),
            ]
            if l.verticalAccuracy >= 0 { p["alt"] = l.altitude }
            if l.horizontalAccuracy >= 0 { p["acc"] = l.horizontalAccuracy }
            return (l.timestamp, p)
          }
          lock.lock()
          points.append(contentsOf: batch)
          lock.unlock()
          if finished { group.leave() }
        }
        self.store.execute(q)
      }
      group.notify(queue: .global()) {
        done(points.sorted { $0.0 < $1.0 }.map { $0.1 })
      }
    }
    store.execute(query)
  }

  private func heartRate(from: Date, to: Date, done: @escaping ([[String: Any]]) -> Void) {
    let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(
      sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit,
      sortDescriptors: [sort]
    ) { [weak self] _, samples, _ in
      guard let self else { return done([]) }
      done((samples as? [HKQuantitySample] ?? []).map {
        ["t": Self.ms($0.startDate), "bpm": $0.quantity.doubleValue(for: self.bpm)]
      })
    }
    store.execute(query)
  }

  // MARK: - Helpers

  private static func kind(_ type: HKWorkoutActivityType) -> String? {
    switch type {
    case .running: return "run"
    case .cycling: return "ride"
    case .hiking: return "hike"
    case .walking: return "walk"
    default: return nil
    }
  }

  private static func ms(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

  private func span(_ args: [String: Any]) -> (Date, Date)? {
    guard let from = args["from"] as? NSNumber, let to = args["to"] as? NSNumber else { return nil }
    return (
      Date(timeIntervalSince1970: from.doubleValue / 1000),
      Date(timeIntervalSince1970: to.doubleValue / 1000)
    )
  }
}
