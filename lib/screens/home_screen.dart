import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/teaching.dart';
import '../services/auth_service.dart';
import '../services/teaching_service.dart';
import '../services/widget_service.dart';
import '../widgets/teaching_card.dart';
import '../widgets/widget_instructions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.teachingService,
    required this.widgetService,
    required this.authService,
    this.clock = DateTime.now,
  });

  final TeachingService teachingService;
  final WidgetService widgetService;
  final AuthService authService;

  /// Injectable for tests.
  final DateTime Function() clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late DateTime _today;
  late Teaching _teaching;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showToday();
    widget.widgetService.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Coming back to the app may mean a new day or a new time zone, so update
  /// the screen and ask WidgetKit to rebuild its timeline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_showToday);
      widget.widgetService.refresh();
    }
  }

  void _showToday() {
    final now = widget.clock();
    _today = now;
    _teaching = widget.teachingService.forDate(now);

    // Roll over while the app is open at midnight. DateTime normalises day + 1
    // across month/year ends and lands on local midnight even across DST.
    _midnightTimer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(_showToday);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const _Header(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(_today),
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1.2,
                            color: WithinColors.paper.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TeachingCard(teaching: _teaching),
                      ],
                    ),
                  ),
                ),
              ),
              _AddWidgetButton(
                onPressed: () => WidgetInstructions.show(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _formatDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}'
          .toUpperCase();
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The logo's background is the same ink as the scaffold, so it blends in.
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/images/logo.png', width: 36, height: 36),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Within',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: WithinColors.paper,
              ),
            ),
            Text(
              'Timeless wisdom, every day.',
              style: TextStyle(fontSize: 12, color: WithinColors.sage),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddWidgetButton extends StatelessWidget {
  const _AddWidgetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: WithinColors.paper,
          backgroundColor: WithinColors.inkRaised,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Add the widget to your phone',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
