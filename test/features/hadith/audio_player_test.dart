import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/app/app.dart';
import 'package:xadiithapp/core/audio/audio_engine.dart';
import 'package:xadiithapp/core/routing/app_routes.dart';
import 'package:xadiithapp/core/settings/app_settings_controller.dart';
import 'package:xadiithapp/data/models/hadith.dart';
import 'package:xadiithapp/data/remote/catalog_mapper.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/features/hadith/presentation/widgets/hadith_audio_player.dart';

import '../../support/test_library.dart';

/// Records every call; streams are driven by the test. No real audio.
class FakeAudioEngine implements AudioEngine {
  FakeAudioEngine({this.failLoad = false, this.loadDuration = const Duration(seconds: 90)});

  final bool failLoad;
  final Duration? loadDuration;
  final calls = <String>[];
  final _status = StreamController<AudioStatus>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  bool disposed = false;
  Uri? loaded;

  void emitStatus(AudioStatus s) => _status.add(s);
  void emitPosition(Duration p) => _position.add(p);

  @override
  Stream<AudioStatus> get status => _status.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration?> get duration => _duration.stream;

  @override
  Future<Duration?> load(Uri url) async {
    calls.add('load');
    loaded = url;
    if (failLoad) throw Exception('network');
    return loadDuration;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _status.add(AudioStatus.playing);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _status.add(AudioStatus.ready);
  }

  @override
  Future<void> seek(Duration position) async => calls.add('seek:${position.inSeconds}');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed:$speed');

  @override
  Future<void> dispose() async {
    disposed = true;
    await _status.close();
    await _position.close();
    await _duration.close();
  }
}

// Placeholder URL, never fetched (the engine is fake).
final _audio = HadithAudio(
  url: Uri.parse('https://example.invalid/test-1.mp3'),
  reciter: 'TEST reciter',
  sourceName: 'TEST source',
  license: 'TEST licence',
);

Hadith _withAudio(Hadith h, HadithAudio a) => Hadith(
  id: h.id,
  bookId: h.bookId,
  chapterId: h.chapterId,
  number: h.number,
  arabicText: h.arabicText,
  somaliText: h.somaliText,
  narrator: h.narrator,
  categoryIds: h.categoryIds,
  source: h.source,
  audio: a,
);

const _id = 'muslim-c1-h1';
const _next = 'muslim-c1-h2';

HadithRepository _repo() => HadithRepository(
  chapters: TestLibrary.chapters,
  hadiths: [
    for (final h in TestLibrary.hadiths)
      if (h.id == _id)
        _withAudio(h, _audio)
      else if (h.id == _next)
        _withAudio(
          h,
          HadithAudio(
            url: Uri.parse('https://example.invalid/test-2.mp3'),
            reciter: 'TEST reciter',
            sourceName: 'TEST source',
            license: 'TEST licence',
          ),
        )
      else
        h,
  ],
);

Future<List<FakeAudioEngine>> _pump(WidgetTester tester, {bool failFirstLoad = false}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final engines = <FakeAudioEngine>[];
  final services = await createTestServices(
    InMemorySettingsStore({'auth.onboardingSeen': true}),
    repository: _repo(),
    audioEngineFactory: () {
      final e = FakeAudioEngine(failLoad: failFirstLoad && engines.isEmpty);
      engines.add(e);
      return e;
    },
  );
  await tester.pumpWidget(XadiisApp(services: services, initialLocation: AppRoutes.hadith(_id)));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Dhegeyso'), 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  return engines;
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

void main() {
  test('formatAudioTime', () {
    expect(formatAudioTime(null), '--:--');
    expect(formatAudioTime(const Duration(seconds: 5)), '0:05');
    expect(formatAudioTime(const Duration(minutes: 3, seconds: 42)), '3:42');
    expect(formatAudioTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  testWidgets('nothing is loaded until play; play streams the linked URL and pause works', (tester) async {
    final engines = await _pump(tester);
    expect(engines, isEmpty, reason: 'no download before the user presses play');
    expect(find.text('Akhriyaha: TEST reciter · Isha: TEST source'), findsOneWidget);
    expect(find.text('Codka lama xaqiijin'), findsOneWidget);

    await _tapTooltip(tester, 'Dhegeyso');
    final e = engines.single;
    expect(e.loaded, _audio.url);
    expect(e.calls, ['load', 'speed:1.0', 'play']);
    expect(find.text('Waa la dhegeysanayaa'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget, reason: 'duration from the stream source');

    e.emitPosition(const Duration(seconds: 45));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0:45'), findsOneWidget);

    await _tapTooltip(tester, 'Jooji');
    expect(e.calls.last, 'pause');
    expect(find.text('Waa la joojiyay'), findsOneWidget);
  });

  testWidgets('speed and seeking go to the engine', (tester) async {
    final engines = await _pump(tester);
    await _tapTooltip(tester, 'Dhegeyso');
    await tester.tap(find.text('1.25x'));
    await tester.pumpAndSettle();
    expect(engines.single.calls, contains('speed:1.25'));

    final slider = find.byType(Slider);
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
    await tester.pumpAndSettle();
    expect(engines.single.calls.where((c) => c.startsWith('seek:')), isNotEmpty);
  });

  testWidgets('completed audio replays from the start', (tester) async {
    final engines = await _pump(tester);
    await _tapTooltip(tester, 'Dhegeyso');
    engines.single.emitStatus(AudioStatus.completed);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Waa dhammaaday'), findsOneWidget);
    await _tapTooltip(tester, 'Dib u dhegeyso');
    expect(engines.single.calls.sublist(engines.single.calls.length - 2), ['seek:0', 'play']);
  });

  testWidgets('load failure shows a Somali error; retry uses a fresh engine', (tester) async {
    final engines = await _pump(tester, failFirstLoad: true);
    await _tapTooltip(tester, 'Dhegeyso');
    expect(find.text(HadithAudioPlayer.loadFailedMessage), findsOneWidget);
    expect(engines.first.disposed, isTrue);
    expect(find.text('Waa la dhegeysanayaa'), findsNothing, reason: 'no fake playback');

    await tester.ensureVisible(find.text('Isku day mar kale'));
    await tester.tap(find.text('Isku day mar kale'));
    await tester.pumpAndSettle();
    expect(engines, hasLength(2));
    expect(engines.last.calls, ['load', 'speed:1.0', 'play']);
    expect(find.text(HadithAudioPlayer.loadFailedMessage), findsNothing);
  });

  testWidgets('moving to the next hadith disposes the playing engine', (tester) async {
    final engines = await _pump(tester);
    await _tapTooltip(tester, 'Dhegeyso');
    await tester.tap(find.text('Xadiiska xiga'));
    await tester.pumpAndSettle();
    expect(engines.single.disposed, isTrue, reason: 'previous recording stopped');
    await tester.scrollUntilVisible(find.text('Dhegeyso'), 300, scrollable: find.byType(Scrollable).first);
    await _tapTooltip(tester, 'Dhegeyso');
    expect(engines.last.loaded.toString(), 'https://example.invalid/test-2.mp3');
  });

  group('CatalogMapper.audio', () {
    Map<String, dynamic> row({
      Object? url = 'https://example.invalid/a.mp3',
      Object? license = 'L',
      String status = 'published',
    }) => {
      'audio_url': url,
      'reciter': 'R',
      'source_name': 'S',
      'license': license,
      'duration_seconds': 61.5,
      'verified_at': '2026-11-23T00:00:00Z',
      'status': status,
    };

    test('published https row with reciter, source and licence is used', () {
      final a = CatalogMapper.audio([row()])!;
      expect(a.url.toString(), 'https://example.invalid/a.mp3');
      expect(a.duration, const Duration(milliseconds: 61500));
      expect(a.verified, isTrue);
      expect(a.language, 'ar');
    });

    test('unsafe or incomplete rows are dropped', () {
      expect(CatalogMapper.audio([row(url: 'http://example.invalid/a.mp3')]), isNull);
      expect(CatalogMapper.audio([row(license: ' ')]), isNull);
      expect(CatalogMapper.audio([row(status: 'verified')]), isNull);
      expect(CatalogMapper.audio(null), isNull);
    });

    test('offline cache keeps the audio metadata', () {
      final h = _withAudio(TestLibrary.hadiths.first, _audio);
      final back = CatalogMapper.hadithFromJson(CatalogMapper.hadithToJson(h))!;
      expect(back.audio?.url, _audio.url);
      expect(back.audio?.license, 'TEST licence');
    });
  });
}
