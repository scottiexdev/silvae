import 'package:flutter/material.dart';

/// Il verde di Silvae, desaturato quanto basta per stare accanto a un grigio
/// caldo senza gridare.
const Color silvaeGreen = Color(0xFF2F6B4F);

/// Le costanti che tengono insieme le schermate: un solo raggio per i
/// contenitori, uno più stretto per quel che ci sta dentro.
abstract final class Radii {
  static const double card = 16;
  static const double field = 12;
  static const double chip = 10;
  static const double badge = 6;
}

/// Il passo verticale. Le schermate respirano a multipli di questo.
abstract final class Insets {
  static const double gutter = 20;
  static const double gap = 12;
  static const double section = 28;

  /// Sotto le liste resta lo spazio per il pulsante flottante.
  static const double bottom = 104;
}

/// La larghezza oltre la quale il testo smette di essere leggibile: sul web
/// una lista a tutto schermo diventa una riga lunga un metro.
const double readableWidth = 920;

/// Il punto in cui la navigazione passa dalla barra in basso alla colonna
/// laterale: su un monitor la barra in basso è lontana dagli occhi.
const double wideLayout = 900;

extension TabularText on TextStyle {
  /// Cifre a larghezza fissa: ore e date incolonnate non ballano da una riga
  /// all'altra.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

const ColorScheme _light = ColorScheme(
  brightness: Brightness.light,
  primary: silvaeGreen,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD2E6D9),
  onPrimaryContainer: Color(0xFF0C2A1B),
  secondary: Color(0xFF5F6E5C),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE0E7DB),
  onSecondaryContainer: Color(0xFF1B2419),
  tertiary: Color(0xFF7C5E33),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF0E2CB),
  onTertiaryContainer: Color(0xFF2A1D06),
  error: Color(0xFF9C3B2E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF6DCD6),
  onErrorContainer: Color(0xFF3A0F09),
  surface: Color(0xFFFBFAF6),
  onSurface: Color(0xFF1A1D19),
  onSurfaceVariant: Color(0xFF585E55),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF6F5EF),
  surfaceContainer: Color(0xFFF1F0E9),
  surfaceContainerHigh: Color(0xFFEBEAE2),
  surfaceContainerHighest: Color(0xFFE5E4DB),
  outline: Color(0xFF8A9086),
  outlineVariant: Color(0xFFDBDCD2),
  inverseSurface: Color(0xFF2E312C),
  onInverseSurface: Color(0xFFF1F0E9),
  inversePrimary: Color(0xFF9BD2AF),
  shadow: Color(0xFF1A1D19),
  scrim: Color(0xFF000000),
);

const ColorScheme _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9BD2AF),
  onPrimary: Color(0xFF0A2416),
  primaryContainer: Color(0xFF23503A),
  onPrimaryContainer: Color(0xFFBCEACD),
  secondary: Color(0xFFBCC9B6),
  onSecondary: Color(0xFF26301F),
  secondaryContainer: Color(0xFF3B4636),
  onSecondaryContainer: Color(0xFFD7E4D0),
  tertiary: Color(0xFFE0C393),
  onTertiary: Color(0xFF3F2E10),
  tertiaryContainer: Color(0xFF5A4423),
  onTertiaryContainer: Color(0xFFF6E0BC),
  error: Color(0xFFEBA79A),
  onError: Color(0xFF521711),
  errorContainer: Color(0xFF70281E),
  onErrorContainer: Color(0xFFF9DAD3),
  surface: Color(0xFF12150F),
  onSurface: Color(0xFFE3E4DC),
  onSurfaceVariant: Color(0xFFB7BCB1),
  surfaceContainerLowest: Color(0xFF0D100B),
  surfaceContainerLow: Color(0xFF1A1E17),
  surfaceContainer: Color(0xFF1E221B),
  surfaceContainerHigh: Color(0xFF282D24),
  surfaceContainerHighest: Color(0xFF33382E),
  outline: Color(0xFF878D81),
  outlineVariant: Color(0xFF3A3F35),
  inverseSurface: Color(0xFFE3E4DC),
  onInverseSurface: Color(0xFF2E312C),
  inversePrimary: silvaeGreen,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

ThemeData silvaeTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? _dark : _light;
  final base = ThemeData(brightness: brightness, colorScheme: colors);
  final text = _textTheme(base.textTheme, colors);

  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
    textTheme: text,
    dividerColor: colors.outlineVariant,
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardSurface(colors),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surfaceContainerLow,
      indicatorColor: colors.primaryContainer,
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: colors.onSurface,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.onSurface,
      unselectedLabelColor: colors.onSurfaceVariant,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: colors.outlineVariant,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colors.primary, width: 2.5),
        insets: const EdgeInsets.symmetric(horizontal: 4),
      ),
      overlayColor: WidgetStatePropertyAll(
        colors.primary.withValues(alpha: .06),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      labelStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      border: _fieldBorder(colors.outlineVariant),
      enabledBorder: _fieldBorder(colors.outlineVariant),
      disabledBorder: _fieldBorder(colors.outlineVariant.withValues(alpha: .5)),
      focusedBorder: _fieldBorder(colors.primary, width: 1.6),
      errorBorder: _fieldBorder(colors.error),
      focusedErrorBorder: _fieldBorder(colors.error, width: 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: text.labelLarge,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 1,
      extendedTextStyle: text.labelLarge,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field + 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.primaryContainer,
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      iconColor: colors.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardSurface(colors),
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card + 4),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardSurface(colors),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Radii.card + 8),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: colors.outline, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.surfaceContainerHigh,
      circularTrackColor: colors.surfaceContainerHigh,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      textColor: colors.onSurface,
      collapsedTextColor: colors.onSurface,
      iconColor: colors.onSurfaceVariant,
      collapsedIconColor: colors.onSurfaceVariant,
    ),
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.field),
      borderSide: BorderSide(color: color, width: width),
    );

/// Titoli stretti e pesanti, etichette larghe e leggere: la gerarchia si legge
/// prima del contenuto.
TextTheme _textTheme(TextTheme base, ColorScheme colors) => base.copyWith(
  displaySmall: base.displaySmall?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    height: 1.1,
  ),
  headlineMedium: base.headlineMedium?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.15,
  ),
  headlineSmall: base.headlineSmall?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  ),
  titleLarge: base.titleLarge?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  ),
  titleMedium: base.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  ),
  titleSmall: base.titleSmall?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  ),
  bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
  bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
  bodySmall: base.bodySmall?.copyWith(
    height: 1.4,
    color: colors.onSurfaceVariant,
  ),
  labelLarge: base.labelLarge?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  ),
  labelMedium: base.labelMedium?.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  ),
  labelSmall: base.labelSmall?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  ),
);

/// La carta su cui poggiano schede, dialoghi e fogli. Di giorno è più chiara
/// della pagina, di notte è più chiara lo stesso: quel che è sollevato prende
/// più luce, non meno.
Color cardSurface(ColorScheme colors) => colors.brightness == Brightness.dark
    ? colors.surfaceContainerLow
    : colors.surfaceContainerLowest;
