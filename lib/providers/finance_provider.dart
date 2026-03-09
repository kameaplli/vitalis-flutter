import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/finance_models.dart';

// ── Statements list ──────────────────────────────────────────────────────────
final financeStatementsProvider =
    FutureProvider.autoDispose<List<BankStatement>>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.financeStatements);
  final list = res.data['statements'] as List;
  return list
      .map((e) => BankStatement.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Single statement with transactions ───────────────────────────────────────
final financeStatementDetailProvider =
    FutureProvider.autoDispose.family<BankStatement, String>((ref, id) async {
  final res =
      await apiClient.dio.get('${ApiConstants.financeStatements}/$id');
  return BankStatement.fromJson(res.data as Map<String, dynamic>);
});

// ── Spending analytics ───────────────────────────────────────────────────────
// key = period (month|3month|6month|year)
final financeSpendingProvider =
    FutureProvider.autoDispose.family<FinanceSpending, String>(
        (ref, period) async {
  final res = await apiClient.dio.get(
    ApiConstants.financeSpending,
    queryParameters: {'period': period},
  );
  return FinanceSpending.fromJson(res.data as Map<String, dynamic>);
});

// ── Budget ───────────────────────────────────────────────────────────────────
final financeBudgetProvider =
    FutureProvider.autoDispose<FinanceBudget>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.financeBudget);
  return FinanceBudget.fromJson(res.data as Map<String, dynamic>);
});

// ── Trends ───────────────────────────────────────────────────────────────────
final financeTrendsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, months) async {
  final res = await apiClient.dio.get(
    ApiConstants.financeTrends,
    queryParameters: {'months': months},
  );
  return res.data as Map<String, dynamic>;
});
