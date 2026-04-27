import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// PetPogo "The Curated Companion" 主题
/// 字体：Plus Jakarta Sans（设计规范 §15.3）
/// 设计原则：
///   — 无 1px 边框分割，用背景色层次
///   — 阴影带品牌棕红色调
///   — Material3 ColorScheme 精确对齐设计 Token
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          // Primary
          primary:          AppColors.primary,
          onPrimary:        AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          // Secondary (青绿)
          secondary:          AppColors.secondary,
          onSecondary:        AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          // Tertiary (金黄)
          tertiary:          AppColors.tertiary,
          onTertiary:        AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiaryContainer,
          // Error
          error:          AppColors.error,
          onError:        AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          // Surface
          surface:        AppColors.surface,
          onSurface:      AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          surfaceContainerLowest:  AppColors.surfaceContainerLowest,
          surfaceContainerLow:     AppColors.surfaceContainerLow,
          surfaceContainer:        AppColors.surfaceContainer,
          surfaceContainerHigh:    AppColors.surfaceContainerHigh,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          // Outline
          outline:        AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          // Inverse
          inversePrimary: AppColors.inversePrimary,
          inverseSurface: AppColors.inverseSurface,
          onInverseSurface: AppColors.inverseOnSurface,
          // Scrim / Shadow
          scrim: AppColors.ambientShadow,
          shadow: AppColors.ambientShadow,
        ),
        scaffoldBackgroundColor: AppColors.surface,

        // ── 字体：Plus Jakarta Sans ────────────────────
        // 注：google_fonts 包的 plusJakartaSans 即为 Plus Jakarta Sans
        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          // Display — Hero 大标题，紧字距
          displayLarge:  GoogleFonts.plusJakartaSans(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -0.02 * 56, color: AppColors.onSurface),
          displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w700, letterSpacing: -0.02 * 45, color: AppColors.onSurface),
          displaySmall:  GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.02 * 36, color: AppColors.onSurface),
          // Headline
          headlineLarge:  GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.01 * 32, color: AppColors.onSurface),
          headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.01 * 28, color: AppColors.onSurface),
          headlineSmall:  GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          // Title
          titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurface),
          titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface),
          // Body
          bodyLarge:  GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface),
          bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurface),
          bodySmall:  GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
          // Label — 元数据标签
          labelLarge:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.01 * 14, color: AppColors.onSurface),
          labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.01 * 12, color: AppColors.onSurface),
          labelSmall:  GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.01 * 11, color: AppColors.onSurfaceVariant),
        ),

        // ── AppBar ─────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primary,
          ),
        ),

        // ── Card ───────────────────────────────────────
        // 卡片用色调层次 + 品牌阴影，无边框
        cardTheme: CardThemeData(
          color: AppColors.surfaceContainerLowest,
          elevation: 0,
          shadowColor: AppColors.cardShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),

        // ── Elevated Button (Primary) ──────────────────
        // Pill 形，渐变效果通过 BoxDecoration 在自定义 Widget 实现
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            shadowColor: AppColors.primaryGlow,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(48), // xl pill
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Outlined / Text Button ─────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.15)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(48),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Input — "Clear Field" 风格 ─────────────────
        // 填充式，无任何边框（包括焦点状态）
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,  // 无焦点边框
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),

        // ── Divider — 禁止使用！仅保留极低透明度 ────────
        dividerTheme: DividerThemeData(
          color: AppColors.outlineVariant.withOpacity(0.10),
          thickness: 0,
          space: 0,
        ),

        // ── BottomNavigationBar ────────────────────────
        // 玻璃态效果在 app.dart 中用 ClipRRect + BackdropFilter 实现
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Plus Jakarta Sans',
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),

        // ── Chip ──────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceContainerLow,
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          side: BorderSide.none,
        ),

        // ── FloatingActionButton ───────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          elevation: 0,
          shape: CircleBorder(),
        ),

        // ── Icon ──────────────────────────────────────
        iconTheme: const IconThemeData(
          color: AppColors.onSurface,
          size: 24,
        ),
        primaryIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 24,
        ),

        // ── SnackBar ──────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.inverseSurface,
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.inverseOnSurface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
