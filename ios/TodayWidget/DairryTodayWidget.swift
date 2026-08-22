import SwiftUI
import UIKit
import WidgetKit

private let appGroupId = "group.com.dairry.dairryapp"
private let widgetKind = "DairryTodayWidget"

struct DairryTodayEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
    let hasDoodle: Bool
    let language: String
}

struct DairryTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DairryTodayEntry {
        DairryTodayEntry(date: Date(), imagePath: nil, hasDoodle: false, language: "turkish")
    }

    func getSnapshot(in context: Context, completion: @escaping (DairryTodayEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DairryTodayEntry>) -> Void) {
        let now = Date()
        let entry = entry(for: now)
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 2),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func entry(for date: Date) -> DairryTodayEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let storedDate = defaults?.string(forKey: "today_date_key") ?? ""
        let currentDate = Self.dateKeyFormatter.string(from: date)
        let hasDoodle = defaults?.bool(forKey: "has_doodle") == true && storedDate == currentDate
        return DairryTodayEntry(
            date: date,
            imagePath: hasDoodle ? defaults?.string(forKey: "today_doodle") : nil,
            hasDoodle: hasDoodle,
            language: defaults?.string(forKey: "widget_language") ?? "turkish"
        )
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct DairryTodayEntryView: View {
    let entry: DairryTodayEntry
    @Environment(\.widgetFamily) private var widgetFamily

    private var locale: Locale {
        Locale(identifier: entry.language == "english" ? "en_US" : "tr_TR")
    }

    private var prompt: String {
        entry.language == "english" ? "Draw today" : "Bugünü çiz"
    }

    private var day: String {
        formattedDate("d")
    }

    private var month: String {
        formattedDate("MMMM")
    }

    private var weekday: String {
        formattedDate("EEEE")
    }

    private func formattedDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: entry.date)
    }

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 17.0, *) {
                content
                    .containerBackground(Color.white, for: .widget)
            } else {
                content.background(Color.white)
            }
        }
        .widgetURL(URL(string: "dairry://draw/today?homeWidget"))
    }

    @ViewBuilder
    private var content: some View {
        if widgetFamily == .systemSmall {
            smallContent
        } else {
            mediumContent
        }
    }

    private var smallContent: some View {
        ZStack {
            Color.white

            if entry.hasDoodle,
               let path = entry.imagePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                VStack(spacing: 5) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 28, weight: .semibold))
                    Text(prompt)
                        .font(.caption2.weight(.bold))
                }
                .foregroundColor(Color(red: 49 / 255, green: 95 / 255, blue: 70 / 255))
            }

            VStack {
                HStack(spacing: 3) {
                    Text(day)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(weekday.capitalized(with: locale))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(Color(red: 37 / 255, green: 41 / 255, blue: 37 / 255))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(5)
        }
    }

    private var mediumContent: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(day)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 37 / 255, green: 41 / 255, blue: 37 / 255))
                        .lineLimit(1)

                    Text(month.capitalized(with: locale))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 49 / 255, green: 95 / 255, blue: 70 / 255))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(weekday.capitalized(with: locale))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 105 / 255, green: 113 / 255, blue: 106 / 255))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)

                ZStack {
                    Color.white

                    if entry.hasDoodle,
                       let path = entry.imagePath,
                       let image = UIImage(contentsOfFile: path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.height, height: geometry.size.height)
                            .clipped()
                    } else {
                        VStack(spacing: 5) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 28, weight: .semibold))
                            Text(prompt)
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundColor(Color(red: 49 / 255, green: 95 / 255, blue: 70 / 255))
                    }
                }
                .frame(width: geometry.size.height, height: geometry.size.height)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

@main
struct DairryTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: DairryTodayProvider()) { entry in
            DairryTodayEntryView(entry: entry)
        }
        .configurationDisplayName("dairry.")
        .description("Bugünün görsel takvim karesi")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
