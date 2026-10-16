import SwiftUI
import WidgetKit

/// Shared with the app, which writes the summary after every save or delete
/// (WidgetChannel in Runner/AppDelegate.swift).
private let appGroup = "group.cz.mojetepovka.tepovka"
private let summaryKey = "widget_summary"
private let measureURL = URL(string: "tepovka://measure")!

private let accent = Color(red: 0xE5 / 255.0, green: 0x39 / 255.0, blue: 0x35 / 255.0)
private let secondary = Color(red: 0x6E / 255.0, green: 0x6D / 255.0, blue: 0x6D / 255.0)
private let good = Color(red: 0x1E / 255.0, green: 0x8E / 255.0, blue: 0x3E / 255.0)
private let medium = Color(red: 0xE8 / 255.0, green: 0xA3 / 255.0, blue: 0x17 / 255.0)

/// What the app last wrote: the latest reading, the ones before it and the
/// labels in the app's own language, which may differ from the phone's.
struct Summary: Decodable {
  struct Labels: Decodable {
    let title: String
    let empty: String
    let measure: String
    let unit: String
    let today: String
  }

  let bpm: Int?
  let atMs: Double?
  let quality: String?
  let recent: [Int]
  let locale: String
  let labels: Labels

  var at: Date? { atMs.map { Date(timeIntervalSince1970: $0 / 1000) } }

  static func load() -> Summary? {
    guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: summaryKey),
      let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(Summary.self, from: data)
  }

  /// Before the app has run once there is nothing to read; the phone's
  /// language decides then.
  static var fallback: Summary {
    let czech = Locale.preferredLanguages.first?.hasPrefix("cs") ?? false
    return Summary(
      bpm: nil, atMs: nil, quality: nil, recent: [],
      locale: czech ? "cs" : "en",
      labels: Labels(
        title: czech ? "Poslední měření" : "Last measurement",
        empty: czech ? "Zatím žádné měření" : "No measurements yet",
        measure: czech ? "Změřit tep" : "Measure",
        unit: "bpm",
        today: czech ? "Dnes" : "Today"))
  }

  static var sample: Summary {
    let base = fallback
    return Summary(
      bpm: 72, atMs: (Date().timeIntervalSince1970 - 3600) * 1000, quality: "good",
      recent: [68, 74, 71, 69, 73, 70, 72], locale: base.locale, labels: base.labels)
  }

  /// "Today 9:20" or "14 Oct 9:20" in the app's language. The timeline
  /// refreshes at midnight, so "today" never goes stale.
  var when: String {
    guard let at else { return "" }
    let locale = Locale(identifier: locale)
    let time = at.formatted(.dateTime.hour().minute().locale(locale))
    if Calendar.current.isDateInToday(at) { return "\(labels.today) \(time)" }
    return at.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale))
  }

  var qualityColor: Color? {
    switch quality {
    case "good": return good
    case "medium": return medium
    case "poor": return accent
    default: return nil
    }
  }
}

struct Entry: TimelineEntry {
  let date: Date
  let summary: Summary
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), summary: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    // The widget gallery should show what the widget looks like with data.
    let summary = Summary.load() ?? (context.isPreview ? .sample : .fallback)
    completion(Entry(date: Date(), summary: summary))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    // The app reloads the widget after each change; the only thing that ages
    // by itself is "today", so the next refresh is at midnight.
    let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
    let entry = Entry(date: Date(), summary: Summary.load() ?? .fallback)
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

// MARK: - Views

private struct Reading: View {
  let s: Summary
  var size: CGFloat = 40

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: "heart.fill").foregroundStyle(accent)
        Text(s.labels.title).foregroundStyle(secondary).lineLimit(1)
      }
      .font(.caption)
      Spacer(minLength: 0)
      if let bpm = s.bpm {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(bpm)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
          Text(s.labels.unit).font(.subheadline).foregroundStyle(secondary)
        }
        HStack(spacing: 5) {
          if let color = s.qualityColor {
            Circle().fill(color).frame(width: 7, height: 7)
          }
          Text(s.when).font(.caption).foregroundStyle(secondary).lineLimit(1)
        }
      } else {
        Text(s.labels.empty).font(.subheadline).foregroundStyle(secondary)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct MeasurePill: View {
  let label: String

  var body: some View {
    Text(label)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .frame(maxWidth: .infinity)
      .background(Capsule().fill(accent))
  }
}

/// The latest readings as bars, scaled between the lowest and highest so a
/// change of a few bpm still shows; the newest one is red.
private struct Bars: View {
  let values: [Int]

  var body: some View {
    let lo = values.min() ?? 0
    let hi = values.max() ?? 0
    GeometryReader { geo in
      HStack(alignment: .bottom, spacing: 4) {
        ForEach(Array(values.enumerated()), id: \.offset) { i, v in
          let share = hi == lo ? 0.6 : 0.3 + 0.7 * Double(v - lo) / Double(hi - lo)
          RoundedRectangle(cornerRadius: 3)
            .fill(i == values.count - 1 ? accent : accent.opacity(0.28))
            .frame(height: geo.size.height * share)
        }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    }
  }
}

private struct SmallView: View {
  let s: Summary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Reading(s: s)
      MeasurePill(label: s.labels.measure)
    }
  }
}

private struct MediumView: View {
  let s: Summary

  var body: some View {
    HStack(spacing: 16) {
      Reading(s: s, size: 44)
      VStack(spacing: 10) {
        if s.recent.count >= 2 {
          Bars(values: s.recent)
        } else {
          Spacer(minLength: 0)
        }
        MeasurePill(label: s.labels.measure)
      }
      .frame(maxWidth: .infinity)
    }
  }
}

struct EntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: Entry

  var body: some View {
    let s = entry.summary
    switch family {
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Image(systemName: "heart.fill").font(.caption)
          Text(s.bpm.map { "\($0)" } ?? "–")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .minimumScaleFactor(0.6)
        }
      }
      .widgetURL(measureURL)
      .widgetBackground(.clear)
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 1) {
        Label(
          s.bpm.map { "\($0) \(s.labels.unit)" } ?? s.labels.measure,
          systemImage: "heart.fill"
        )
        .font(.headline)
        Text(s.bpm == nil ? s.labels.empty : s.when).font(.caption).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .widgetURL(measureURL)
      .widgetBackground(.clear)
    case .accessoryInline:
      Label(
        s.bpm.map { "\($0) \(s.labels.unit) · \(s.when)" } ?? s.labels.measure,
        systemImage: "heart.fill"
      )
      .widgetURL(measureURL)
    case .systemMedium:
      MediumView(s: s).widgetURL(measureURL).widgetBackground(.white)
    default:
      SmallView(s: s).widgetURL(measureURL).widgetBackground(.white)
    }
  }
}

extension View {
  /// iOS 17 wants the background declared, or the widget shows a warning.
  @ViewBuilder
  fileprivate func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      background(color)
    }
  }
}

// MARK: - Widget

struct TepovkaWidget: Widget {
  private var czech: Bool { Locale.preferredLanguages.first?.hasPrefix("cs") ?? false }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TepovkaWidget", provider: Provider()) { entry in
      EntryView(entry: entry)
    }
    .configurationDisplayName("Tepovka")
    .description(
      czech
        ? "Poslední tep a rychlý start měření."
        : "Your latest heart rate and a quick way to measure.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

@main
struct TepovkaWidgetBundle: WidgetBundle {
  var body: some Widget {
    TepovkaWidget()
  }
}
