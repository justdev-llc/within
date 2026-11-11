import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/within_app.dart';
import 'env/env.dart';
import 'services/auth_service.dart';
import 'services/teaching_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // A build without keys skips Supabase and goes straight to the teachings,
  // so the app still runs before .env is set up.
  SupabaseClient? supabase;
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseKey.isNotEmpty) {
    final instance = await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
    supabase = instance.client;
  } else {
    debugPrint(
      'Supabase keys missing; add them to .env and run '
      'dart run build_runner build',
    );
  }

  final teachingService = await TeachingService.load();
  final widgetService = WidgetService();
  await widgetService.initialize();

  runApp(
    WithinApp(
      teachingService: teachingService,
      widgetService: widgetService,
      authService: AuthService(supabase),
    ),
  );
}
