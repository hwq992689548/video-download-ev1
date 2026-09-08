import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Local copy of LaserPecker light colors / ThemeData (not a dependency).
abstract final class AppColors {
  static const theme = Color(0xFFFAC905);
  static const themePressed = Color(0xFFF2B602);
  static const themeDisabled = Color(0x57FAC905);

  static const textPrimary = Color(0xE5000000);
  static const textSecondary = Color(0x8A000000);
  static const textTertiary = Color(0x66000000);
  static const textQuaternary = Color(0x42000000);
  static const textWhite = Color(0xFFFFFFFF);

  static const background = Color(0xFFF2F1F6);
  static const surface = Color(0xFFFFFFFF);
  static const popup = Color(0xFFF6F6F6);
  static const mask = Color(0x66000000);

  static const fillThin = Color(0x0A000000);
  static const fillRegular = Color(0x14000000);
  static const divider = Color(0x1F000000);

  static const error = Color(0xFFDB382C);
  static const success = Color(0xFF00BD13);
  static const warning = Color(0xFFEB6E00);
  static const tip = Color(0xFF0066FF);
}

abstract final class AppRadii {
  static const card = 12.0;
  static const field = 10.0;
  static const pill = 20.0;
  static const button = 8.0;
}

ThemeData buildLightTheme() {
  const textPrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  const titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.theme,
      onPrimary: AppColors.textPrimary,
      primaryContainer: AppColors.theme,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.fillRegular,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: Color(0x33FAC905),
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.error,
      onError: AppColors.textWhite,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.popup,
      surfaceContainerHighest: AppColors.fillRegular,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.textPrimary,
      primaryContrastingColor: AppColors.theme,
      textTheme: CupertinoTextThemeData(
        textStyle: textPrimary,
        actionTextStyle: textPrimary,
        navActionTextStyle: textPrimary,
        navTitleTextStyle: titleMedium,
      ),
    ),
    appBarTheme: const AppBarTheme(
      foregroundColor: AppColors.textPrimary,
      backgroundColor: AppColors.surface,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      actionsPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
      centerTitle: true,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surface,
    canvasColor: AppColors.surface,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.theme,
      linearTrackColor: AppColors.fillRegular,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    primaryIconTheme: const IconThemeData(color: AppColors.textPrimary),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.theme,
      selectionColor: AppColors.theme.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.theme,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleMedium: titleMedium,
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: textPrimary,
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: titleMedium,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.theme,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.themeDisabled,
        disabledForegroundColor: AppColors.textQuaternary,
        textStyle: titleMedium,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textQuaternary,
        textStyle: titleMedium,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.theme, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dividerTheme: const DividerThemeData(
      space: 1,
      thickness: 0.5,
      color: AppColors.divider,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      height: 64,
      indicatorColor: AppColors.theme.withValues(alpha: 0.35),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return const IconThemeData(color: AppColors.textPrimary, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w500
              : FontWeight.w400,
          color: AppColors.textPrimary,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.popup,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
      elevation: const WidgetStatePropertyAll(0),
      hintStyle: const WidgetStatePropertyAll(
        TextStyle(color: AppColors.textTertiary, fontSize: 14),
      ),
      textStyle: const WidgetStatePropertyAll(textPrimary),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textPrimary,
      textColor: AppColors.textPrimary,
      tileColor: AppColors.surface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.fillRegular,
      selectedColor: AppColors.theme.withValues(alpha: 0.55),
      labelStyle: titleMedium,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
  );
}

class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
