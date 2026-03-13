// Daily intake lookup by age / gender — shared helper used across nutrition widgets.

class DailyIntake {
  final double calories, protein, carbs, fat;
  const DailyIntake(this.calories, this.protein, this.carbs, this.fat);
}

DailyIntake dailyIntake(int? age, String? gender) {
  final male = (gender ?? '').toLowerCase().startsWith('m');
  final a = age ?? 30;
  if (a < 4)  return const DailyIntake(1200, 13, 150, 40);
  if (a < 9)  return const DailyIntake(1400, 19, 175, 45);
  if (a < 14) return DailyIntake(male ? 1800 : 1600, 34, male ? 225 : 200, 50);
  if (a < 19) return DailyIntake(male ? 2600 : 2000, male ? 52 : 46, male ? 325 : 250, male ? 75 : 65);
  if (a < 51) return DailyIntake(male ? 2500 : 2000, male ? 56 : 46, male ? 300 : 250, male ? 70 : 65);
  return DailyIntake(male ? 2300 : 1800, male ? 56 : 46, male ? 275 : 225, male ? 65 : 60);
}
