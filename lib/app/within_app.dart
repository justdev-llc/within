import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../services/auth_service.dart';
import '../services/teaching_service.dart';
import '../services/widget_service.dart';
import 'theme.dart';

class WithinApp extends StatefulWidget {
  const WithinApp({
    super.key,
    required this.teachingService,
    required this.widgetService,
    required this.authService,
    this.clock = DateTime.now,
  });

  final TeachingService teachingService;
  final WidgetService widgetService;
  final AuthService authService;
  final DateTime Function() clock;

  @override
  State<WithinApp> createState() => _WithinAppState();
}

class _WithinAppState extends State<WithinApp> {
  // Held once so rebuilds don't resubscribe.
  late final _authChanges = widget.authService.authChanges;

  // Without Supabase (no keys in .env) there is nothing to sign in to, so go
  // straight home rather than strand the user on the auth screen.
  bool get _needsAuth =>
      widget.authService.isAvailable && !widget.authService.isSignedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Within',
      debugShowCheckedModeBanner: false,
      theme: WithinTheme.dark,
      // Rebuilds on sign in and sign out, swapping screens.
      home: StreamBuilder(
        stream: _authChanges,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          // The default layout centres children loosely, which shrinks the
          // screens to their content; make them fill the window instead.
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: _needsAuth
              ? AuthScreen(
                  key: const ValueKey('auth'),
                  authService: widget.authService,
                )
              : HomeScreen(
                  key: const ValueKey('home'),
                  teachingService: widget.teachingService,
                  widgetService: widget.widgetService,
                  authService: widget.authService,
                  clock: widget.clock,
                ),
        ),
      ),
    );
  }
}
