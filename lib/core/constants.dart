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
  static const String deleteAccount = '/api/auth/account';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String registerDevice = '/api/auth/register-device';
  static const String unregisterDevice = '/api/auth/unregister-device';

  // Dashboard
  static const String dashboard = '/api/dashboard';
  static const String dashboardFamily = '/api/dashboard/family';
  static const String dashboardPersonalBests = '/api/dashboard/personal-bests';
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

  // Custom Meal / Recipe
  static const String customMeal = '/api/foods/custom-meal';
  static String foodRecipeIngredients(String id) => '/api/foods/$id/ingredients';

  // Nutrients / Micronutrients
  static const String nutrientsDri = '/api/nutrients/dri';
  static const String nutrientsDaily = '/api/nutrients/daily';
  static const String nutrientsPeriod = '/api/nutrients/period';
  static const String nutrientsCatalog = '/api/nutrients/catalog';
  // Food nutrient profile: '/api/foods/{foodId}/nutrients'
  static String foodNutrients(String foodId) => '/api/foods/$foodId/nutrients';
  // Food detail (info card): '/api/foods/{foodId}/detail'
  static String foodDetail(String foodId) => '/api/foods/$foodId/detail';

  // Nutrition
  static const String nutritionLog = '/api/log/nutrition';
  static const String nutritionAll = '/api/log/nutrition/all';
  static const String nutritionVoice = '/api/log/nutrition/voice';
  static const String nutritionVoiceAudio = '/api/log/nutrition/voice-audio';
  static const String nutritionVoiceConfirm = '/api/log/nutrition/voice/confirm';
  static const String quickCreate = '/api/log/nutrition/quick-create';

  // Weight
  static const String weightLog = '/api/log/weight';
  static const String weightHistory = '/api/log/weight/history';

  // Hydration
  static const String hydrationLog = '/api/log/hydration';
  static const String hydrationHistory = '/api/log/hydration/history';
  static const String hydrationGoal = '/api/hydration/goal';
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

  // Skin Photos (Phase 3) + Skin Intelligence
  static const String skinPhotoUpload   = '/api/health/eczema/photo';
  static const String skinPhotos        = '/api/health/eczema/photos';
  static const String skinPhotoTimeline = '/api/health/eczema/photo-timeline';
  static const String skinAnalyze       = '/api/health/eczema/skin/analyze';
  static const String skinAnalyzeUpload = '/api/health/eczema/skin/analyze-upload';
  static const String skinAnalyses      = '/api/health/eczema/skin/analyses';
  static const String skinTrend         = '/api/health/eczema/skin/trend';

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
  static const String insightsHealthReport = '/api/insights/health-report';

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

  // Health Reports
  static const String reportPreferences = '/api/reports/preferences';
  static const String reportGenerate    = '/api/reports/generate';
  static const String reportSendNow    = '/api/reports/send-now';

  // Social
  static const String socialProfile = '/api/social/profile';
  static String socialProfileUser(String id) => '/api/social/profile/$id';
  static const String socialPrivacy = '/api/social/privacy';
  static const String socialConnections = '/api/social/connections';
  static const String socialConnectionsPending = '/api/social/connections/pending';
  static String socialConnectionAccept(String id) => '/api/social/connections/$id/accept';
  static String socialConnectionReject(String id) => '/api/social/connections/$id/reject';
  static String socialConnectionRemove(String id) => '/api/social/connections/$id';
  static const String socialBlock = '/api/social/block';
  static String socialUnblock(String id) => '/api/social/block/$id';
  static const String socialBlockedUsers = '/api/social/block/list';
  static const String socialReport = '/api/social/report';
  static const String socialBadges = '/api/social/badges';
  static String socialUserBadges(String userId) => '/api/social/badges/$userId';
  static const String socialSearch = '/api/social/search';
  static const String socialFeed = '/api/social/feed';
  static const String socialFeedRecipes = '/api/social/feed/recipes';
  static String socialFeedRead(String id) => '/api/social/feed/$id/read';
  static String socialFeedDelete(String id) => '/api/social/feed/$id';
  static String socialFeedEdit(String id) => '/api/social/feed/$id';
  static const String socialFeedReadAll = '/api/social/feed/read-all';
  static const String socialFeedUnreadCount = '/api/social/feed/unread-count';
  static const String socialShare = '/api/social/share';
  static const String socialReactions = '/api/social/reactions';
  static String socialReactionRemove(String id) => '/api/social/reactions/$id';
  static const String socialComments = '/api/social/comments';
  static String socialCommentsForEvent(String id) => '/api/social/comments/$id';
  static String socialCommentDelete(String id) => '/api/social/comments/$id';
  static const String challenges = '/api/challenges';
  static String challengeDetail(String id) => '/api/challenges/$id';
  static String challengeJoin(String id) => '/api/challenges/$id/join';
  static String challengeLeave(String id) => '/api/challenges/$id/leave';
  static String challengeLeaderboard(String id) => '/api/challenges/$id/leaderboard';
  static const String challengesMine = '/api/challenges/mine';
  static const String socialNotifications = '/api/social/notifications';
  static const String socialNotificationsUnread = '/api/social/notifications/unread-count';
  static String socialNotificationRead(String id) => '/api/social/notifications/$id/read';
  static const String socialNotificationsReadAll = '/api/social/notifications/read-all';
  static const String socialStreakBuddy = '/api/social/streak-buddy';
  static const String socialStreakBuddyNudge = '/api/social/streak-buddy/nudge';
  static const String socialCommunityPulse = '/api/social/pulse';
  static const String socialShareCard = '/api/social/share-card';

  // Polls
  static const String polls = '/api/social/polls';
  static String pollDetail(String id) => '/api/social/polls/$id';
  static String pollVote(String id) => '/api/social/polls/$id/vote';
  static String pollInvite(String id) => '/api/social/polls/$id/invite';
  static const String pollsMine = '/api/social/polls/mine';
  static String pollComments(String id) => '/api/social/polls/$id/comments';

  // Group Chats
  static const String groupChats = '/api/social/groups';
  static String groupChatDetail(String id) => '/api/social/groups/$id';
  static String groupChatMessages(String id) => '/api/social/groups/$id/messages';
  static String groupChatMembers(String id) => '/api/social/groups/$id/members';
  static String groupChatJoin(String id) => '/api/social/groups/$id/join';
  static String groupChatLeave(String id) => '/api/social/groups/$id/leave';
  static String groupChatInvite(String id) => '/api/social/groups/$id/invite';

  // Direct Messages
  static const String dmConversations = '/api/social/dm';
  static String dmMessages(String id) => '/api/social/dm/$id/messages';

  // Blood Test Intelligence (Labs)
  static const String labUpload     = '/api/labs/upload';
  static String labParseStatus(String jobId) => '/api/labs/parse-status/$jobId';
  static const String labConfirm    = '/api/labs/confirm';
  static const String labManual     = '/api/labs/manual';
  static const String labReports    = '/api/labs/reports';
  static String labReport(String id) => '/api/labs/reports/$id';
  static String biomarkerHistory(String code) => '/api/labs/biomarker/$code/history';
  static const String labDashboard  = '/api/labs/dashboard';
  static const String labBiomarkers = '/api/labs/biomarkers';
  static const String labReprocess  = '/api/labs/reprocess';
  static const String labInsights   = '/api/labs/insights';
  static String labInsightDismiss(String id) => '/api/labs/insights/$id/dismiss';
  static const String labScore      = '/api/labs/score';
  static String labCompare(String id, String otherId) => '/api/labs/reports/$id/compare/$otherId';
  static const String labRecommendations = '/api/labs/recommendations';

  // Health Intelligence
  static const String healthScoreDaily       = '/api/health-intelligence/score/daily';
  static const String healthScoreWeekly      = '/api/health-intelligence/score/weekly';
  static const String healthScoreHistory     = '/api/health-intelligence/score/history';
  static const String healthAlerts           = '/api/health-intelligence/alerts';
  static String healthAlertDismiss(String id) => '/api/health-intelligence/alerts/$id/dismiss';
  static String healthAlertRead(String id)    => '/api/health-intelligence/alerts/$id/read';
  static const String healthTriggerCheck     = '/api/health-intelligence/triggers/check';
  static const String healthRiskProfile      = '/api/health-intelligence/risk-profile';
  static const String healthClinicalReport   = '/api/health-intelligence/clinical-report';
  static const String healthClinicalReportPdf = '/api/health-intelligence/clinical-report/pdf';

  // Wearable Sync (Phase 1)
  static const String syncIngest       = '/api/sync/ingest';
  static const String syncStatus       = '/api/sync/status';
  static const String syncAccounts     = '/api/sync/accounts';
  static const String syncDailySummary = '/api/sync/daily-summary';
  static const String syncDevices      = '/api/sync/devices';
  static const String syncDataTypes    = '/api/sync/data-types';

  // Data Import (Phase 2)
  static const String importUpload     = '/api/sync/import/upload';
  static const String importBatch      = '/api/sync/import/batch';
  static const String importJobs       = '/api/sync/imports';
  static String importJob(String id)   => '/api/sync/import/$id';
  static String importComplete(String id) => '/api/sync/import/$id/complete';
  static String importCancel(String id) => '/api/sync/import/$id/cancel';
  static String importRollback(String id) => '/api/sync/import/$id/rollback';

  // Health Timeline (Phase 4)
  static const String syncTimeline = '/api/sync/timeline';

  // Cloud Sync OAuth2 (Phase 3)
  static const String syncConnect    = '/api/sync/accounts/connect';
  static const String syncCallback   = '/api/sync/accounts/callback';
  static String syncDisconnect(String id) => '/api/sync/accounts/$id';
  static String syncResync(String id) => '/api/sync/accounts/$id/resync';

  // Digital Twin / Goals / Weekly Summary
  static const String twinDaily = '/api/health-intelligence/twin/daily';
  static const String twinTrend = '/api/health-intelligence/twin/trend';
  static const String healthGoals = '/api/health-intelligence/goals';
  static const String healthGoalInsights = '/api/health-intelligence/goals/insights';
  static const String weeklySummary = '/api/health-intelligence/weekly-summary';
  static const String weeklySummaryHistory = '/api/health-intelligence/weekly-summary/history';

  // Health Twin Engine — Phase 2-4
  static const String crossDomainCorrelations = '/api/health-intelligence/correlations';
  static const String correlationDetail = '/api/health-intelligence/correlations/detail';
  static const String healthLevel = '/api/health-intelligence/level';
  static const String healthStreaks = '/api/health-intelligence/streaks';
  static const String healthAchievements = '/api/health-intelligence/achievements';
  static const String engagementSummary = '/api/health-intelligence/engagement';
  static const String healthPredictions = '/api/health-intelligence/predictions';
  static const String whatIfScenarios = '/api/health-intelligence/what-if';
  static const String labFeedback = '/api/health-intelligence/lab-feedback';
  static String biomarkerTimeline(String code) => '/api/health-intelligence/lab-feedback/biomarker/$code';
  static const String familyOverview = '/api/health-intelligence/family-overview';
  static const String familyComparison = '/api/health-intelligence/family-comparison';

  // Debug / Diagnostics (no auth required)
  static const String debugGoogleApi      = '/api/debug/google-api';
  static const String debugVoiceAiStatus  = '/api/debug/voice-ai-status';
}
