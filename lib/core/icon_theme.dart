import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Icon theme system for Qorhealth.
/// Each theme defines a complete set of icons used across the app.
/// Themes can be swapped at runtime to personalize the look.

/// A unified icon reference that can be either a Material IconData or HugeIcon SVG data.
class VIcon {
  final IconData? materialIcon;
  final List<List<dynamic>>? hugeIcon;

  const VIcon.material(this.materialIcon) : hugeIcon = null;
  const VIcon.huge(this.hugeIcon) : materialIcon = null;

  /// Build the appropriate widget.
  Widget build({double size = 24, Color? color}) {
    if (hugeIcon != null) {
      return HugeIcon(icon: hugeIcon!, size: size, color: color);
    }
    return Icon(materialIcon, size: size, color: color);
  }

  /// Get IconData for places that strictly require it (e.g. BottomNavigationBar).
  /// Falls back to a placeholder for HugeIcon-based themes.
  IconData get iconData => materialIcon ?? Icons.circle;
}

/// All icon slots used across the app.
class QorhealthIcons {
  // Navigation
  final VIcon home;
  final VIcon nutrition;
  final VIcon hydration;
  final VIcon health;
  final VIcon analytics;
  final VIcon profile;

  // Actions
  final VIcon add;
  final VIcon edit;
  final VIcon delete;
  final VIcon search;
  final VIcon filter;
  final VIcon settings;
  final VIcon notifications;
  final VIcon save;
  final VIcon close;
  final VIcon back;
  final VIcon refresh;
  final VIcon share;

  // Health categories
  final VIcon symptoms;
  final VIcon medications;
  final VIcon supplements;
  final VIcon mood;
  final VIcon sleep;
  final VIcon exercise;
  final VIcon weight;
  final VIcon eczema;
  final VIcon skinPhotos;
  final VIcon products;
  final VIcon insights;
  final VIcon vitals;

  // Specific
  final VIcon waterDrop;
  final VIcon food;
  final VIcon meal;
  final VIcon snack;
  final VIcon calendar;
  final VIcon chart;
  final VIcon pdf;
  final VIcon email;
  final VIcon camera;
  final VIcon scan;
  final VIcon timer;
  final VIcon star;
  final VIcon heart;
  final VIcon fire;
  final VIcon trophy;
  final VIcon family;
  final VIcon person;
  final VIcon child;
  final VIcon grocery;
  final VIcon finance;
  final VIcon sun;
  final VIcon moon;
  final VIcon thermometer;
  final VIcon warning;

  const QorhealthIcons({
    required this.home,
    required this.nutrition,
    required this.hydration,
    required this.health,
    required this.analytics,
    required this.profile,
    required this.add,
    required this.edit,
    required this.delete,
    required this.search,
    required this.filter,
    required this.settings,
    required this.notifications,
    required this.save,
    required this.close,
    required this.back,
    required this.refresh,
    required this.share,
    required this.symptoms,
    required this.medications,
    required this.supplements,
    required this.mood,
    required this.sleep,
    required this.exercise,
    required this.weight,
    required this.eczema,
    required this.skinPhotos,
    required this.products,
    required this.insights,
    required this.vitals,
    required this.waterDrop,
    required this.food,
    required this.meal,
    required this.snack,
    required this.calendar,
    required this.chart,
    required this.pdf,
    required this.email,
    required this.camera,
    required this.scan,
    required this.timer,
    required this.star,
    required this.heart,
    required this.fire,
    required this.trophy,
    required this.family,
    required this.person,
    required this.child,
    required this.grocery,
    required this.finance,
    required this.sun,
    required this.moon,
    required this.thermometer,
    required this.warning,
  });
}

/// Default Material Design icons — the classic look.
const materialIcons = QorhealthIcons(
  home: VIcon.material(Icons.dashboard_rounded),
  nutrition: VIcon.material(Icons.restaurant_rounded),
  hydration: VIcon.material(Icons.water_drop_rounded),
  health: VIcon.material(Icons.favorite_rounded),
  analytics: VIcon.material(Icons.insights_rounded),
  profile: VIcon.material(Icons.person_rounded),
  add: VIcon.material(Icons.add_rounded),
  edit: VIcon.material(Icons.edit_rounded),
  delete: VIcon.material(Icons.delete_rounded),
  search: VIcon.material(Icons.search_rounded),
  filter: VIcon.material(Icons.filter_list_rounded),
  settings: VIcon.material(Icons.settings_rounded),
  notifications: VIcon.material(Icons.notifications_rounded),
  save: VIcon.material(Icons.check_rounded),
  close: VIcon.material(Icons.close_rounded),
  back: VIcon.material(Icons.arrow_back_rounded),
  refresh: VIcon.material(Icons.refresh_rounded),
  share: VIcon.material(Icons.share_rounded),
  symptoms: VIcon.material(Icons.thermostat_rounded),
  medications: VIcon.material(Icons.medical_services_rounded),
  supplements: VIcon.material(Icons.science_rounded),
  mood: VIcon.material(Icons.self_improvement_rounded),
  sleep: VIcon.material(Icons.bedtime_rounded),
  exercise: VIcon.material(Icons.directions_run_rounded),
  weight: VIcon.material(Icons.fitness_center_rounded),
  eczema: VIcon.material(Icons.dry_rounded),
  skinPhotos: VIcon.material(Icons.photo_camera_rounded),
  products: VIcon.material(Icons.local_pharmacy_rounded),
  insights: VIcon.material(Icons.auto_awesome_rounded),
  vitals: VIcon.material(Icons.monitor_heart_rounded),
  waterDrop: VIcon.material(Icons.water_drop_rounded),
  food: VIcon.material(Icons.lunch_dining_rounded),
  meal: VIcon.material(Icons.restaurant_rounded),
  snack: VIcon.material(Icons.cookie_rounded),
  calendar: VIcon.material(Icons.calendar_today_rounded),
  chart: VIcon.material(Icons.bar_chart_rounded),
  pdf: VIcon.material(Icons.picture_as_pdf_rounded),
  email: VIcon.material(Icons.email_rounded),
  camera: VIcon.material(Icons.camera_alt_rounded),
  scan: VIcon.material(Icons.qr_code_scanner_rounded),
  timer: VIcon.material(Icons.timer_rounded),
  star: VIcon.material(Icons.star_rounded),
  heart: VIcon.material(Icons.favorite_rounded),
  fire: VIcon.material(Icons.local_fire_department_rounded),
  trophy: VIcon.material(Icons.emoji_events_rounded),
  family: VIcon.material(Icons.family_restroom_rounded),
  person: VIcon.material(Icons.person_rounded),
  child: VIcon.material(Icons.child_care_rounded),
  grocery: VIcon.material(Icons.shopping_cart_rounded),
  finance: VIcon.material(Icons.account_balance_wallet_rounded),
  sun: VIcon.material(Icons.wb_sunny_rounded),
  moon: VIcon.material(Icons.nightlight_rounded),
  thermometer: VIcon.material(Icons.thermostat_rounded),
  warning: VIcon.material(Icons.warning_amber_rounded),
);

/// HugeIcons theme — modern, clean stroke icons.
final hugeIconsTheme = QorhealthIcons(
  home: VIcon.huge(HugeIcons.strokeRoundedHome01),
  nutrition: VIcon.huge(HugeIcons.strokeRoundedRestaurant01),
  hydration: VIcon.huge(HugeIcons.strokeRoundedDroplet),
  health: VIcon.huge(HugeIcons.strokeRoundedFavourite),
  analytics: VIcon.huge(HugeIcons.strokeRoundedAnalytics01),
  profile: VIcon.huge(HugeIcons.strokeRoundedUser),
  add: VIcon.huge(HugeIcons.strokeRoundedAdd01),
  edit: VIcon.huge(HugeIcons.strokeRoundedEdit01),
  delete: VIcon.huge(HugeIcons.strokeRoundedDelete01),
  search: VIcon.huge(HugeIcons.strokeRoundedSearch01),
  filter: VIcon.huge(HugeIcons.strokeRoundedFilterHorizontal),
  settings: VIcon.huge(HugeIcons.strokeRoundedSettings01),
  notifications: VIcon.huge(HugeIcons.strokeRoundedNotification01),
  save: VIcon.huge(HugeIcons.strokeRoundedCheckmarkCircle01),
  close: VIcon.huge(HugeIcons.strokeRoundedCancel01),
  back: VIcon.huge(HugeIcons.strokeRoundedArrowLeft01),
  refresh: VIcon.huge(HugeIcons.strokeRoundedRefresh),
  share: VIcon.huge(HugeIcons.strokeRoundedShare01),
  symptoms: VIcon.huge(HugeIcons.strokeRoundedThermometer),
  medications: VIcon.huge(HugeIcons.strokeRoundedMedicine01),
  supplements: VIcon.huge(HugeIcons.strokeRoundedTestTube01),
  mood: VIcon.huge(HugeIcons.strokeRoundedYoga01),
  sleep: VIcon.huge(HugeIcons.strokeRoundedMoon02),
  exercise: VIcon.huge(HugeIcons.strokeRoundedRunningShoes),
  weight: VIcon.huge(HugeIcons.strokeRoundedDumbbell01),
  eczema: VIcon.huge(HugeIcons.strokeRoundedBandage),
  skinPhotos: VIcon.huge(HugeIcons.strokeRoundedCamera01),
  products: VIcon.huge(HugeIcons.strokeRoundedMedicine02),
  insights: VIcon.huge(HugeIcons.strokeRoundedIdea01),
  vitals: VIcon.huge(HugeIcons.strokeRoundedPulse01),
  waterDrop: VIcon.huge(HugeIcons.strokeRoundedDroplet),
  food: VIcon.huge(HugeIcons.strokeRoundedRestaurant01),
  meal: VIcon.huge(HugeIcons.strokeRoundedRestaurant01),
  snack: VIcon.huge(HugeIcons.strokeRoundedCookie),
  calendar: VIcon.huge(HugeIcons.strokeRoundedCalendar01),
  chart: VIcon.huge(HugeIcons.strokeRoundedChartColumn),
  pdf: VIcon.huge(HugeIcons.strokeRoundedPdf01),
  email: VIcon.huge(HugeIcons.strokeRoundedMail01),
  camera: VIcon.huge(HugeIcons.strokeRoundedCamera01),
  scan: VIcon.huge(HugeIcons.strokeRoundedQrCode),
  timer: VIcon.huge(HugeIcons.strokeRoundedTimer01),
  star: VIcon.huge(HugeIcons.strokeRoundedStar),
  heart: VIcon.huge(HugeIcons.strokeRoundedFavourite),
  fire: VIcon.huge(HugeIcons.strokeRoundedFire),
  trophy: VIcon.huge(HugeIcons.strokeRoundedAward01),
  family: VIcon.huge(HugeIcons.strokeRoundedUserGroup),
  person: VIcon.huge(HugeIcons.strokeRoundedUser),
  child: VIcon.huge(HugeIcons.strokeRoundedBabyBed01),
  grocery: VIcon.huge(HugeIcons.strokeRoundedShoppingCart01),
  finance: VIcon.huge(HugeIcons.strokeRoundedWallet01),
  sun: VIcon.huge(HugeIcons.strokeRoundedSun01),
  moon: VIcon.huge(HugeIcons.strokeRoundedMoon02),
  thermometer: VIcon.huge(HugeIcons.strokeRoundedThermometer),
  warning: VIcon.huge(HugeIcons.strokeRoundedAlert01),
);

/// Registry of all available icon themes.
enum IconThemeChoice {
  material('Material', 'Classic Material Design icons'),
  hugeicons('HugeIcons', 'Modern line icons by HugeIcons');

  const IconThemeChoice(this.label, this.description);
  final String label;
  final String description;

  QorhealthIcons get icons {
    switch (this) {
      case IconThemeChoice.material:
        return materialIcons;
      case IconThemeChoice.hugeicons:
        return hugeIconsTheme;
    }
  }
}
