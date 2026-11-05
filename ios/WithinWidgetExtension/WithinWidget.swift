import SwiftUI
import WidgetKit

extension Color {
    /// Sampled from the app icon so the widget and icon read as one surface.
    static let withinInk = Color(red: 0x1B / 255, green: 0x19 / 255, blue: 0x19 / 255)
    static let withinPaper = Color(red: 0xF5 / 255, green: 0xF1 / 255, blue: 0xE8 / 255)
    static let withinSage = Color(red: 0xA8 / 255, green: 0xB5 / 255, blue: 0xA2 / 255)
}

/// The ring-and-dot logo, drawn as vectors so it stays crisp at any size and
/// can be tinted in accented and lock screen modes.
struct WithinMark: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: size * 0.08)
            Circle().frame(width: size * 0.27, height: size * 0.27)
        }
        .frame(width: size, height: size)
    }
}

struct WithinWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TeachingEntry

    private var teaching: Teaching { entry.teaching }

    var body: some View {
        switch family {
        case .accessoryRectangular: lockScreen
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Lock screen

    /// iOS renders lock screen widgets in its own vibrant style, so this sticks
    /// to semantic styles and drops the reference when the quote needs the room.
    /// Custom colors aren't allowed here; the system's translucent backing is the
    /// closest to the brand charcoal and keeps the text legible on bright wallpapers.
    private var lockScreen: some View {
        ZStack {
            AccessoryWidgetBackground()
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 1) {
                    quote(teaching.shortText, size: 13)
                    Text(teaching.reference)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .widgetAccentable()
                }
                quote(teaching.shortText, size: 13)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            WithinMark(size: 14)
                .foregroundStyle(Color.withinSage)
                .widgetAccentable()
            Spacer(minLength: 8)
            quote(teaching.shortText, size: 15)
                .foregroundStyle(Color.withinPaper)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 8)
            reference
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                WithinMark(size: 14)
                Text("Within")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1.5)
            }
            .foregroundStyle(Color.withinSage)
            .widgetAccentable()
            Spacer(minLength: 8)
            // Prefer the full passage; fall back to the short form if it won't fit.
            ViewThatFits(in: .vertical) {
                quote(teaching.text, size: 15)
                quote(teaching.shortText, size: 16)
            }
            .foregroundStyle(Color.withinPaper)
            Spacer(minLength: 8)
            reference
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var reference: some View {
        Text(teaching.reference)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.withinSage)
            .lineLimit(1)
    }

    private func quote(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, design: .serif))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct WithinWidget: Widget {
    /// Also used by the Flutter app (via home_widget) to request reloads.
    static let kind = "WithinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TeachingTimelineProvider()) { entry in
            WithinWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    BackgroundView()
                }
        }
        .configurationDisplayName("Daily Teaching")
        .description("A new teaching from the Buddha each day.")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}

/// Lock screen widgets sit directly on the wallpaper; home screen widgets get
/// the brand charcoal (iOS removes it automatically in tinted/clear modes).
private struct BackgroundView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            Color.clear
        } else {
            Color.withinInk
        }
    }
}

private let previewEntry = TeachingEntry(date: .now, teaching: TeachingTimelineProvider.fallback)

#Preview("Lock screen", as: .accessoryRectangular) {
    WithinWidget()
} timeline: {
    previewEntry
}

#Preview("Small", as: .systemSmall) {
    WithinWidget()
} timeline: {
    previewEntry
}

#Preview("Medium", as: .systemMedium) {
    WithinWidget()
} timeline: {
    previewEntry
}
