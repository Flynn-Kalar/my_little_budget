import 'package:flutter/material.dart';

import 'theme_colors.dart';

class AppTokens {
  static const income = Color(0xFF2563EB);
  static const expense = Color(0xFFDC2626);
  static const transfer = Color(0xFFFFAE00);
  static const background = Color(0xFFECFEEF);
  static const surface = Color(0xFFF5FFF7);
  static const accent = Color(0xFF646464);
  static const warning = Color(0xFF5E00D1);

  static const sidebarBg = Color(0xFFF5FFF7);
  static const sidebarBorder = Color(0xFFD8E8DC);
  static const sidebarActive = Color(0xFFE3F5E8);

  static const primaryText = Color(0xFF111827);
  static const secondaryText = Color(0xFF374151);
  static const titleText = Color(0xFF0F172A);
  static const disabledText = Color(0xFF9CA3AF);
  static const muted = secondaryText;
}

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.accent,
    required this.warning,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color accent;
  final Color warning;

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? accent,
    Color? warning,
  }) {
    return AppSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppThemeColors on BuildContext {
  AppSemanticColors get _semanticColors {
    return Theme.of(this).extension<AppSemanticColors>() ??
        const AppSemanticColors(
          income: AppTokens.income,
          expense: AppTokens.expense,
          transfer: AppTokens.transfer,
          accent: AppTokens.accent,
          warning: AppTokens.warning,
        );
  }

  Color get appIncome => _semanticColors.income;

  Color get appExpense => _semanticColors.expense;

  Color get appTransfer => _semanticColors.transfer;

  Color get appAccent => _semanticColors.accent;

  Color get appWarning => _semanticColors.warning;

  Color get desktopIncome => appIncome;

  Color get desktopExpense => appExpense;

  Color get desktopTransfer => appTransfer;

  Color get desktopAccent => appAccent;

  Color get desktopWarning => appWarning;

  Color get desktopBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get desktopSurface => Theme.of(this).colorScheme.surface;

  Color get desktopBorder => Theme.of(this).dividerColor;

  Color get desktopMuted {
    final theme = Theme.of(this);
    return theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.86 : 0.76,
    );
  }

  Color get desktopSelectedSurface {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : AppTokens.sidebarActive;
  }

  Color get desktopSidebarBackground {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : AppTokens.sidebarBg;
  }
}

ThemeData buildAppTheme({
  ThemeColors colors = defaultTheme,
  Brightness brightness = Brightness.light,
}) {
  final effectiveColors = colors;
  final isDark = brightness == Brightness.dark;

  final primaryText = isDark ? Colors.white : AppTokens.primaryText;
  final secondaryText = isDark
      ? Colors.white.withValues(alpha: 0.75)
      : AppTokens.secondaryText;
  final disabledText = isDark
      ? Colors.white.withValues(alpha: 0.45)
      : AppTokens.disabledText;
  final divider = isDark
      ? const Color(0xFF56596F).withValues(alpha: 0.72)
      : AppTokens.sidebarBorder.withValues(alpha: 0.86);
  final activeSurface = isDark
      ? effectiveColors.surface.withValues(alpha: 0.82)
      : AppTokens.sidebarActive;
  final onPrimary = _readableOn(effectiveColors.income);
  final onSecondary = _readableOn(effectiveColors.accent);

  final scheme = ColorScheme.fromSeed(
    seedColor: effectiveColors.income,
    brightness: brightness,
    primary: effectiveColors.income,
    secondary: effectiveColors.accent,
    surface: effectiveColors.surface,
    error: effectiveColors.expense,
    onSurface: primaryText,
    onPrimary: onPrimary,
    onSecondary: onSecondary,
  );

  final textTheme = ThemeData(
    brightness: brightness,
  ).textTheme.apply(bodyColor: primaryText, displayColor: primaryText);

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: divider),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [
      AppSemanticColors(
        income: effectiveColors.income,
        expense: effectiveColors.expense,
        transfer: effectiveColors.transfer,
        accent: effectiveColors.accent,
        warning: effectiveColors.warning,
      ),
    ],
    scaffoldBackgroundColor: effectiveColors.background,
    disabledColor: disabledText,
    dividerColor: divider,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: effectiveColors.background,
      foregroundColor: primaryText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: effectiveColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: divider),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: effectiveColors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: primaryText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: secondaryText),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: effectiveColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: effectiveColors.surface,
      modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.32),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: effectiveColors.surface,
      indicatorColor: activeSurface,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? disabledText
            : primaryText;
        return TextStyle(color: color, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        final disabled = states.contains(WidgetState.disabled);
        return IconThemeData(
          color: disabled
              ? disabledText
              : (selected ? primaryText : secondaryText),
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: activeSurface,
      foregroundColor: primaryText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: effectiveColors.surface,
      labelStyle: TextStyle(color: secondaryText),
      hintStyle: TextStyle(color: secondaryText),
      prefixIconColor: secondaryText,
      suffixIconColor: secondaryText,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: effectiveColors.income, width: 1.5),
      ),
      disabledBorder: inputBorder,
    ),
    listTileTheme: ListTileThemeData(
      textColor: primaryText,
      iconColor: secondaryText,
    ),
    dividerTheme: DividerThemeData(color: divider),
    chipTheme: ChipThemeData(
      backgroundColor: effectiveColors.surface,
      selectedColor: activeSurface,
      disabledColor: effectiveColors.surface.withValues(alpha: 0.65),
      labelStyle: TextStyle(color: primaryText),
      secondaryLabelStyle: TextStyle(color: primaryText),
      side: BorderSide(color: divider),
    ),
  );
}

Color _readableOn(Color color) {
  return color.computeLuminance() > 0.46 ? Colors.black : Colors.white;
}
