import 'package:flutter/material.dart';

abstract final class NavAblePalette {
  static const navy = Color(0xFF0F2B4D);
  static const green = Color(0xFF5BC66B);
  static const greenDark = Color(0xFF278A47);
  static const accent = Color(0xFFF3FFF4);
  static const canvas = Color(0xFFF3F7F4);
  static const surface = Color(0xFFF8FAF8);
  static const text = Color(0xFF4A5563);
  static const border = Color(0xFFDCE5DE);
  static const darkCanvas = Color(0xFF101820);
  static const darkSurface = Color(0xFF18232E);
  static const darkText = Color(0xFFD1D9E0);
  static const darkBorder = Color(0xFF31404D);
}

abstract final class NavAblePreferences {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final textScale = ValueNotifier<double>(1);
  static final language = ValueNotifier<String>('English (United States)');
}

abstract final class NavAbleSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const cardInset = 18.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class NavAbleRadius {
  static const small = 8.0;
  static const tile = 12.0;
  static const control = 14.0;
  static const button = 16.0;
  static const card = 18.0;
  static const pill = 999.0;
}

abstract final class NavAbleSize {
  static const compactControl = 48.0;
  static const control = 52.0;
  static const field = 56.0;
  static const primaryButton = 56.0;
  static const minimumTouchTarget = 48.0;
  static const navigationBar = 70.0;
}

abstract final class NavAbleTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NavAblePalette.green,
      brightness: Brightness.light,
      primary: NavAblePalette.navy,
      secondary: NavAblePalette.green,
      surface: NavAblePalette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NavAblePalette.canvas,
      canvasColor: NavAblePalette.canvas,
      hoverColor: NavAblePalette.green.withValues(alpha: 0.08),
      splashColor: NavAblePalette.green.withValues(alpha: 0.12),
      highlightColor: NavAblePalette.green.withValues(alpha: 0.06),
      focusColor: NavAblePalette.green.withValues(alpha: 0.12),
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: NavAblePalette.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: NavAblePalette.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: NavAblePalette.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: NavAblePalette.text, height: 1.45),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NavAblePalette.surface,
        foregroundColor: NavAblePalette.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NavAblePalette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
          borderSide: const BorderSide(color: NavAblePalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
          borderSide: const BorderSide(color: NavAblePalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
          borderSide: const BorderSide(color: NavAblePalette.green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
          borderSide: const BorderSide(color: Color(0xFFB42318)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(NavAbleSize.minimumTouchTarget, NavAbleSize.control),
          ),
          backgroundColor: const WidgetStatePropertyAll(NavAblePalette.navy),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NavAbleRadius.button),
            ),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 1;
            if (states.contains(WidgetState.hovered)) return 9;
            return 5;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return NavAblePalette.green.withValues(alpha: 0.12);
            }
            return null;
          }),
          animationDuration: const Duration(milliseconds: 160),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(NavAblePalette.navy),
          side: const WidgetStatePropertyAll(
            BorderSide(color: NavAblePalette.border, width: 1.3),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NavAbleRadius.button),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            NavAblePalette.green.withValues(alpha: 0.09),
          ),
          animationDuration: const Duration(milliseconds: 160),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NavAblePalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: NavAbleSize.navigationBar,
        indicatorColor: NavAblePalette.green.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? NavAblePalette.navy
                : NavAblePalette.text,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? NavAblePalette.greenDark
                : NavAblePalette.text,
            size: 22,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NavAblePalette.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.tile),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NavAblePalette.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: NavAblePalette.green,
      brightness: Brightness.dark,
      primary: NavAblePalette.green,
      secondary: NavAblePalette.green,
      surface: NavAblePalette.darkSurface,
    );

    return light.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: NavAblePalette.darkCanvas,
      canvasColor: NavAblePalette.darkCanvas,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: NavAblePalette.darkText, height: 1.45),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NavAblePalette.darkSurface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NavAblePalette.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: NavAbleSize.navigationBar,
        indicatorColor: NavAblePalette.green.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : NavAblePalette.darkText,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? NavAblePalette.green
                : NavAblePalette.darkText,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: NavAblePalette.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

class NavAbleSurface extends StatefulWidget {
  const NavAbleSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NavAbleSpacing.cardInset),
    this.borderRadius = NavAbleRadius.card,
    this.color = NavAblePalette.surface,
    this.onTap,
    this.enableHover = false,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color color;
  final VoidCallback? onTap;
  final bool enableHover;
  final double? width;

  @override
  State<NavAbleSurface> createState() => _NavAbleSurfaceState();
}

class _NavAbleSurfaceState extends State<NavAbleSurface> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!widget.enableHover || _hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lift = _pressed ? 1.0 : (_hovered ? -2.0 : 0.0);
    final darkOpacity = _pressed ? 0.045 : (_hovered ? 0.12 : 0.075);

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: widget.width,
          padding: widget.padding,
          transform: Matrix4.translationValues(0, lift, 0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isDark
                  ? NavAblePalette.darkBorder
                  : Colors.white.withValues(alpha: 0.88),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.95),
                blurRadius: _hovered ? 15 : 11,
                offset: const Offset(-5, -5),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: _hovered ? 0.42 : 0.32)
                    : NavAblePalette.navy.withValues(alpha: darkOpacity),
                blurRadius: _hovered ? 24 : 18,
                offset: _pressed ? const Offset(2, 3) : const Offset(7, 9),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class NavAbleHoverLift extends StatefulWidget {
  const NavAbleHoverLift({super.key, required this.child});

  final Widget child;

  @override
  State<NavAbleHoverLift> createState() => _NavAbleHoverLiftState();
}

class _NavAbleHoverLiftState extends State<NavAbleHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _hovered ? const Offset(0, -0.025) : Offset.zero,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
