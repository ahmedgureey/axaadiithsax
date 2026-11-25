import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// "Hagaha isticmaalaha" — a short illustrated walkthrough. Each page shows a
/// small drawing of the screen with the button to tap highlighted, a title
/// and one or two short sentences.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  static const title = 'Hagaha isticmaalaha';

  /// Support contact (WhatsApp), Somalia +252.
  static const whatsAppDisplay = '0612341376';
  static final whatsAppUri = Uri.parse('https://wa.me/252612341376');

  /// (title, text) of each guide page, in order.
  static const pages = <(String, String)>[
    ('Ku soo dhowow', '42-ka xadiis ee Imaam an-Nawawi, Carabi iyo Soomaali. Wuxuu shaqeeyaa internet la\'aan.'),
    ('Raadi xadiis', 'Riix Raadinta, qor eray Carabi ama Soomaali ah. Ereyga waa la calaamadeeyaa.'),
    ('Akhri oo keydi', 'A− / A+ wuxuu beddelaa cabbirka. Astaamaha hoose: koobiyee, la wadaag, keydi.'),
    ('Xifdi oo is tijaabi', 'Xifdinta: riix "Waan xifdiyey". Imtixaanka: su\'aalo gaagaaban.'),
    ('Xasuusin', 'Aniga → Dejinta → Ogeysiisyada: shid xasuusinta oo dooro waqtiga.'),
  ];

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == HelpScreen.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go(AppRoutes.profile);

  void _next() {
    if (_isLast) return _close();
    _controller.nextPage(duration: AppDurations.medium, curve: Curves.easeOut);
  }

  Future<void> _openWhatsApp() async {
    final ok = await launchUrl(
      HelpScreen.whatsAppUri,
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);
    if (!ok && mounted) {
      AppSnackbar.show(
        context,
        'WhatsApp lama furi karo. Lambarka: ${HelpScreen.whatsAppDisplay}',
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = HelpScreen.pages.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      label: '${HelpScreen.title}, bogga ${_page + 1} ee $total',
                      excludeSemantics: true,
                      child: Text(
                        'HAGAHA ISTICMAALKA  ${_page + 1} / $total',
                        style: context.textStyles.labelLarge?.copyWith(
                          letterSpacing: 1.2,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _close, child: const Text('Ka bood')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _GuidePage(index: i, onWhatsApp: _openWhatsApp),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? context.colors.primary : context.colors.outlineVariant,
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(label: _isLast ? 'Dhammee' : 'Xiga', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  const _GuidePage({required this.index, required this.onWhatsApp});

  final int index;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final (title, text) = HelpScreen.pages[index];
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSpacing.gapMd,
              _PhoneMock(child: _illustration(index)),
              AppSpacing.gapLg,
              Text(title, style: context.textStyles.headlineSmall, textAlign: TextAlign.center),
              AppSpacing.gapXs,
              Text(
                text,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyLarge?.copyWith(color: context.appColors.textSecondary),
              ),
              if (index == HelpScreen.pages.length - 1) ...[
                AppSpacing.gapLg,
                OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  icon: Icon(Icons.chat_rounded, color: context.appColors.success),
                  label: const Text('WhatsApp · ${HelpScreen.whatsAppDisplay}'),
                ),
              ],
              AppSpacing.gapMd,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _illustration(int i) => switch (i) {
    0 => const _WelcomeMock(),
    1 => const _SearchMock(),
    2 => const _ReaderMock(),
    3 => const _MemorizeMock(),
    _ => const _RemindersMock(),
  };
}

// ── Drawings ────────────────────────────────────────────────────────────────

/// A simple phone frame around a drawing.
class _PhoneMock extends StatelessWidget {
  const _PhoneMock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: context.colors.outlineVariant, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: context.colors.surfaceContainerLow, borderRadius: BorderRadius.circular(26)),
          child: child,
        ),
      ),
    );
  }
}

/// Grey placeholder lines that stand for text.
class _Lines extends StatelessWidget {
  const _Lines({this.count = 2, this.rtl = false});

  final int count;
  final bool rtl;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          height: 7,
          width: i.isEven ? 150 : 105,
          decoration: BoxDecoration(color: context.colors.outlineVariant, borderRadius: AppRadius.pillAll),
        ),
    ],
  );
}

/// Highlights the element to tap: gold ring and a pointing hand.
class _Tap extends StatelessWidget {
  const _Tap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.gold, width: 2.5),
        ),
        child: Padding(padding: const EdgeInsets.all(3), child: child),
      ),
      Positioned(
        right: -10,
        bottom: -16,
        child: Icon(Icons.touch_app_rounded, color: context.appColors.gold, size: 28),
      ),
    ],
  );
}

class _MockCard extends StatelessWidget {
  const _MockCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(14)),
    child: child,
  );
}

class _WelcomeMock extends StatelessWidget {
  const _WelcomeMock();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('42', style: context.textStyles.headlineMedium?.copyWith(color: context.colors.onPrimary)),
            Text('Xadiis', style: context.textStyles.labelMedium?.copyWith(color: context.colors.onPrimary)),
          ],
        ),
      ),
      AppSpacing.gapSm,
      Text('Arbaciin', style: context.textStyles.titleMedium),
      const ArabicText('الأربعون النووية', variant: ArabicTextVariant.label, textAlign: TextAlign.center),
      AppSpacing.gapSm,
      const _MockCard(child: _Lines(rtl: true)),
      AppSpacing.gapXs,
      const _MockCard(child: _Lines()),
      AppSpacing.gapSm,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: const [
          MetaChip(label: '42', icon: Icons.menu_book_rounded),
          MetaChip(label: 'AR · SO', icon: Icons.translate_rounded),
          MetaChip(label: 'Offline', icon: Icons.cloud_off_outlined),
        ],
      ),
    ],
  );
}

class _SearchMock extends StatelessWidget {
  const _SearchMock();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Tap(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.pillAll),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18),
              AppSpacing.gapXs,
              Text('انما', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      ),
      AppSpacing.gapLg,
      _MockCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '... '),
                  TextSpan(
                    text: 'إِنَّمَا',
                    style: TextStyle(backgroundColor: context.appColors.gold.withValues(alpha: 0.35)),
                  ),
                  const TextSpan(text: ' الْأَعْمَالُ بِالنِّيَّاتِ'),
                ],
              ),
              textDirection: TextDirection.rtl,
              style: ArabicTextStyles.hadith(context, fontSize: 18),
            ),
            const _Lines(count: 1),
          ],
        ),
      ),
      AppSpacing.gapXs,
      const _MockCard(child: _Lines()),
    ],
  );
}

class _ReaderMock extends StatelessWidget {
  const _ReaderMock();

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData i) => Icon(i, size: 18, color: context.colors.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _Tap(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: context.appColors.goldSubtle, borderRadius: AppRadius.pillAll),
              child: Text('A−   26   A+', style: context.textStyles.labelLarge),
            ),
          ),
        ),
        AppSpacing.gapMd,
        const _MockCard(child: _Lines(count: 3, rtl: true)),
        AppSpacing.gapXs,
        const _MockCard(child: _Lines()),
        AppSpacing.gapMd,
        _Tap(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                icon(Icons.translate_rounded),
                icon(Icons.copy_rounded),
                icon(Icons.copy_all_rounded),
                icon(Icons.share_rounded),
                icon(Icons.bookmark_border_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemorizeMock extends StatelessWidget {
  const _MemorizeMock();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MockCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qorshaha maanta  1 / 3', style: context.textStyles.labelLarge),
            AppSpacing.gapXs,
            ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: 1 / 3,
                minHeight: 6,
                backgroundColor: context.colors.outlineVariant,
              ),
            ),
          ],
        ),
      ),
      AppSpacing.gapMd,
      _Tap(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: context.colors.primary, borderRadius: AppRadius.pillAll),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: context.colors.onPrimary),
              AppSpacing.gapXs,
              Flexible(
                child: Text(
                  'Waan xifdiyey',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelLarge?.copyWith(color: context.colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
      AppSpacing.gapLg,
      for (final (letter, ok) in [('A', false), ('B', true), ('C', false)])
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ok ? context.appColors.success : context.colors.outlineVariant),
          ),
          child: Row(
            children: [
              Text(letter, style: context.textStyles.labelMedium),
              AppSpacing.gapSm,
              const Expanded(child: _Lines(count: 1)),
              if (ok) Icon(Icons.check_circle_rounded, size: 16, color: context.appColors.success),
            ],
          ),
        ),
    ],
  );
}

class _RemindersMock extends StatelessWidget {
  const _RemindersMock();

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String time, {bool on = false, bool tap = false}) {
      final r = Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.textStyles.labelLarge),
                  Text(time, style: context.textStyles.labelSmall),
                ],
              ),
            ),
            Switch(value: on, onChanged: (_) {}),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: tap ? _Tap(child: r) : r,
      );
    }

    return Column(
      children: [
        Icon(Icons.notifications_active_outlined, size: 40, color: context.appColors.goldText),
        AppSpacing.gapSm,
        row('Xadiiska maalinta', '08:00', on: true, tap: true),
        row('Xasuusinta xifdinta', '19:00'),
        row('Dib-u-eegista', '17:00'),
      ],
    );
  }
}
