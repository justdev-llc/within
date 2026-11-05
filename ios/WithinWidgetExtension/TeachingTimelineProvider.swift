import WidgetKit

struct TeachingEntry: TimelineEntry {
    let date: Date
    let teaching: Teaching
}

/// Hands WidgetKit a week of entries, one per local midnight, so the widget
/// rolls over to the next teaching each day without the app ever running.
struct TeachingTimelineProvider: TimelineProvider {
    static let daysAhead = 7

    /// Shown if the bundled JSON is somehow missing, so the widget is never blank.
    static let fallback = Teaching(
        id: "fallback",
        tradition: "buddhism",
        scripture: "Dhammapada",
        reference: "Dhammapada 5",
        text: "Hatred is never ended by hatred. By non-hatred alone it ends.",
        shortText: "Hatred is never ended by hatred. By non-hatred alone it ends.",
        contentType: "paraphrase",
        language: "en",
        attribution: nil
    )

    private let store = TeachingStore.load()

    private func teaching(for date: Date) -> Teaching {
        store?.teaching(for: date) ?? Self.fallback
    }

    func placeholder(in context: Context) -> TeachingEntry {
        TeachingEntry(date: .now, teaching: teaching(for: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (TeachingEntry) -> Void) {
        completion(TeachingEntry(date: .now, teaching: teaching(for: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TeachingEntry>) -> Void) {
        completion(Self.timeline(from: .now, teaching: teaching(for:)))
    }

    /// Today's entry starts now; each following entry starts at a local midnight.
    /// `date(byAdding:)` from `startOfDay` handles 23/25-hour DST days correctly.
    static func timeline(
        from now: Date,
        calendar: Calendar = TeachingStore.localCalendar,
        teaching: (Date) -> Teaching
    ) -> Timeline<TeachingEntry> {
        let today = calendar.startOfDay(for: now)
        var entries = [TeachingEntry(date: now, teaching: teaching(now))]
        for offset in 1...daysAhead {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(TeachingEntry(date: midnight, teaching: teaching(midnight)))
        }
        // Ask for a fresh week once the last midnight passes. iOS may run this
        // later than requested, but the queued entries keep the widget correct.
        return Timeline(entries: entries, policy: .atEnd)
    }
}
