import 'package:flutter/material.dart';

/// Centrální helper pro responsivní velikosti napříč aplikací.
/// **iPhone-only**: aplikace cílí na iPhone (`TARGETED_DEVICE_FAMILY = 1`),
/// takže scale je vyladěn pro rozsah iPhone SE až iPhone 16 Pro Max
/// (320–430 pt šířka).
///
/// Použití:
///   final r = Responsive.of(context);
///   Text('Ahoj', style: TextStyle(fontSize: r.fontBody));
///   Padding(padding: EdgeInsets.all(r.spaceMd), ...);
///   SizedBox(width: r.iconLg, height: r.iconLg);
///
/// Globální `textScaler` z `main.dart` (slider „Velikost textu" v Settings)
/// se aplikuje navrch – Responsive škáluje **podle velikosti zařízení**,
/// textScaler navrch podle **preference uživatele**.
class Responsive {
  final MediaQueryData mq;
  final double width;
  final double height;
  final bool isCompact; // iPhone SE / mini (< 380 pt)
  final double scale;

  Responsive._(this.mq)
      : width = mq.size.width,
        height = mq.size.height,
        // Compact = staré malé iPhony (SE 1.gen, mini), kde se musí
        // hodně škrtnout. Většina iPhonů od 14 výš je 390+.
        isCompact = mq.size.width < 380,
        // Reference iPhone 14 (390 pt). Clamp pro iPhone SE (320) –> 0.82
        // až iPhone 16 Pro Max (430) –> 1.10.
        scale = (mq.size.width / 390.0).clamp(0.82, 1.10);

  static Responsive of(BuildContext context) =>
      Responsive._(MediaQuery.of(context));

  // ─── Fonty ─────────────────────────────────────────────────────────
  double get fontCaption => 11 * scale; // poznámky, popisky
  double get fontSmall => 12 * scale;
  double get fontBody => 14 * scale; // odstavce
  double get fontBodyLg => 16 * scale; // důležitější text
  double get fontTitle => 18 * scale;
  double get fontTitleLg => 20 * scale;
  double get fontHeadline => 22 * scale; // velký nadpis stránky
  double get fontDisplay => 32 * scale; // velký BPM/hodnoty
  double get fontDisplayXl => 42 * scale; // hero číslo (v summary)

  // ─── Spacing ───────────────────────────────────────────────────────
  double get spaceXs => 4 * scale;
  double get spaceSm => 8 * scale;
  double get spaceMd => 12 * scale;
  double get spaceLg => 16 * scale;
  double get spaceXl => 20 * scale;
  double get spaceXxl => 28 * scale;

  // ─── Ikony ─────────────────────────────────────────────────────────
  double get iconSm => 16 * scale;
  double get iconMd => 22 * scale;
  double get iconLg => 28 * scale;
  double get iconXl => 36 * scale;

  // ─── Layout primitives ─────────────────────────────────────────────

  /// Standardní padding stránky.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: isCompact ? 12.0 : 16.0,
        vertical: spaceLg,
      );

  /// Symmetric padding pro AlertDialog.
  EdgeInsets get dialogInsetPadding => EdgeInsets.symmetric(
        horizontal: isCompact ? 12.0 : 20.0,
        vertical: 24.0,
      );

  /// Počet sloupců v gridu metrik. Vždy 1 na compact, jinak 2.
  int get gridColumns => isCompact ? 1 : 2;

  /// Doporučená výška PPG chartu (portrait-only).
  double get chartHeight => (height * 0.22).clamp(150.0, 230.0);

  /// Pixels-per-second pro PPG chart.
  double get chartPixelsPerSecond => (20.0 * scale).clamp(16.0, 24.0);

  /// Kruhová kamera (live preview) – proporcionální s clampingem.
  double get cameraSize => (width * 0.25).clamp(96.0, 140.0);
}
