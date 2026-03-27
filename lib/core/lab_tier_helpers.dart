import 'package:flutter/material.dart';

// ── Tier Colors (consistent across labs screens) ────────────────────────────

const kOptimalColor = Color(0xFF16A34A);
const kSufficientColor = Color(0xFF2563EB);
const kSuboptimalColor = Color(0xFFD97706);
const kCriticalColor = Color(0xFFDC2626);
const kUnknownTierColor = Color(0xFF64748B);

Color getTierColor(String? tier) => switch (tier) {
      'optimal' => kOptimalColor,
      'sufficient' => kSufficientColor,
      'suboptimal' => kSuboptimalColor,
      'critical' => kCriticalColor,
      _ => kUnknownTierColor,
    };

String getTierLabel(String? tier) => switch (tier) {
      'optimal' => 'OPTIMAL',
      'sufficient' => 'SUFFICIENT',
      'suboptimal' => 'NEEDS WORK',
      'critical' => 'CRITICAL',
      _ => 'UNKNOWN',
    };
