import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_tokens.dart';

/// PetPogo 暖棕粉红主题
/// 字体：Plus Jakarta Sans + 中文回退（AppFonts）
/// 色值 / 间距 / 圆角 / 字号见 docs/design-tokens.md
/// 设计原则：
///   — 分隔优先用背景层次（surfacePage / surfaceCard / surfaceSunken）；
///     必要时用 1px borderSubtle，不用带透明度的描边
///   — 阴影带品牌棕红色调
///   — Material3 ColorScheme 精确对齐设计 Token
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
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
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: TextStyle(fontFamily: AppFonts.primary, fontSize: 18,
              fontWeight: FontWeight.w700, color: AppColors.onSurface),
          contentTextStyle: TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
              height: 1.5, color: AppColors.onSurfaceVariant),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: AppColors.surfaceContainerLow,
          headerForegroundColor: AppColors.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: AppColors.surfaceContainerLowest,
          dialBackgroundColor: AppColors.surfaceContainerLow,
          dialHandColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        ),

        // ── 字体：Plus Jakarta Sans（英文）+ Noto Sans SC（中文回退）─
        // 注：google_fonts 包的 plusJakartaSans 即为 Plus Jakarta Sans
        // 中文字符自动回退到 Noto Sans SC（思源黑体），Google 官方设计字体
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
          titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),   // 页面标题
          titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurface),
          titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),   // 区块标题
          // Body
          bodyLarge:  GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface),
          bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),   // 正文
          bodySmall:  GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
          // Label — 元数据标签
          labelLarge:  GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.01 * 13, color: AppColors.textPrimary),   // 列表标题
          labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.01 * 12, color: AppColors.onSurface),
          labelSmall:  GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.01 * 11, color: AppColors.textTertiary),
        ).apply(
          // 中文回退字体：统一从 AppFonts.chineseFallback 读取，改字体只改 app_fonts.dart
          fontFamilyFallback: AppFonts.fallback,
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
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.brandPrimaryStrong,
          ).copyWith(
            fontFamilyFallback: AppFonts.fallback,
          ),
        ),

        // ── Card ───────────────────────────────────────
        // 卡片用色调层次 + 品牌阴影，无边框
        cardTheme: CardThemeData(
          color: AppColors.surfaceContainerLowest,
          elevation: 0,
          shadowColor: AppColors.cardShadow,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
          ),
          margin: EdgeInsets.zero,
        ),

        // ── Elevated / Filled Button (Primary) ─────────
        // 主操作唯一色 brandPrimary；按压态 brandPrimaryStrong
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _primaryButtonStyle,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _primaryButtonStyle,
        ),

        // ── Outlined / Text Button ─────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandPrimary,
            side: BorderSide(color: AppColors.borderSubtle),
            minimumSize: const Size(AppSize.touchMin, AppSize.touchMin),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x24, vertical: AppSpacing.x12),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.controlRadius,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandPrimary,
            minimumSize: const Size(AppSize.touchMin, AppSize.touchMin),
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
          fillColor: AppColors.surfaceSunken,
          border: const OutlineInputBorder(
            borderRadius: AppRadius.controlRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.controlRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadius.controlRadius,
            borderSide: BorderSide.none,  // 无焦点边框
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.controlRadius,
            borderSide: BorderSide(color: AppColors.statusAlert),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x16, vertical: AppSpacing.x16),
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),

        // ── Divider — 1px border-subtle ───────────────
        dividerTheme: DividerThemeData(
          color: AppColors.borderSubtle,
          thickness: 1,
          space: 0,
        ),

        // ── BottomNavigationBar ────────────────────────
        // 玻璃态效果在 app.dart 中用 ClipRRect + BackdropFilter 实现
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.brandPrimary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.latin,
            fontFamilyFallback: AppFonts.fallback,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: AppFonts.latin,
            fontFamilyFallback: AppFonts.fallback,
          ),
        ),

        // ── Chip ──────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceSunken,
          selectedColor: AppColors.brandPrimarySoft,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
          side: BorderSide.none,
        ),

        // ── FloatingActionButton ───────────────────────
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.textOnBrand,
          elevation: 0,
          shape: CircleBorder(),
        ),

        // ── Icon ──────────────────────────────────────
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        primaryIconTheme: IconThemeData(
          color: AppColors.brandPrimary,
          size: 24,
        ),

        // ── Progress ──────────────────────────────────
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.brandPrimary,
        ),

        // ── SnackBar ──────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.inverseSurface,
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.inverseOnSurface,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlRadius,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

  /// 主按钮样式：brandPrimary 底 / textOnBrand 字 / 按压 brandPrimaryStrong
  static ButtonStyle get _primaryButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.brandPrimary.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.brandPrimaryStrong;
          }
          return AppColors.brandPrimary;
        }),
        foregroundColor: WidgetStatePropertyAll(AppColors.textOnBrand),
        overlayColor: WidgetStatePropertyAll(
            AppColors.brandPrimaryStrong.withValues(alpha: 0.12)),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(AppColors.primaryGlow),
        minimumSize:
            const WidgetStatePropertyAll(Size(AppSize.touchMin, AppSize.touchMin)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
            horizontal: AppSpacing.x24, vertical: AppSpacing.x12)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
        )),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        )),
      );

  /// 数据 / 时间 / 数字用等宽字体（仅限短数据）
  static TextStyle monoData({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'Courier New'],
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
