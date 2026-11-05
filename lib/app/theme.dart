import 'package:flutter/material.dart';

/// Brand palette. `ink` is sampled from the app icon so the icon, app and
/// widgets share one background; keep it in sync with `WithinWidget.swift`.
abstract final class WithinColors {
  static const ink = Color(0xFF1B1919);
  static const paper = Color(0xFFF5F1E8);
  static const sage = Color(0xFFA8B5A2);
  static const inkRaised = Color(0xFF242121);
}

abstract final class WithinTheme {
  /// Serif for the teachings themselves, echoing the widget's serif design.
  static const serif = 'Georgia';

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WithinColors.sage,
        brightness: Brightness.dark,
        surface: WithinColors.ink,
        onSurface: WithinColors.paper,
        primary: WithinColors.sage,
      ),
      scaffoldBackgroundColor: WithinColors.ink,
      splashFactory: NoSplash.splashFactory,
    );
    return base.copyWith(
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WithinColors.inkRaised,
        showDragHandle: true,
        dragHandleColor: WithinColors.sage,
      ),
    );
  }
}
