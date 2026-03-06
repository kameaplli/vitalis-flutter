import 'package:flutter/foundation.dart';

class ApiConstants {
  // Railway backend URL — update this after deploying to Railway.
  // e.g. 'https://vitalis-backend-production.up.railway.app'
  static const String _railwayUrl = 'https://web-production-7665e.up.railway.app';

  static String get baseUrl {
    if (kIsWeb) {
      // Web: use the same host the page was loaded from (works on localhost and LAN).
      return 'http://${Uri.base.host}:8000';
    }
    // Android / iOS: use the Railway URL so the app works on any network.
    return _railwayUrl;
  }

  /// Resolves a URL that may be absolute (Supabase Storage) or relative (legacy).
  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;   // already absolute
    return '$baseUrl$path';                      // legacy relative path
  }

  // Auth
  static const String login = '/api/login';
  static const String register = '/api/register';
  static const String logout = '/api/logout';
  static const String user = '/api/user';
  static const String tokenRefresh = '/api/token/refresh';

  // Dashboard
  static const String dashboard = '/api/dashboard';

  // Foods
  static const String foodDatabase = '/api/foods/database';
  static const String frequentFoods = '/api/foods/frequent';
  static const String customFoods = '/api/foods/custom';
  static const String foodLabelScan = '/api/foods/scan-label';

  // Nutrition
  static const String nutritionLog = '/api/log/nutrition';
  static const String nutritionAll = '/api/log/nutrition/all';

  // Weight
  static const String weightLog = '/api/log/weight';
  static const String weightHistory = '/api/log/weight/history';

  // Hydration
  static const String hydrationLog = '/api/log/hydration';
  static const String hydrationHistory = '/api/log/hydration/history';
  static const String beveragePresets = '/api/beverages/presets';

  // Health
  static const String symptoms = '/api/health/symptoms';
  static const String medications = '/api/health/medications';
  static const String vitals = '/api/health/vitals';
  static const String sleep = '/api/health/sleep';
  static const String exercise = '/api/health/exercise';
  static const String mood = '/api/health/mood';

  // Eczema
  static const String eczema = '/api/health/eczema';
  static const String eczemaHistory = '/api/health/eczema/history';
  static const String eczemaHeatmap = '/api/health/eczema/heatmap';

  // Analytics
  static const String analyticsNutrition = '/api/analytics/nutrition';
  static const String nutritionBreakdown  = '/api/analytics/nutrition/breakdown';

  // Profile
  static const String profile = '/api/profile';
  static const String profileAvatar = '/api/profile/avatar';
  static const String profileChild = '/api/profile/child';

  // Grocery Intelligence
  static const String groceryReceipts      = '/api/grocery/receipts';
  static const String grocerySpending      = '/api/analytics/grocery/spending';
  static const String groceryNutrition     = '/api/analytics/grocery/nutrition';
  static const String groceryCategoryItems = '/api/analytics/grocery/category-items';
}
