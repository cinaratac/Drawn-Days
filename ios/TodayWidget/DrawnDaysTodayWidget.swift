import SwiftUI
import UIKit
import WidgetKit

private let appGroupId = "group.com.drawndays.app"
private let widgetKind = "DrawnDaysTodayWidget"
private let paper = Color(red: 255 / 255, green: 254 / 255, blue: 248 / 255)
private let ink = Color(red: 23 / 255, green: 63 / 255, blue: 50 / 255)
private let green = Color(red: 49 / 255, green: 95 / 255, blue: 70 / 255)
private let yellow = Color(red: 242 / 255, green: 215 / 255, blue: 98 / 255)

struct DrawnDaysTodayEntry: TimelineEntry {
    let date: Date
    let todayImageData: Data?
    let weekImageData: Data?
    let monthImageData: Data?
    let language: String
}

struct DrawnDaysTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DrawnDaysTodayEntry { entry(for: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (DrawnDaysTodayEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DrawnDaysTodayEntry>) -> Void) {
        let now = Date()
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 2),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry(for: now)], policy: .after(nextMidnight)))
    }

    private func entry(for date: Date) -> DrawnDaysTodayEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let storedDate = defaults?.string(forKey: "today_date_key") ?? ""
        let currentDate = Self.dateKeyFormatter.string(from: date)
        let today = storedDate == currentDate ? Self.imageData(defaults: defaults, key: "today_doodle") : nil
        return DrawnDaysTodayEntry(
            date: date,
            todayImageData: today,
            weekImageData: Self.imageData(defaults: defaults, key: "week_widget"),
            monthImageData: Self.imageData(defaults: defaults, key: "month_widget"),
            language: defaults?.string(forKey: "widget_language") ?? "english"
        )
    }

    private static func imageData(defaults: UserDefaults?, key: String) -> Data? {
        var urls: [URL] = []
        if let path = defaults?.string(forKey: key), !path.isEmpty {
            urls.append(URL(fileURLWithPath: path))
        }
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            urls.append(groupURL.appendingPathComponent("home_widget", isDirectory: true).appendingPathComponent("\(key).png"))
        }
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url), !data.isEmpty { return data }
        }
        return nil
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct DrawnDaysTodayEntryView: View {
    let entry: DrawnDaysTodayEntry
    @Environment(\.widgetFamily) private var family

    private var locale: Locale { Locale(identifier: entry.language == "english" ? "en_US" : "tr_TR") }
    private var destination: URL? {
        switch family {
        case .systemMedium: return URL(string: "drawndays://calendar/week?homeWidget")
        case .systemLarge: return URL(string: "drawndays://calendar/month?homeWidget")
        default: return URL(string: "drawndays://draw/today?homeWidget")
        }
    }

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 17.0, *) {
                content.containerBackground(paper, for: .widget)
            } else {
                content.background(paper)
            }
        }
        .widgetURL(destination)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemMedium:
            artwork(entry.weekImageData, aspect: 2)
        case .systemLarge:
            artwork(entry.monthImageData, aspect: 1)
        default:
            todayCard
        }
    }

    @ViewBuilder private func artwork(_ data: Data?, aspect: CGFloat) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(aspect, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(paper)
        } else {
            ZStack {
                paper
                HandPencil().stroke(green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 45, height: 45)
                    .rotationEffect(.degrees(-7))
            }
        }
    }

    private var todayCard: some View {
        ZStack {
            PaperTexture()
            if let data = entry.todayImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(8)
                VStack {
                    Rectangle()
                        .fill(yellow.opacity(0.78))
                        .frame(width: 42, height: 10)
                        .rotationEffect(.degrees(-3))
                        .offset(y: -2)
                    Spacer()
                }
            } else {
                ZStack {
                    Ellipse()
                        .fill(yellow.opacity(0.72))
                        .frame(width: 58, height: 52)
                        .rotationEffect(.degrees(-5))
                    HandPencil().stroke(green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 35, height: 35)
                        .rotationEffect(.degrees(-7))
                }
                .offset(y: 8)
            }
            VStack(alignment: .leading) {
                Text(formatted("d"))
                    .font(.custom("PatrickHand-Regular", size: 29))
                    .foregroundColor(ink)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            UnevenCard()
                .stroke(ink.opacity(0.62), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .padding(3)
        }
    }

    private func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: entry.date)
    }
}

private struct HandPencil: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY * 0.62))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY + rect.height * 0.13))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.9, y: rect.minY + rect.height * 0.35), control1: CGPoint(x: rect.minX + rect.width * 0.79, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.79))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.81, y: rect.minY + rect.height * 0.43))
        return path
    }
}

private struct UnevenCard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 12, y: rect.minY + 2))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 1), control: CGPoint(x: rect.midX, y: rect.minY - 2))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 10), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 1), control: CGPoint(x: rect.midX, y: rect.maxY + 2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 12, y: rect.minY + 2), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        return path
    }
}

private struct PaperTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
            for y in stride(from: 7.0, to: size.height, by: 14.0) {
                for x in stride(from: 8.0, to: size.width, by: 19.0) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(ink.opacity(0.035)))
                }
            }
        }
    }
}

@main
struct DrawnDaysTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: DrawnDaysTodayProvider()) { entry in
            DrawnDaysTodayEntryView(entry: entry)
        }
        .configurationDisplayName("Drawn Days")
        .description("Bugünün, son 7 günün veya ayın çizimlerini gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
