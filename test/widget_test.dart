import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:within/app/within_app.dart';
import 'package:within/services/teaching_service.dart';
import 'package:within/services/widget_service.dart';

class _FakeWidgetService extends WidgetService {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  final service = TeachingService.fromJsonString(
    File('assets/teachings/buddhism.json').readAsStringSync(),
  );

  testWidgets('shows the teaching for the current date and refreshes widgets', (
    tester,
  ) async {
    final widgets = _FakeWidgetService();
    final now = DateTime(2025, 1, 2, 9);

    await tester.pumpWidget(
      WithinApp(
        teachingService: service,
        widgetService: widgets,
        clock: () => now,
      ),
    );

    final expected = service.forDate(now);
    expect(find.text(expected.text), findsOneWidget);
    expect(find.text(expected.reference), findsOneWidget);
    expect(find.text('Paraphrase'), findsOneWidget);
    expect(find.text('THURSDAY, 2 JANUARY'), findsOneWidget);
    expect(widgets.refreshes, 1);
  });

  testWidgets('opens widget instructions', (tester) async {
    await tester.pumpWidget(
      WithinApp(teachingService: service, widgetService: _FakeWidgetService()),
    );

    await tester.tap(find.text('Add the widget to your phone'));
    await tester.pumpAndSettle();

    expect(find.text('LOCK SCREEN'), findsOneWidget);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });
}
