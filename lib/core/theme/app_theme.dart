import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_theme_colors.dart';
import 'app_typography.dart';

/// Central ThemeData for light and dark mode.
abstract final class AppTheme {
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primaryGreen,
    onPrimary: AppPalette.pureWhite,
    primaryContainer: AppPalette.lightGreen,
    onPrimaryContainer: AppPalette.deepGreen,
    secondary: AppPalette.darkGold,
    onSecondary: AppPalette.pureWhite,
    secondaryContainer: Color(0xFFF3E8CF),
    onSecondaryContainer: Color(0xFF3D2E10),
    tertiary: AppPalette.deepGreen,
    onTertiary: AppPalette.pureWhite,
    error: AppPalette.error,
    onError: AppPalette.pureWhite,
    errorContainer: Color(0xFFF9E1DF),
    onErrorContainer: Color(0xFF5C1513),
    surface: AppPalette.warmCream,
    onSurface: AppPalette.textPrimary,
    onSurfaceVariant: AppPalette.textSecondary,
    surfaceContainerLowest: AppPalette.pureWhite,
    surfaceContainerLow: AppPalette.pureWhite,
    surfaceContainer: Color(0xFFF4EFE1),
    surfaceContainerHigh: AppPalette.creamDeep,
    surfaceContainerHighest: Color(0xFFEAE2CE),
    outline: Color(0xFFC9C6B8),
    outlineVariant: AppPalette.divider,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: AppPalette.deepGreen,
    onInverseSurface: AppPalette.warmCream,
    inversePrimary: Color(0xFF8CCBA6),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: AppPalette.darkOnPrimary,
    primaryContainer: AppPalette.darkPrimaryContainer,
    onPrimaryContainer: Color(0xFFD6EEDF),
    secondary: AppPalette.nightGold,
    onSecondary: Color(0xFF2E2208),
    secondaryContainer: Color(0xFF4A3B1C),
    onSecondaryContainer: Color(0xFFF3E3C0),
    tertiary: Color(0xFFB9DCC6),
    onTertiary: AppPalette.darkOnPrimary,
    error: AppPalette.darkError,
    onError: AppPalette.darkOnError,
    errorContainer: Color(0xFF6B1E1B),
    onErrorContainer: Color(0xFFFBDAD7),
    surface: AppPalette.darkBackground,
    onSurface: AppPalette.darkTextPrimary,
    onSurfaceVariant: AppPalette.darkTextSecondary,
    surfaceContainerLowest: Color(0xFF0A140F),
    surfaceContainerLow: AppPalette.darkSurface,
    surfaceContainer: AppPalette.darkSurface,
    surfaceContainerHigh: AppPalette.darkSurfaceHigh,
    surfaceContainerHighest: AppPalette.darkSurfaceHighest,
    outline: Color(0xFF4F6458),
    outlineVariant: AppPalette.darkDivider,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: AppPalette.darkTextPrimary,
    onInverseSurface: AppPalette.darkBackground,
    inversePrimary: AppPalette.primaryGreen,
  );

  static ThemeData get light => _build(lightScheme, AppThemeColors.light);
  static ThemeData get dark => _build(darkScheme, AppThemeColors.dark);

  static ThemeData _build(ColorScheme scheme, AppThemeColors c) {
    final textTheme = AppTypography.textTheme(c);
    final isDark = scheme.brightness == Brightness.dark;
    final cardColor = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    final inputFill = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: AppRadius.buttonAll,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.uiFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: c.divider,
      extensions: [c],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.icon),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: c.cardBorder),
        ),
      ),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          textStyle: textTheme.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: c.textDisabled,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.minTouchTarget),
          iconSize: AppSizes.icon,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: scheme.primary),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 1.6),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
        disabledBorder: inputBorder(scheme.outlineVariant.withValues(alpha: 0.5)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.onSurface.withValues(alpha: 0.08),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.icon,
            color: selected ? scheme.onPrimaryContainer : c.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: isDark ? AppPalette.primaryGreen : AppPalette.softGold,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.primaryContainer,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primaryContainer,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: AppSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: AppRadius.smAll),
        textStyle: textTheme.labelSmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
