import 'package:home_widget/home_widget.dart';

/// Talks to the native home/lock screen widgets.
///
/// The iOS widget computes each day's teaching itself from its own copy of the
/// JSON, so the app never pushes content — it only nudges WidgetKit to rebuild
/// the timeline (e.g. after an app update or a time zone change).
class WidgetService {
  /// Must match the App Group in both targets' `.entitlements` files.
  static const appGroupId = 'group.com.justdev.within';

  /// Must match `WithinWidget.kind` in `WithinWidget.swift`.
  static const iOSWidgetKind = 'WithinWidget';

  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } on Exception {
      // Widgets are a bonus; the app must work even if the plugin is unavailable.
    }
  }

  Future<void> refresh() async {
    try {
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } on Exception {
      // Best effort: WidgetKit will still roll over on its own timeline.
    }
  }
}
