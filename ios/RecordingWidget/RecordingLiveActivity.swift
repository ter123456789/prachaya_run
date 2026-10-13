import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Obsidian Kinetic tokens, mirrored from lib/core/theme/app_colors.dart.
private enum Tokens {
  static let background = Color(red: 0x0C / 255, green: 0x0D / 255, blue: 0x0B / 255)
  static let surfaceHigh = Color(red: 0x29 / 255, green: 0x2A / 255, blue: 0x28 / 255)
  static let lime = Color(red: 0xD4 / 255, green: 0xF3 / 255, blue: 0x6B / 255)
  static let onLime = Color(red: 0x11 / 255, green: 0x13 / 255, blue: 0x0C / 255)
  static let mint = Color(red: 0x6E / 255, green: 0xE7 / 255, blue: 0xB7 / 255)
  static let amber = Color(red: 0xF2 / 255, green: 0xA6 / 255, blue: 0x5A / 255)
  static let textSecondary = Color.white.opacity(0.7)
  static let textMuted = Color.white.opacity(0.5)
}

private struct Clock: View {
  let state: RecordingAttributes.ContentState
  var body: some View {
    if state.paused {
      Text(state.elapsedText)
    } else {
      Text(timerInterval: state.clockStart...Date.distantFuture, countsDown: false)
    }
  }
}

private struct Metric: View {
  let label: String
  let value: String
  let unit: String
  var color: Color = .white
  var compact = false
  var body: some View {
    VStack(alignment: compact ? .center : .leading, spacing: 2) {
      Text(label).font(.caption2).foregroundStyle(Tokens.textMuted).lineLimit(1)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.system(compact ? .headline : .title3, design: .monospaced).weight(.semibold))
          .foregroundStyle(color)
        Text(unit).font(.caption2.monospaced()).foregroundStyle(Tokens.textSecondary)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    }
  }
}

private struct Controls: View {
  let paused: Bool
  var body: some View {
    if #available(iOS 17.0, *) {
      HStack(spacing: 10) {
        if paused {
          Button(intent: ResumeRecordingIntent()) {
            Label("ทำต่อ", systemImage: "play.fill").frame(maxWidth: .infinity)
          }
          .tint(Tokens.lime)
          .foregroundStyle(Tokens.onLime)
        } else {
          Button(intent: PauseRecordingIntent()) {
            Label("หยุดชั่วคราว", systemImage: "pause.fill").frame(maxWidth: .infinity)
          }
          .tint(Tokens.surfaceHigh)
        }
        Button(intent: LapRecordingIntent()) {
          Label("เพิ่ม Lap", systemImage: "flag.fill").frame(maxWidth: .infinity)
        }
        .tint(Tokens.surfaceHigh)
        .disabled(paused)
      }
      .buttonStyle(.borderedProminent)
      .font(.footnote.weight(.semibold))
    }
  }
}

private struct LockScreenView: View {
  let state: RecordingAttributes.ContentState
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Circle().fill(state.paused ? Tokens.amber : Tokens.lime).frame(width: 8, height: 8)
        Text(state.title).font(.subheadline.weight(.semibold))
        Spacer()
        Clock(state: state)
          .font(.system(.title2, design: .monospaced).weight(.bold))
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 130, alignment: .trailing)
      }
      HStack(alignment: .top) {
        Metric(label: "ระยะทางสะสม", value: state.distance, unit: state.distanceUnit,
               color: Tokens.lime)
        Spacer()
        Metric(label: state.paceLabel, value: state.pace, unit: state.paceUnit)
        Spacer()
        Metric(label: "แคลอรี่", value: state.calories, unit: "KCAL")
      }
      HStack {
        Text("● รอบที่ \(state.lapNumber) • \(state.lapDistance)")
          .font(.caption.monospaced()).foregroundStyle(Tokens.mint)
        Spacer()
        Text("ขึ้น \(state.elevation) ม.").font(.caption.monospaced())
          .foregroundStyle(Tokens.textSecondary)
      }
      Controls(paused: state.paused)
    }
    .padding(16)
    .foregroundStyle(.white)
  }
}

struct RecordingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(Tokens.background)
        .activitySystemActionForegroundColor(Tokens.lime)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Metric(label: "ระยะทาง", value: state.distance, unit: state.distanceUnit,
                 color: Tokens.lime, compact: true)
            .dynamicIsland(verticalPlacement: .belowIfTooWide)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Metric(label: state.paceLabel, value: state.pace, unit: state.paceUnit,
                 compact: true)
            .dynamicIsland(verticalPlacement: .belowIfTooWide)
        }
        DynamicIslandExpandedRegion(.center) {
          Clock(state: state)
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(state.paused ? Tokens.amber : .white)
            .multilineTextAlignment(.center)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 8) {
            Text("รอบที่ \(state.lapNumber) • \(state.lapDistance)")
              .font(.caption.monospaced()).foregroundStyle(Tokens.mint)
            Controls(paused: state.paused)
          }
        }
      } compactLeading: {
        Image(systemName: "figure.run").foregroundStyle(Tokens.lime)
      } compactTrailing: {
        Text("\(state.distance) \(state.distanceUnit)")
          .font(.caption.monospaced().weight(.semibold))
          .foregroundStyle(Tokens.lime)
      } minimal: {
        Image(systemName: state.paused ? "pause.fill" : "figure.run")
          .foregroundStyle(state.paused ? Tokens.amber : Tokens.lime)
      }
      .keylineTint(Tokens.lime)
    }
  }
}
