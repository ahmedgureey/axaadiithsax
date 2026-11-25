import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/core/app_info.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/core/update/update_checker.dart';
import 'package:xadiithapp/core/update/update_prompt.dart';

import '../../support/test_library.dart';

Map<String, Object> _json({int latest = 12, int min = 10, String url = 'https://example.invalid/app.apk'}) => {
  'latest_build': latest,
  'min_build': min,
  'version': '2.0.0',
  'apk_url': url,
  'message': 'TEST message',
};

Future<void> _pump(WidgetTester tester, UpdateChecker checker) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await createTestServices(
    InMemorySettingsStore({'auth.onboardingSeen': true}),
    updateChecker: checker,
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.home));
  await tester.pumpAndSettle();
}

void main() {
  group('Decision', () {
    test('below min_build → required; below latest → optional; up to date → nothing', () {
      expect(UpdateChecker.parse(_json(), 9)!.kind, UpdateKind.required);
      expect(UpdateChecker.parse(_json(), 11)!.kind, UpdateKind.optional);
      expect(UpdateChecker.parse(_json(), 12), isNull);
      expect(UpdateChecker.parse(_json(), 13), isNull);
    });

    test('invalid data never blocks (bad url, missing fields, not json)', () {
      expect(UpdateChecker.parse(_json(url: 'http://insecure.example/app.apk'), 1), isNull);
      expect(UpdateChecker.parse({'min_build': 99}, 1), isNull);
      expect(UpdateChecker.parse('oops', 1), isNull);
    });

    test('offline / errors → no update shown', () async {
      final offline = UpdateChecker(fetch: (_) async => throw const SocketException('offline'), currentBuild: 1);
      expect(await offline.check(), isNull);
      final notFound = UpdateChecker(fetch: (_) async => null, currentBuild: 1);
      expect(await notFound.check(), isNull);
    });

    test('the shipped update.json does not ask the current build to update', () {
      final file = jsonDecode(File('update.json').readAsStringSync());
      expect(UpdateChecker.parse(file, int.parse(AppInfo.buildNumber)), isNull);
      expect((file as Map)['latest_build'], int.parse(AppInfo.buildNumber), reason: 'update.json matches pubspec');
    });
  });

  group('Prompt', () {
    testWidgets('required update: cannot be dismissed, only "Cusboonaysii"', (tester) async {
      await _pump(tester, UpdateChecker(fetch: (_) async => jsonEncode(_json()), currentBuild: 9));
      expect(find.text(UpdatePrompt.requiredTitle), findsOneWidget);
      expect(find.text(UpdatePrompt.laterLabel), findsNothing);
      expect(find.text(UpdatePrompt.updateLabel), findsOneWidget);
      // Back button and a tap outside do not close it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(UpdatePrompt.requiredTitle), findsOneWidget);
    });

    testWidgets('optional update: "Marka dambe" closes it, shown once per session', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        UpdateChecker(
          fetch: (_) async {
            calls++;
            return jsonEncode(_json());
          },
          currentBuild: 11,
        ),
      );
      expect(find.text(UpdatePrompt.optionalTitle), findsOneWidget);
      await tester.tap(find.text(UpdatePrompt.laterLabel));
      await tester.pumpAndSettle();
      expect(find.text(UpdatePrompt.optionalTitle), findsNothing);
      await tester.tap(find.text('Kutubta'));
      await tester.pumpAndSettle();
      expect(calls, 1, reason: 'checked once per app start');
    });

    testWidgets('up to date: nothing shown', (tester) async {
      await _pump(tester, UpdateChecker(fetch: (_) async => jsonEncode(_json()), currentBuild: 12));
      expect(find.text(UpdatePrompt.requiredTitle), findsNothing);
      expect(find.text(UpdatePrompt.optionalTitle), findsNothing);
    });
  });

  group('Hubi cusboonaysiin (report)', () {
    test('reports build numbers and the outcome', () async {
      final r = await UpdateChecker(fetch: (_) async => jsonEncode(_json()), currentBuild: 9).report();
      expect(r.currentBuild, 9);
      expect(r.latestBuild, 12);
      expect(r.minBuild, 10);
      expect(r.info!.kind, UpdateKind.required);
      expect(r.summary, 'Cusboonaysiin qasab ah ayaa jirta.');
      final upToDate = await UpdateChecker(fetch: (_) async => jsonEncode(_json()), currentBuild: 12).report();
      expect(upToDate.summary, 'App-kaagu waa nooca ugu dambeeyay.');
    });

    test('explains offline / missing file / bad file', () async {
      final offline = await UpdateChecker(
        fetch: (_) async => throw const SocketException('x'),
        currentBuild: 9,
      ).report();
      expect(offline.summary, 'Internet lama heli karo.');
      final missing = await UpdateChecker(fetch: (_) async => null, currentBuild: 9).report();
      expect(missing.summary, 'Faylka update.json lama helin.');
      final bad = await UpdateChecker(fetch: (_) async => '{oops', currentBuild: 9).report();
      expect(bad.summary, 'update.json si sax ah looma akhrin karo.');
    });

    testWidgets('button on Ku saabsan shows the result with both build numbers', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var calls = 0;
      final services = await createTestServices(
        InMemorySettingsStore({'auth.onboardingSeen': true}),
        updateChecker: UpdateChecker(
          fetch: (_) async {
            calls++;
            return jsonEncode(_json(latest: 9, min: 9));
          },
          currentBuild: 9,
        ),
      );
      services.updateCheckDone = true; // only the manual check
      await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.about));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hubi cusboonaysiin'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Hubi cusboonaysiin'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('App-kaagu waa nooca ugu dambeeyay.'), findsOneWidget);
      expect(find.text('App-kaaga (build)'), findsOneWidget);
    });
  });
}
