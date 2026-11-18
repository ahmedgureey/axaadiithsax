import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/quiz_generator.dart';
import '../domain/quiz_models.dart';
import '../domain/quiz_session.dart';
import 'widgets/quiz_question_card.dart';

/// Runs a quiz built from [config]. Questions are generated once, when the
/// screen opens; insufficient data shows an explanation instead.
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({super.key, this.config, this.generator});

  final QuizConfig? config;

  /// Override for tests (seeded randomness).
  final QuizGenerator? generator;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  QuizSession? _session;
  String? _problem;
  bool _finishing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null || _problem != null) return;
    final services = context.services;
    final config = widget.config ?? const QuizConfig();
    final build = (widget.generator ?? QuizGenerator(services.repository)).generate(
      config,
      favoriteIds: services.favorites.ids.toSet(),
      memorizedIds: {for (final r in services.memorization.recentlyMemorized) r.hadithId},
    );
    if (build.isEmpty) {
      _problem = build.problem;
    } else {
      _session = QuizSession(build.questions, config: config);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final result = _session!.finish();
    final router = GoRouter.of(context);
    await context.services.memorization.recordQuiz(
      total: result.total,
      correct: result.correct,
      seconds: result.duration?.inSeconds,
    );
    router.pushReplacement(AppRoutes.quizResults, extra: result);
  }

  Future<bool> _confirmLeave() async {
    final s = _session;
    if (s == null || _finishing) return true;
    return showConfirmDialog(
      context,
      title: 'Ka bax imtixaanka?',
      message: 'Jawaabaha aad bixisay lama keydin doono.',
      confirmLabel: 'Ka bax',
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Imtixaan'),
        body: EmptyStateWidget(
          icon: Icons.quiz_outlined,
          title: 'Imtixaan lama samayn karo',
          message: _problem ?? 'Xog kuma filna.',
          actionLabel: 'Beddel doorashada',
          onAction: () => context.canPop() ? context.pop() : context.go(AppRoutes.quiz),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final n = session.index + 1;
          return Scaffold(
            appBar: AppTopBar(title: 'Su\'aal $n / ${session.total}'),
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                AppPageBody(
                  child: Semantics(
                    label: 'Su\'aal $n ka mid ah ${session.total}',
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: AppRadius.pillAll,
                      child: LinearProgressIndicator(value: n / session.total, minHeight: 6),
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                AppPageBody(
                  child: QuizQuestionCard(
                    key: ValueKey(session.index),
                    question: session.current,
                    selected: session.answerFor(session.index),
                    onSelect: session.submit,
                  ),
                ),
                AppSpacing.gapLg,
              ],
            ),
            // Always visible once answered — no scrolling past the explanation.
            // Note: a min-height Column — AppPageBody's Align would expand to
            // fill the whole screen inside bottomNavigationBar.
            bottomNavigationBar: session.currentAnswered
                ? SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                            child: PrimaryButton(
                              label: session.isLast ? 'Arag natiijada' : 'Su\'aasha xigta',
                              icon: session.isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                              onPressed: session.isLast ? _finish : session.next,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
