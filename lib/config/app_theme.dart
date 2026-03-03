import 'package:flutter/material.dart';

/// Minimalist 3-color palette: Gold · Black · White
/// Automatically adapts to system light/dark mode.
/// Usage: `final c = AppColors.of(context);`
class AppColors {
  final Brightness brightness;

  const AppColors._({required this.brightness});

  factory AppColors.of(BuildContext context) {
    return AppColors._(brightness: Theme.of(context).brightness);
  }

  bool get isDark => brightness == Brightness.dark;

  // ── Brand colors ──
  Color get gold => const Color(0xFFD4A843);
  Color get goldLight => const Color(0xFFF5D990);
  Color get goldDim => const Color(0xFFB08C35);

  // Semantic aliases (all map to gold/white variants)
  Color get promo => gold;
  Color get routeBlue => gold;
  Color get success => goldLight;
  Color get error => isDark
      ? Colors.white.withValues(alpha: 0.85)
      : Colors.black.withValues(alpha: 0.75);

  // ── Backgrounds ──
  Color get bg => isDark ? const Color(0xFF08090C) : const Color(0xFFF2F2F7);
  Color get panel => isDark ? const Color(0xFF101114) : Colors.white;
  Color get surface => isDark ? const Color(0xFF161719) : Colors.white;
  Color get cardBg => isDark ? const Color(0xFF0E0F12) : Colors.white;

  // ── Text ──
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get textSecondary => isDark
      ? Colors.white.withValues(alpha: 0.50)
      : const Color(0xFF8E8E93);
  Color get textTertiary => isDark
      ? Colors.white.withValues(alpha: 0.30)
      : const Color(0xFFC7C7CC);
  Color get textOnGold => const Color(0xFF0A0800);

  // ── Borders & dividers ──
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.06);
  Color get divider => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.black.withValues(alpha: 0.04);

  // ── Shadows ──
  Color get shadow => Colors.black.withValues(alpha: isDark ? 0.35 : 0.08);

  // ── Icon colors ──
  Color get iconDefault => isDark
      ? Colors.white.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.45);
  Color get iconMuted => isDark
      ? Colors.white.withValues(alpha: 0.20)
      : Colors.black.withValues(alpha: 0.15);
  Color get chevron => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.10);

  // ── Search bar ──
  Color get searchText => isDark
      ? Colors.white.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.35);
  Color get searchBorder => gold.withValues(alpha: 0.25);

  // ── Chip button ──
  Color get chipText => isDark
      ? Colors.white.withValues(alpha: 0.65)
      : Colors.black.withValues(alpha: 0.55);
  Color get chipBorder => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.08);

  // ── Bottom nav ──
  Color get navInactive => isDark
      ? Colors.white.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.30);
  Color get navActiveBg => gold.withValues(alpha: 0.10);

  // ── Ride card gradients (all gold-based) ──
  List<Color> get rideCardVip => isDark
      ? [const Color(0xFF1A1500), const Color(0xFF100E00)]
      : [const Color(0xFFFFF8E8), const Color(0xFFFFF3D6)];
  List<Color> get rideCardPremium => isDark
      ? [const Color(0xFF12120E), const Color(0xFF0D0D0A)]
      : [const Color(0xFFFAF9F6), const Color(0xFFF5F4F0)];
  List<Color> get rideCardComfort => isDark
      ? [const Color(0xFF0F0F0C), const Color(0xFF0A0A08)]
      : [const Color(0xFFF8F8F5), const Color(0xFFF3F3F0)];

  // ── Ride card text ──
  Color get rideCardVehicle => isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get rideCardSub => isDark
      ? Colors.white.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.40);
  Color get rideCardBorder => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.06);

  // ── Notification badge ──
  Color get badgeText => const Color(0xFF0A0800);

  // ── Map panel ──
  Color get mapPanel => isDark ? const Color(0xFF111214) : Colors.white;
  Color get mapSurface => isDark ? const Color(0xFF1A1B1E) : const Color(0xFFF2F2F7);

  // ── Splash ──
  Color get splashBg => isDark ? const Color(0xFF050505) : const Color(0xFFF2F2F7);
}

// ── Theme data builders ──

const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
  },
);

final ThemeData darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF08090C),
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFD4A843),
    surface: Color(0xFF101114),
  ),
  pageTransitionsTheme: _pageTransitions,
);

final ThemeData lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: const Color(0xFFF2F2F7),
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFD4A843),
    surface: Color(0xFFF2F2F7),
  ),
  pageTransitionsTheme: _pageTransitions,
);
