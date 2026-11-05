import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/within_app.dart';
import 'services/teaching_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final teachingService = await TeachingService.load();
  final widgetService = WidgetService();
  await widgetService.initialize();

  runApp(
    WithinApp(teachingService: teachingService, widgetService: widgetService),
  );
}
