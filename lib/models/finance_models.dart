class BankStatement {
  final String id;
  final String? bankName;
  final String? accountType;
  final String? accountLast4;
  final DateTime? statementDate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? openingBalance;
  final double? closingBalance;
  final double? totalDebits;
  final double? totalCredits;
  final String currency;
  final String? originalFilename;
  final String status;
  final String? errorMessage;
  final int transactionCount;
  final int expenseCount;
  final String? parseEngine;
  final double? confidenceScore;
  final DateTime createdAt;
  final DateTime? processedAt;
  final List<FinanceTransaction>? transactions;

  const BankStatement({
    required this.id,
    this.bankName,
    this.accountType,
    this.accountLast4,
    this.statementDate,
    this.periodStart,
    this.periodEnd,
    this.openingBalance,
    this.closingBalance,
    this.totalDebits,
    this.totalCredits,
    this.currency = 'USD',
    this.originalFilename,
    required this.status,
    this.errorMessage,
    this.transactionCount = 0,
    this.expenseCount = 0,
    this.parseEngine,
    this.confidenceScore,
    required this.createdAt,
    this.processedAt,
    this.transactions,
  });

  factory BankStatement.fromJson(Map<String, dynamic> j) => BankStatement(
        id: j['id'] as String,
        bankName: j['bank_name'] as String?,
        accountType: j['account_type'] as String?,
        accountLast4: j['account_last4'] as String?,
        statementDate: j['statement_date'] != null
            ? DateTime.tryParse(j['statement_date'] as String)
            : null,
        periodStart: j['period_start'] != null
            ? DateTime.tryParse(j['period_start'] as String)
            : null,
        periodEnd: j['period_end'] != null
            ? DateTime.tryParse(j['period_end'] as String)
            : null,
        openingBalance: (j['opening_balance'] as num?)?.toDouble(),
        closingBalance: (j['closing_balance'] as num?)?.toDouble(),
        totalDebits: (j['total_debits'] as num?)?.toDouble(),
        totalCredits: (j['total_credits'] as num?)?.toDouble(),
        currency: j['currency'] as String? ?? 'USD',
        originalFilename: j['original_filename'] as String?,
        status: j['status'] as String? ?? 'pending',
        errorMessage: j['error_message'] as String?,
        transactionCount: (j['transaction_count'] as num?)?.toInt() ?? 0,
        expenseCount: (j['expense_count'] as num?)?.toInt() ?? 0,
        parseEngine: j['parse_engine'] as String?,
        confidenceScore: (j['confidence_score'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        processedAt: j['processed_at'] != null
            ? DateTime.tryParse(j['processed_at'] as String)
            : null,
        transactions: j['transactions'] != null
            ? (j['transactions'] as List)
                .map((e) =>
                    FinanceTransaction.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
}

class FinanceTransaction {
  final String id;
  final String statementId;
  final DateTime? transactionDate;
  final String? description;
  final String? merchantName;
  final double amount;
  final String transactionType; // debit / credit
  final String category;
  final List<String> categories;
  final String? reference;
  final String? rawText;
  final String? notes;
  final bool isRecurring;
  final bool? isEssential;

  const FinanceTransaction({
    required this.id,
    required this.statementId,
    this.transactionDate,
    this.description,
    this.merchantName,
    required this.amount,
    required this.transactionType,
    required this.category,
    required this.categories,
    this.reference,
    this.rawText,
    this.notes,
    this.isRecurring = false,
    this.isEssential,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> j) =>
      FinanceTransaction(
        id: j['id'] as String,
        statementId: j['statement_id'] as String,
        transactionDate: j['transaction_date'] != null
            ? DateTime.tryParse(j['transaction_date'] as String)
            : null,
        description: j['description'] as String?,
        merchantName: j['merchant_name'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        transactionType: j['transaction_type'] as String? ?? 'debit',
        category: j['category'] as String? ?? 'uncategorized',
        categories: (j['categories'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [j['category'] as String? ?? 'uncategorized'],
        reference: j['reference'] as String?,
        rawText: j['raw_text'] as String?,
        notes: j['notes'] as String?,
        isRecurring: j['is_recurring'] as bool? ?? false,
        isEssential: j['is_essential'] as bool?,
      );
}

class FinanceSpending {
  final String period;
  final double totalSpend;
  final double essentialSpend;
  final double discretionarySpend;
  final List<FinanceCategorySpend> byCategory;

  const FinanceSpending({
    required this.period,
    required this.totalSpend,
    required this.essentialSpend,
    required this.discretionarySpend,
    required this.byCategory,
  });

  factory FinanceSpending.fromJson(Map<String, dynamic> j) => FinanceSpending(
        period: j['period'] as String? ?? 'month',
        totalSpend: (j['total_spend'] as num?)?.toDouble() ?? 0,
        essentialSpend: (j['essential_spend'] as num?)?.toDouble() ?? 0,
        discretionarySpend:
            (j['discretionary_spend'] as num?)?.toDouble() ?? 0,
        byCategory: (j['by_category'] as List?)
                ?.map((e) =>
                    FinanceCategorySpend.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class FinanceCategorySpend {
  final String category;
  final double amount;
  final int count;
  final double percentage;

  const FinanceCategorySpend({
    required this.category,
    required this.amount,
    required this.count,
    required this.percentage,
  });

  factory FinanceCategorySpend.fromJson(Map<String, dynamic> j) =>
      FinanceCategorySpend(
        category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
        count: (j['count'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
      );
}

class FinanceBudget {
  final List<BudgetItem> budget;
  final double totalMonthlyBudget;
  final double essentialMonthly;
  final double discretionaryMonthly;
  final double averageMonthlyIncome;
  final double incomeNeeded;
  final double surplusDeficit;
  final String recommendation;

  const FinanceBudget({
    required this.budget,
    required this.totalMonthlyBudget,
    required this.essentialMonthly,
    required this.discretionaryMonthly,
    required this.averageMonthlyIncome,
    required this.incomeNeeded,
    required this.surplusDeficit,
    required this.recommendation,
  });

  factory FinanceBudget.fromJson(Map<String, dynamic> j) => FinanceBudget(
        budget: (j['budget'] as List?)
                ?.map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        totalMonthlyBudget:
            (j['total_monthly_budget'] as num?)?.toDouble() ?? 0,
        essentialMonthly: (j['essential_monthly'] as num?)?.toDouble() ?? 0,
        discretionaryMonthly:
            (j['discretionary_monthly'] as num?)?.toDouble() ?? 0,
        averageMonthlyIncome:
            (j['average_monthly_income'] as num?)?.toDouble() ?? 0,
        incomeNeeded: (j['income_needed'] as num?)?.toDouble() ?? 0,
        surplusDeficit: (j['surplus_deficit'] as num?)?.toDouble() ?? 0,
        recommendation: j['recommendation'] as String? ?? 'tight',
      );
}

class BudgetItem {
  final String category;
  final double monthlyAverage;
  final double quarterlyTotal;
  final bool isEssential;

  const BudgetItem({
    required this.category,
    required this.monthlyAverage,
    required this.quarterlyTotal,
    required this.isEssential,
  });

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        category: j['category'] as String,
        monthlyAverage: (j['monthly_average'] as num).toDouble(),
        quarterlyTotal: (j['quarterly_total'] as num).toDouble(),
        isEssential: j['is_essential'] as bool? ?? false,
      );
}
