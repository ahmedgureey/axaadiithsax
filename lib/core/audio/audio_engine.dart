import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Playback state reported by an [AudioEngine].
enum AudioStatus { idle, loading, ready, playing, completed }

/// Minimal playback interface used by the hadith audio player. The real
/// implementation streams with just_audio; tests use a fake. Each player
/// widget owns one engine and disposes it.
abstract class AudioEngine {
  Stream<AudioStatus> get status;
  Stream<Duration> get position;
  Stream<Duration?> get duration;

  /// Prepares [url] for streaming (nothing is downloaded before this call).
  /// Returns the duration when known. Throws on failure.
  Future<Duration?> load(Uri url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

/// Creates engines; replaceable in tests.
typedef AudioEngineFactory = AudioEngine Function();

/// Streaming playback with just_audio (Android, iOS, web).
class JustAudioEngine implements AudioEngine {
  JustAudioEngine() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<AudioStatus> get status => _player.playerStateStream.map((s) {
    switch (s.processingState) {
      case ProcessingState.idle:
        return AudioStatus.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioStatus.loading;
      case ProcessingState.completed:
        return AudioStatus.completed;
      case ProcessingState.ready:
        return s.playing ? AudioStatus.playing : AudioStatus.ready;
    }
  });

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Duration?> get duration => _player.durationStream;

  @override
  Future<Duration?> load(Uri url) => _player.setAudioSource(AudioSource.uri(url));

  // just_audio's play() completes when playback stops, so it is not awaited.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();
}
