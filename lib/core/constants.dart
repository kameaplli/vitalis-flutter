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
  static const String dashboardFamily = '/api/dashboard/family';
  static const String welcome = '/api/welcome';

  // Foods
  static const String foodDatabase = '/api/foods/database';
  static const String foodSearch = '/api/foods/search';
  static const String frequentFoods = '/api/foods/frequent';
  static const String customFoods = '/api/foods/custom';
  static const String foodLabelScan = '/api/foods/scan-label';
  static const String foodAllergenCheck = '/api/foods/allergen-check';
  static const String foodClassifyBatch = '/api/foods/classify-batch';
  static const String foodIngredients = '/api/foods/ingredients';

  // Nutrients / Micronutrients
  static const String nutrientsDri = '/api/nutrients/dri';
  static const String nutrientsDaily = '/api/nutrients/daily';
  static const String nutrientsPeriod = '/api/nutrients/period';
  static const String nutrientsCatalog = '/api/nutrients/catalog';
  // Food nutrient profile: '/api/foods/{foodId}/nutrients'
  static String foodNutrients(String foodId) => '/api/foods/$foodId/nutrients';

  // Nutrition
  static const String nutritionLog = '/api/log/nutrition';
  static const String nutritionAll = '/api/log/nutrition/all';
  static const String nutritionVoice = '/api/log/nutrition/voice';
  static const String nutritionVoiceConfirm = '/api/log/nutrition/voice/confirm';

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
  static const String supplements = '/api/health/supplements';
  static const String vitals = '/api/health/vitals';
  static const String sleep = '/api/health/sleep';
  static const String exercise = '/api/health/exercise';
  static const String mood = '/api/health/mood';

  // Eczema
  static const String eczema = '/api/health/eczema';
  static const String eczemaHistory = '/api/health/eczema/history';
  static const String eczemaHeatmap = '/api/health/eczema/heatmap';
  static const String eczemaMock = '/api/health/eczema/mock';
  static const String eczemaFoodCorrelation = '/api/health/eczema/food-correlation';

  // Analytics
  static const String analyticsNutrition = '/api/analytics/nutrition';
  static const String nutritionBreakdown  = '/api/analytics/nutrition/breakdown';

  // Profile
  static const String profile = '/api/profile';
  static const String profileAvatar = '/api/profile/avatar';
  static const String profileChild = '/api/profile/child';

  // Grocery Intelligence
  static const String groceryReceipts        = '/api/grocery/receipts';
  static const String groceryItems           = '/api/grocery/items';
  static const String groceryLearnCategories = '/api/grocery/learn-categories';
  static const String groceryCategoryMap     = '/api/grocery/category-map';
  static const String grocerySpending        = '/api/analytics/grocery/spending';
  static const String groceryNutrition       = '/api/analytics/grocery/nutrition';
  static const String groceryCategoryItems   = '/api/analytics/grocery/category-items';

  // Environment Intelligence (Phase 1)
  static const String environmentCurrent     = '/api/environment/current';
  static const String environmentHistory     = '/api/environment/history';
  static const String environmentCorrelation = '/api/environment/correlation';
  static const String environmentFlareRisk   = '/api/environment/flare-risk';

  // Smart Food Analysis (Phase 2)
  static const String eczemaSmartCorrelation = '/api/health/eczema/smart-correlation';

  // Skin Photos (Phase 3)
  static const String skinPhotoUpload   = '/api/health/eczema/photo';
  static const String skinPhotos        = '/api/health/eczema/photos';
  static const String skinPhotoTimeline = '/api/health/eczema/photo-timeline';

  // Product Scanner (Phase 4)
  static const String productScan       = '/api/products/scan';
  static const String products          = '/api/products';
  static const String productCorrelation = '/api/products/correlation';

  // AI Insights (Phase 5)
  static const String insightsWeekly    = '/api/insights/weekly';
  static const String insightsFlareRisk = '/api/insights/flare-risk';
  static const String insightsInvestigate = '/api/insights/investigate';
  static const String insightsNutrition = '/api/insights/nutrition';
  static const String insightsGrocery   = '/api/insights/grocery';
  static const String insightsHistory   = '/api/insights/history';

  // Supplement Lookup, Intake & Import
  static const String supplementLookup     = '/api/foods/supplements/lookup';
  static const String supplementSave       = '/api/foods/supplements/save';
  static const String supplementBulkImport = '/api/foods/supplements/bulk-import';
  static const String supplementImportBrand = '/api/foods/supplements/import-brand';
  static String supplementLogIntake(String id) => '/api/health/supplements/$id/log-intake';

  // USDA FDC Import
  static const String usdaSearch       = '/api/foods/usda/search';
  static String usdaImport(int fdcId)  => '/api/foods/usda/import/$fdcId';
  static const String usdaBulkImport   = '/api/foods/usda/bulk-import';

  // ML Features — Nutrient Intelligence
  static const String nutrientGaps            = '/api/nutrients/gaps';
  static const String nutrientRecommendations = '/api/nutrients/recommendations';
  static String foodSimilar(String id)        => '/api/foods/$id/similar';
  static String foodVector(String id)         => '/api/foods/$id/vector';

  // OpenFoodFacts Import
  static const String offSearch               = '/api/foods/off/search';
  static String offImport(String barcode)     => '/api/foods/off/import/$barcode';
  static const String offBulkImport           = '/api/foods/off/bulk-import';

  // Favorites
  static const String foodFavorites     = '/api/foods/favorites';
  static String foodFavorite(String id) => '/api/foods/favorites/$id';

  // Copy Yesterday / Recent-Frequent
  static const String yesterdayMeals    = '/api/foods/yesterday-meals';
  static const String recentFrequent    = '/api/foods/recent-frequent';

  // Photo Food Recognition
  static const String foodPhotoRecognize = '/api/foods/photo-recognize';

  // Achievements (Phase 6)
  static const String achievements = '/api/achievements';

  // Finance Intelligence
  static const String financeStatements   = '/api/finance/statements';
  static const String financeTransactions = '/api/finance/transactions';
  static const String financeSpending     = '/api/analytics/finance/spending';
  static const String financeBudget       = '/api/analytics/finance/budget';
  static const String financeTrends       = '/api/analytics/finance/trends';
  static const String financeReprocessAll = '/api/finance/statements/reprocess-all';
  static const String financeSpendingTxns = '/api/analytics/finance/spending/transactions';
  static const String financeReport       = '/api/analytics/finance/report';

  // Debug / Diagnostics (no auth required)
  static const String debugGoogleApi      = '/api/debug/google-api';
  static const String debugVoiceAiStatus  = '/api/debug/voice-ai-status';
}
