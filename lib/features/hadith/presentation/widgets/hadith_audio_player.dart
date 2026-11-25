import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_services.dart';
import '../../../../core/audio/audio_engine.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/models/hadith.dart';

/// Arabic recitation player on the Hadith screen.
///
/// * No recording → an honest "Cod lama hayo" card with disabled controls.
/// * With a recording → real streaming playback: play/pause, seek, time,
///   speed (0.75–1.5x), loading, Somali error with retry. Nothing is
///   downloaded until the user presses play. The engine is disposed when
///   the widget goes away (give it a key per hadith so switching hadith
///   stops the previous recording).
class HadithAudioPlayer extends StatelessWidget {
  const HadithAudioPlayer({super.key, required this.hadith});

  static const unavailableLabel = 'Cod lama hayo';
  static const loadFailedMessage = 'Codka lama soo rari karin. Hubi internetka kadibna isku day mar kale.';
  static const speeds = [0.75, 1.0, 1.25, 1.5];
  static const loadTimeout = Duration(seconds: 20);

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final audio = hadith.audio;
    // No recording: nothing is shown (no empty player).
    if (audio == null) return const SizedBox.shrink();
    return _StreamingPlayer(audio: audio, engineFactory: context.services.audioEngineFactory);
  }
}

String formatAudioTime(Duration? d) {
  if (d == null) return '--:--';
  final s = d.inSeconds;
  final m = s ~/ 60;
  final h = m ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${(m % 60).toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

class _StreamingPlayer extends StatefulWidget {
  const _StreamingPlayer({required this.audio, required this.engineFactory});

  final HadithAudio audio;
  final AudioEngineFactory engineFactory;

  @override
  State<_StreamingPlayer> createState() => _StreamingPlayerState();
}

class _StreamingPlayerState extends State<_StreamingPlayer> {
  AudioEngine? _engine;
  final _subs = <StreamSubscription<Object?>>[];
  AudioStatus _status = AudioStatus.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1.0;
  bool _preparing = false;
  bool _failed = false;
  Duration? _dragging;

  @override
  void initState() {
    super.initState();
    _duration = widget.audio.duration;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(engine.dispose().catchError((Object _) {}));
  }

  /// Creates the engine and starts streaming (first play, or retry).
  Future<void> _start() async {
    _release();
    final engine = widget.engineFactory();
    _engine = engine;
    setState(() {
      _preparing = true;
      _failed = false;
    });
    _subs
      ..add(engine.status.listen((s) => mounted ? setState(() => _status = s) : null, onError: (_) => _fail()))
      ..add(engine.position.listen((p) => mounted ? setState(() => _position = p) : null))
      ..add(engine.duration.listen((d) => d != null && mounted ? setState(() => _duration = d) : null));
    try {
      final d = await engine.load(widget.audio.url).timeout(HadithAudioPlayer.loadTimeout);
      if (!mounted || _engine != engine) return;
      if (d != null) _duration = d;
      await engine.setSpeed(_speed);
      await engine.play();
      if (mounted) setState(() => _preparing = false);
    } catch (_) {
      if (mounted && _engine == engine) _fail();
    }
  }

  void _fail() {
    _release();
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _failed = true;
      _status = AudioStatus.idle;
    });
  }

  Future<void> _togglePlay() async {
    final engine = _engine;
    if (engine == null) return _start();
    try {
      switch (_status) {
        case AudioStatus.playing:
          await engine.pause();
        case AudioStatus.completed:
          await engine.seek(Duration.zero);
          await engine.play();
        default:
          await engine.play();
      }
    } catch (_) {
      _fail();
    }
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    try {
      await _engine?.setSpeed(speed);
    } catch (_) {
      _fail();
    }
  }

  Future<void> _seek(Duration to) async {
    setState(() {
      _dragging = null;
      _position = to;
    });
    try {
      await _engine?.seek(to);
    } catch (_) {
      _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final audio = widget.audio;
    final loading = _preparing || _status == AudioStatus.loading;
    final playing = _status == AudioStatus.playing;
    final canSeek = _engine != null && !_preparing && (_duration?.inMilliseconds ?? 0) > 0;
    final total = _duration ?? Duration.zero;
    final shown = _dragging ?? (_position > total && total > Duration.zero ? total : _position);
    final label = _failed
        ? 'Cilad'
        : loading
        ? 'Waa la soo rarayaa…'
        : playing
        ? 'Waa la dhegeysanayaa'
        : _status == AudioStatus.completed
        ? 'Waa dhammaaday'
        : _engine == null
        ? 'Riix si aad u dhegeysato'
        : 'Waa la joojiyay';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: AppSizes.minTouchTarget + 8,
                child: loading
                    ? const Center(
                        child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                      )
                    : IconButton.filled(
                        tooltip: playing
                            ? 'Jooji'
                            : _status == AudioStatus.completed
                            ? 'Dib u dhegeyso'
                            : 'Dhegeyso',
                        onPressed: _failed ? null : _togglePlay,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : _status == AudioStatus.completed
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        iconSize: AppSizes.iconLg,
                      ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dhegeyso', style: context.textStyles.titleSmall),
                    Semantics(
                      liveRegion: true,
                      child: Text(label, style: context.textStyles.labelMedium?.copyWith(color: c.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: total.inMilliseconds <= 0 ? 0 : shown.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
            max: total.inMilliseconds <= 0 ? 1 : total.inMilliseconds.toDouble(),
            semanticFormatterCallback: (_) => '${formatAudioTime(shown)} ka mid ah ${formatAudioTime(_duration)}',
            onChanged: canSeek ? (v) => setState(() => _dragging = Duration(milliseconds: v.round())) : null,
            onChangeEnd: canSeek ? (v) => _seek(Duration(milliseconds: v.round())) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Text(formatAudioTime(shown), style: context.textStyles.labelSmall),
                const Spacer(),
                Text(formatAudioTime(_duration), style: context.textStyles.labelSmall),
              ],
            ),
          ),
          AppSpacing.gapXs,
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final s in HadithAudioPlayer.speeds)
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: s == _speed,
                  onSelected: _failed ? null : (_) => _setSpeed(s),
                ),
            ],
          ),
          if (_failed) ...[
            AppSpacing.gapSm,
            Semantics(
              liveRegion: true,
              child: Text(
                HadithAudioPlayer.loadFailedMessage,
                style: context.textStyles.bodySmall?.copyWith(color: context.colors.error),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppTextButton(label: 'Isku day mar kale', icon: Icons.refresh_rounded, onPressed: _start),
            ),
          ],
          AppSpacing.gapXs,
          Text('Akhriyaha: ${audio.reciter} · Isha: ${audio.sourceName}', style: context.textStyles.bodySmall),
          if (!audio.verified) ...[AppSpacing.gapXxs, const DemoContentBadge(label: 'Codka lama xaqiijin')],
        ],
      ),
    );
  }
}
