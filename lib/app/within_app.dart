import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../services/teaching_service.dart';
import '../services/widget_service.dart';
import 'theme.dart';

class WithinApp extends StatelessWidget {
  const WithinApp({
    super.key,
    required this.teachingService,
    required this.widgetService,
    this.clock = DateTime.now,
  });

  final TeachingService teachingService;
  final WidgetService widgetService;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Within',
      debugShowCheckedModeBanner: false,
      theme: WithinTheme.dark,
      home: HomeScreen(
        teachingService: teachingService,
        widgetService: widgetService,
        clock: clock,
      ),
    );
  }
}
