import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_services.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../settings/notification_preferences_controller.dart';

/// "Sii wad akhriska" — the last hadith actually opened (persisted reading
/// history). Renders nothing when nothing has been read yet, so it never
/// suggests progress that does not exist.
class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.services;
    final repo = services.repository;
    return ListenableBuilder(
      listenable: Listenable.merge([services.history, services.repository]),
      builder: (context, _) {
        final id = services.history.lastId;
        final hadith = id == null ? null : repo.hadithById(id);
        if (hadith == null) return const SizedBox.shrink();
        final book = repo.bookById(hadith.bookId);
        final chapter = repo.chapterById(hadith.chapterId);
        final order = repo.readingOrderOf(hadith.bookId);
        final position = order.indexWhere((h) => h.id == hadith.id) + 1;
        void open() => context.push(AppRoutes.hadith(hadith.id));
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: AppCard(
            onTap: open,
            semanticLabel:
                '${context.tr(AppText.homeContinueReading)}: ${book?.nameSomali ?? ''}, #${hadith.displayNumber}',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: AppRadius.cardAll),
                  child: Icon(Icons.auto_stories_rounded, color: context.colors.onPrimaryContainer),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(AppText.homeContinueReading), style: context.textStyles.titleSmall),
                      Text(
                        '${book?.nameSomali ?? '—'} · ${chapter?.titleSomali ?? ''} · #${hadith.displayNumber}',
                        style: context.textStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (position > 0 && order.isNotEmpty) ...[
                        AppSpacing.gapXs,
                        ClipRRect(
                          borderRadius: AppRadius.pillAll,
                          child: LinearProgressIndicator(
                            value: position / order.length,
                            minHeight: 4,
                            semanticsLabel: '${context.tr(AppText.readerPosition)}: $position / ${order.length}',
                            semanticsValue: '${(position * 100 / order.length).round()}',
                          ),
                        ),
                        AppSpacing.gapXxs,
                        Text('$position / ${order.length} kitaabkan', style: context.textStyles.labelSmall),
                      ],
                    ],
                  ),
                ),
                AppSpacing.gapSm,
                Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Today's memorisation numbers from the real memorisation controller.
class HomeMemorizationSummary extends StatelessWidget {
  const HomeMemorizationSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.services.memorization;
    return ListenableBuilder(
      listenable: Listenable.merge([m, context.services.repository]),
      builder: (context, _) {
        final due = m.dueForReview.length;
        final subtitle = m.plannedToday == 0
            ? 'Xadiisyada la heli karo oo dhan waad xifdisay.'
            : due == 0
            ? 'Maanta · dib-u-eegis ma sugayso'
            : 'Maanta · $due dib-u-eegis ayaa sugaya';
        return MemorizationProgressCard(
          title: context.tr(AppText.homeMemorizationProgress),
          subtitle: subtitle,
          memorized: m.completedToday,
          total: m.plannedToday,
          streakDays: m.streak > 0 ? m.streak : null,
          onTap: () => context.go(AppRoutes.memorization),
        );
      },
    );
  }
}

/// Daily reading reminder state. Reminders are preferences only (no
/// notification service exists), and the card says so.
class ReadingReminderCard extends StatelessWidget {
  const ReadingReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.services.notifications;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final on = prefs.isEnabled(ReminderKind.dailyHadith);
        final time = NotificationPreferencesController.formatTime(prefs.reminderTime);
        return AppCard(
          onTap: () => context.push(AppRoutes.settingsNotifications),
          child: Row(
            children: [
              Icon(
                on ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
                color: context.appColors.goldText,
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr(AppText.homeReminder), style: context.textStyles.titleSmall),
                    Text(
                      on
                          ? 'Doorbid: maalin kasta $time · weli lama diro'
                          : 'Dansan · riix si aad u dejiso (doorbid oo keliya)',
                      style: context.textStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}
