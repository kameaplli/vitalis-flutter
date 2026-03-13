import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../widgets/friendly_error.dart';

// ── Category colours ─────────────────────────────────────────────────────────

const _categoryColors = <String, Color>{
  // Daily living
  'groceries': Colors.green,
  'dining': Colors.orange,
  'fast_food': Colors.deepOrange,
  'coffee': Colors.brown,
  // Transport
  'transport': Colors.blue,
  'fuel': Colors.blueGrey,
  'parking': Colors.grey,
  'tolls': Color(0xFF607D8B),
  'rideshare': Color(0xFF1565C0),
  // Housing
  'rent': Colors.indigo,
  'mortgage': Colors.indigo,
  'utilities': Colors.teal,
  'home_improvement': Colors.brown,
  'repairs': Color(0xFF8D6E63),
  'maintenance': Color(0xFF795548),
  // Insurance & finance
  'insurance': Colors.purple,
  'interest': Colors.red,
  'fees': Colors.red,
  'bank_charges': Colors.red,
  'tax': Color(0xFFD32F2F),
  // Health
  'medical': Colors.pink,
  'pharmacy': Colors.pink,
  'fitness': Colors.lightGreen,
  'personal_care': Colors.purple,
  // Shopping
  'apparel': Colors.deepPurple,
  'electronics': Colors.cyan,
  'furniture': Colors.amber,
  'toys': Colors.lime,
  'online_shopping': Colors.deepOrange,
  // Family & education
  'education': Colors.blue,
  'school_fees': Colors.blue,
  'childcare': Colors.pink,
  'baby': Color(0xFFEC407A),
  // Lifestyle
  'entertainment': Colors.orange,
  'streaming': Colors.purple,
  'subscriptions': Colors.purple,
  'travel': Colors.cyan,
  'hotels': Colors.cyan,
  'flights': Colors.cyan,
  'gifts': Color(0xFFE91E63),
  'donations': Colors.teal,
  'charity': Color(0xFF00897B),
  'alcohol': Colors.deepPurple,
  'tobacco': Color(0xFF6D4C41),
  // Income
  'salary': Colors.green,
  'income': Colors.green,
  'freelance': Color(0xFF43A047),
  'refund': Colors.green,
  'cashback': Color(0xFF66BB6A),
  'rewards': Color(0xFF2E7D32),
  // Financial
  'transfer': Colors.grey,
  'atm': Colors.grey,
  'cash': Color(0xFF757575),
  'investment': Colors.indigo,
  'savings': Colors.green,
  'loan_repayment': Colors.red,
  'credit_card_payment': Color(0xFF7E57C2),
  'hand_loan': Color(0xFFFF7043),
  // Government
  'council_rates': Color(0xFF546E7A),
  // Sports & recreation
  'cricket': Color(0xFF66BB6A),
  'karate': Color(0xFFD32F2F),
  'swimming': Color(0xFF039BE5),
  'calisthenics': Color(0xFF8D6E63),
  'sports': Color(0xFF43A047),
  // Tutoring
  'tutoring': Color(0xFF5E35B1),
  // Professional
  'professional_services': Color(0xFF5C6BC0),
  'pet': Colors.brown,
  'lottery': Color(0xFFFFB300),
  // Catch-all
  'uncategorized': Colors.grey,
  'other': Colors.grey,
};

Color _catColor(String cat) =>
    _categoryColors[cat] ?? const Color(0xFF9E9E9E);

// ── Category icons ───────────────────────────────────────────────────────────

IconData _catIcon(String cat) => switch (cat) {
      'groceries' => Icons.shopping_cart,
      'dining' => Icons.restaurant,
      'fast_food' => Icons.fastfood,
      'coffee' => Icons.coffee,
      'transport' => Icons.directions_bus,
      'fuel' => Icons.local_gas_station,
      'parking' => Icons.local_parking,
      'tolls' => Icons.toll,
      'rideshare' => Icons.local_taxi,
      'rent' => Icons.home,
      'mortgage' => Icons.home,
      'utilities' => Icons.bolt,
      'home_improvement' => Icons.hardware,
      'repairs' => Icons.build,
      'maintenance' => Icons.handyman,
      'insurance' => Icons.shield,
      'interest' => Icons.trending_up,
      'fees' => Icons.receipt,
      'bank_charges' => Icons.receipt,
      'tax' => Icons.account_balance,
      'medical' => Icons.local_hospital,
      'pharmacy' => Icons.medication,
      'fitness' => Icons.fitness_center,
      'personal_care' => Icons.face,
      'apparel' => Icons.checkroom,
      'electronics' => Icons.devices,
      'furniture' => Icons.chair,
      'toys' => Icons.toys,
      'online_shopping' => Icons.shopping_bag,
      'education' => Icons.school,
      'school_fees' => Icons.school,
      'childcare' => Icons.child_care,
      'baby' => Icons.child_friendly,
      'entertainment' => Icons.movie,
      'streaming' => Icons.live_tv,
      'subscriptions' => Icons.subscriptions,
      'travel' => Icons.flight,
      'hotels' => Icons.hotel,
      'flights' => Icons.flight,
      'gifts' => Icons.card_giftcard,
      'donations' => Icons.volunteer_activism,
      'charity' => Icons.favorite,
      'alcohol' => Icons.wine_bar,
      'tobacco' => Icons.smoking_rooms,
      'salary' => Icons.payments,
      'income' => Icons.account_balance_wallet,
      'freelance' => Icons.work_outline,
      'refund' => Icons.replay,
      'cashback' => Icons.money,
      'rewards' => Icons.star,
      'transfer' => Icons.swap_horiz,
      'atm' => Icons.atm,
      'cash' => Icons.money,
      'investment' => Icons.trending_up,
      'savings' => Icons.savings,
      'loan_repayment' => Icons.credit_card,
      'credit_card_payment' => Icons.payment,
      'hand_loan' => Icons.handshake,
      'council_rates' => Icons.account_balance,
      'cricket' => Icons.sports_cricket,
      'karate' => Icons.sports_martial_arts,
      'swimming' => Icons.pool,
      'calisthenics' => Icons.fitness_center,
      'sports' => Icons.sports,
      'tutoring' => Icons.school,
      'professional_services' => Icons.business_center,
      'pet' => Icons.pets,
      'lottery' => Icons.casino,
      _ => Icons.category,
    };

// ── Category labels ──────────────────────────────────────────────────────────

String _catLabel(String cat) => switch (cat) {
      'groceries' => 'Groceries',
      'dining' => 'Dining Out',
      'fast_food' => 'Fast Food',
      'coffee' => 'Coffee',
      'transport' => 'Transport',
      'fuel' => 'Fuel',
      'parking' => 'Parking',
      'tolls' => 'Tolls',
      'rideshare' => 'Rideshare',
      'rent' => 'Rent',
      'mortgage' => 'Mortgage',
      'utilities' => 'Utilities',
      'home_improvement' => 'Home Improvement',
      'repairs' => 'Repairs',
      'maintenance' => 'Maintenance',
      'insurance' => 'Insurance',
      'interest' => 'Interest',
      'fees' => 'Fees',
      'bank_charges' => 'Bank Charges',
      'tax' => 'Tax',
      'medical' => 'Medical',
      'pharmacy' => 'Pharmacy',
      'fitness' => 'Fitness',
      'personal_care' => 'Personal Care',
      'apparel' => 'Apparel',
      'electronics' => 'Electronics',
      'furniture' => 'Furniture',
      'toys' => 'Toys',
      'online_shopping' => 'Online Shopping',
      'education' => 'Education',
      'school_fees' => 'School Fees',
      'childcare' => 'Childcare',
      'baby' => 'Baby',
      'entertainment' => 'Entertainment',
      'streaming' => 'Streaming',
      'subscriptions' => 'Subscriptions',
      'travel' => 'Travel',
      'hotels' => 'Hotels',
      'flights' => 'Flights',
      'gifts' => 'Gifts',
      'donations' => 'Donations',
      'charity' => 'Charity',
      'alcohol' => 'Alcohol',
      'tobacco' => 'Tobacco',
      'salary' => 'Salary',
      'income' => 'Income',
      'freelance' => 'Freelance',
      'refund' => 'Refund',
      'cashback' => 'Cashback',
      'rewards' => 'Rewards',
      'transfer' => 'Transfer',
      'atm' => 'ATM',
      'cash' => 'Cash',
      'investment' => 'Investment',
      'savings' => 'Savings',
      'loan_repayment' => 'Loan Repayment',
      'credit_card_payment' => 'Credit Card Payment',
      'hand_loan' => 'Hand Loan',
      'council_rates' => 'Council Rates',
      'cricket' => 'Cricket',
      'karate' => 'Karate',
      'swimming' => 'Swimming',
      'calisthenics' => 'Calisthenics',
      'sports' => 'Sports',
      'tutoring' => 'Tutoring',
      'professional_services' => 'Professional Services',
      'pet' => 'Pet',
      'lottery' => 'Lottery',
      'uncategorized' => 'Uncategorized',
      'other' => 'Other',
      _ => cat[0].toUpperCase() + cat.substring(1),
    };

// ── All categories for edit chip selection ───────────────────────────────────

const _allCategories = [
  // Daily living
  'groceries', 'dining', 'fast_food', 'coffee',
  // Transport
  'transport', 'fuel', 'parking', 'tolls', 'rideshare',
  // Housing
  'rent', 'mortgage', 'utilities', 'home_improvement', 'repairs', 'maintenance',
  // Insurance & finance
  'insurance', 'interest', 'fees', 'bank_charges', 'tax',
  // Health
  'medical', 'pharmacy', 'fitness', 'personal_care',
  // Shopping
  'apparel', 'electronics', 'furniture', 'toys', 'online_shopping',
  // Family & education
  'education', 'school_fees', 'childcare', 'baby',
  // Lifestyle
  'entertainment', 'streaming', 'subscriptions',
  'travel', 'hotels', 'flights',
  'gifts', 'donations', 'charity', 'alcohol', 'tobacco',
  // Income
  'salary', 'income', 'freelance', 'refund', 'cashback', 'rewards',
  // Financial
  'transfer', 'atm', 'cash', 'investment', 'savings', 'loan_repayment',
  'credit_card_payment', 'hand_loan',
  // Government
  'council_rates',
  // Sports & recreation
  'cricket', 'karate', 'swimming', 'calisthenics', 'sports',
  // Tutoring
  'tutoring',
  // Professional
  'professional_services', 'pet', 'lottery',
  // Catch-all
  'uncategorized', 'other',
];

// ═════════════════════════════════════════════════════════════════════════════
// FinanceScreen — 3-tab: Statements · Analytics · Budget
// ═════════════════════════════════════════════════════════════════════════════

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final scaffold = ScaffoldMessenger.of(context);

    int success = 0;
    int failed = 0;
    int duplicates = 0;

    for (final pf in result.files) {
      if (pf.path == null) {
        failed++;
        continue;
      }
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            pf.path!,
            filename: pf.name,
          ),
        });
        await apiClient.dio.post(
          ApiConstants.financeStatements,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            receiveTimeout: const Duration(seconds: 120),
          ),
        );
        success++;
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          duplicates++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    ref.invalidate(financeStatementsProvider);

    if (!mounted) return;
    final parts = <String>[];
    if (success > 0) parts.add('$success uploaded');
    if (duplicates > 0) parts.add('$duplicates already existed');
    if (failed > 0) parts.add('$failed failed');
    final msg = parts.join(', ');
    final hasIssues = duplicates > 0 || failed > 0;
    scaffold.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: hasIssues ? (failed > 0 ? cs.error : Colors.orange) : cs.primary,
    ));
  }

  Future<void> _reprocessAll() async {
    final scaffold = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;

    try {
      scaffold.showSnackBar(SnackBar(
        content: const Text('Reprocessing all statements...'),
        backgroundColor: cs.primary,
        duration: const Duration(seconds: 2),
      ));
      await apiClient.dio.post(ApiConstants.financeReprocessAll);
      ref.invalidate(financeStatementsProvider);
      if (!mounted) return;
      scaffold.showSnackBar(SnackBar(
        content: const Text('Reprocessing started! Pull to refresh in a moment.'),
        backgroundColor: cs.primary,
      ));
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(SnackBar(
        content: Text('Reprocess failed: $e'),
        backgroundColor: cs.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reprocess all statements',
            onPressed: _reprocessAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Statements'),
            Tab(icon: Icon(Icons.pie_chart_outline), text: 'Analytics'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Budget'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _StatementsTab(),
          _AnalyticsTab(),
          _BudgetTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUpload,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload Statement'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 1 — Statements
// ═════════════════════════════════════════════════════════════════════════════

class _StatementsTab extends ConsumerWidget {
  const _StatementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeStatementsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'financial statements'),
      data: (statements) {
        if (statements.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                const Text('No statements yet'),
                const SizedBox(height: 8),
                const Text(
                  'Tap the button below to upload\nyour first bank statement',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(financeStatementsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: statements.length,
            itemBuilder: (_, i) => _StatementCard(statement: statements[i]),
          ),
        );
      },
    );
  }
}

// ── Statement card ───────────────────────────────────────────────────────────

class _StatementCard extends ConsumerWidget {
  final BankStatement statement;
  const _StatementCard({required this.statement});

  Future<void> _deleteStatement(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Statement'),
        content: Text(
          'Delete "${statement.bankName ?? statement.originalFilename ?? 'this statement'}" '
          'and all its transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await apiClient.dio.delete(
        '${ApiConstants.financeStatements}/${statement.id}',
      );
      ref.invalidate(financeStatementsProvider);
      ref.invalidate(financeSpendingProvider('month'));
      ref.invalidate(financeSpendingProvider('3month'));
      ref.invalidate(financeSpendingProvider('6month'));
      ref.invalidate(financeSpendingProvider('year'));
      ref.invalidate(financeBudgetProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statement deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '\$');
    final isDone = statement.status == 'done';
    final isFailed = statement.status == 'failed';
    final isPending = statement.status == 'pending' ||
        statement.status == 'processing';

    return Dismissible(
      key: ValueKey(statement.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.3},
      confirmDismiss: (_) async {
        await _deleteStatement(context, ref);
        return false; // We handle removal via provider invalidation
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDone ? () => _openDetail(context) : null,
          onLongPress: () => _deleteStatement(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDone
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        size: 20,
                        color: isDone ? cs.primary : cs.outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statement.bankName ?? statement.originalFilename ?? 'Statement',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _periodText(),
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatusBadge(status: statement.status),
                        if (isPending) ...[
                          const SizedBox(height: 6),
                          _PollButton(statementId: statement.id),
                        ],
                      ],
                    ),
                  ],
                ),
                if (isDone) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.receipt_outlined,
                        label: '${statement.transactionCount} txns',
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      if (statement.totalDebits != null)
                        _InfoChip(
                          icon: Icons.arrow_downward,
                          label: fmt.format(statement.totalDebits),
                          color: Colors.red,
                        ),
                      const SizedBox(width: 10),
                      if (statement.totalCredits != null)
                        _InfoChip(
                          icon: Icons.arrow_upward,
                          label: fmt.format(statement.totalCredits),
                          color: Colors.green,
                        ),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 16, color: cs.outline),
                    ],
                  ),
                ],
                if (isFailed && statement.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    statement.errorMessage!,
                    style: TextStyle(fontSize: 11, color: cs.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _periodText() {
    if (statement.periodStart != null && statement.periodEnd != null) {
      final df = DateFormat('d MMM yyyy');
      return '${df.format(statement.periodStart!)} - ${df.format(statement.periodEnd!)}';
    }
    if (statement.statementDate != null) {
      return DateFormat('MMMM yyyy').format(statement.statementDate!);
    }
    return DateFormat('d MMM yyyy').format(statement.createdAt);
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, ctrl) => _StatementDetailSheet(
          statementId: statement.id,
          scrollController: ctrl,
        ),
      ),
    );
  }
}

// ── Poll button — re-check processing statements ─────────────────────────────

class _PollButton extends ConsumerStatefulWidget {
  final String statementId;
  const _PollButton({required this.statementId});

  @override
  ConsumerState<_PollButton> createState() => _PollButtonState();
}

class _PollButtonState extends ConsumerState<_PollButton> {
  bool _polling = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_polling) return;
    setState(() => _polling = true);
    int attempts = 0;
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      try {
        final detail =
            await ref.read(financeStatementDetailProvider(widget.statementId).future);
        if (detail.status == 'done' || detail.status == 'failed' || attempts >= 20) {
          timer.cancel();
          ref.invalidate(financeStatementsProvider);
          if (mounted) setState(() => _polling = false);
        }
      } catch (_) {
        timer.cancel();
        if (mounted) setState(() => _polling = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: TextButton.icon(
        onPressed: _polling ? null : _startPolling,
        icon: _polling
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 14),
        label: Text(
          _polling ? 'Checking...' : 'Check',
          style: const TextStyle(fontSize: 11),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'done':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.green),
              SizedBox(width: 3),
              Text('Done',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 'failed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Colors.red),
              SizedBox(width: 3),
              Text('Failed',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 'processing':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 5),
              Text('Processing',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 12, color: Colors.orange),
              SizedBox(width: 3),
              Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
    }
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.8)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
        ],
      );
}

// ── Statement detail bottom sheet ────────────────────────────────────────────

class _StatementDetailSheet extends ConsumerWidget {
  final String statementId;
  final ScrollController scrollController;
  const _StatementDetailSheet(
      {required this.statementId, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeStatementDetailProvider(statementId));
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load statement: $e')),
        data: (stmt) => _StatementDetailContent(
          statement: stmt,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _StatementDetailContent extends ConsumerStatefulWidget {
  final BankStatement statement;
  final ScrollController scrollController;
  const _StatementDetailContent(
      {required this.statement, required this.scrollController});

  @override
  ConsumerState<_StatementDetailContent> createState() =>
      _StatementDetailContentState();
}

class _StatementDetailContentState
    extends ConsumerState<_StatementDetailContent> {
  void _showEditTransaction(BuildContext context, FinanceTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditTransactionSheet(
          tx: tx,
          onSaved: () {
            ref.invalidate(
                financeStatementDetailProvider(widget.statement.id));
            ref.invalidate(financeStatementsProvider);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(financeStatementDetailProvider(widget.statement.id));
    final stmt = detailAsync.valueOrNull ?? widget.statement;
    final transactions = stmt.transactions ?? [];
    final fmt = NumberFormat.currency(symbol: '\$');
    final cs = Theme.of(context).colorScheme;

    // Group transactions by category
    final Map<String, List<FinanceTransaction>> grouped = {};
    for (final tx in transactions) {
      final cat = tx.category;
      (grouped[cat] ??= []).add(tx);
    }
    final categories = grouped.keys.toList()
      ..sort((a, b) {
        final sa = grouped[a]!.fold(0.0, (s, t) => s + t.amount.abs());
        final sb = grouped[b]!.fold(0.0, (s, t) => s + t.amount.abs());
        return sb.compareTo(sa);
      });

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stmt.bankName ?? 'Bank Statement',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (stmt.periodStart != null &&
                            stmt.periodEnd != null)
                          Text(
                            '${DateFormat('d MMM').format(stmt.periodStart!)} - ${DateFormat('d MMM yyyy').format(stmt.periodEnd!)}',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${transactions.length}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary),
                      ),
                      Text('Transactions',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Debits',
                      value: fmt.format(stmt.totalDebits ?? 0),
                      icon: Icons.arrow_downward,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Credits',
                      value: fmt.format(stmt.totalCredits ?? 0),
                      icon: Icons.arrow_upward,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Categories',
                      value: '${categories.length}',
                      icon: Icons.category_outlined,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: categories.length,
            itemBuilder: (ctx, ci) {
              final cat = categories[ci];
              final catTxns = grouped[cat]!;
              final catTotal =
                  catTxns.fold(0.0, (s, t) => s + t.amount.abs());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _catColor(cat).withOpacity(0.08),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _catColor(cat).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_catIcon(cat),
                              size: 15, color: _catColor(cat)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _catLabel(cat),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _catColor(cat),
                            ),
                          ),
                        ),
                        Text(
                          '${catTxns.length} txn${catTxns.length != 1 ? 's' : ''}'
                          ' \u00b7 ${fmt.format(catTotal)}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  ...catTxns.map((tx) => _TransactionRow(
                        tx: tx,
                        fmt: fmt,
                        onEdit: () =>
                            _showEditTransaction(context, tx),
                      )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Transaction row ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;
  final NumberFormat fmt;
  final VoidCallback? onEdit;
  const _TransactionRow({required this.tx, required this.fmt, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCredit = tx.transactionType == 'credit';

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date
            SizedBox(
              width: 42,
              child: Text(
                tx.transactionDate != null
                    ? DateFormat('d MMM').format(tx.transactionDate!)
                    : '--',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            // Merchant & description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchantName ?? tx.description ?? 'Unknown',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.description != null &&
                      tx.merchantName != null &&
                      tx.description != tx.merchantName)
                    Text(
                      tx.description!,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Category chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _catColor(tx.category).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _catLabel(tx.category),
                style: TextStyle(
                    fontSize: 9,
                    color: _catColor(tx.category),
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            // Amount
            Text(
              '${isCredit ? '+' : '-'}${fmt.format(tx.amount.abs())}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isCredit ? Colors.green : Colors.red.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 14, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// ── Edit transaction bottom sheet ────────────────────────────────────────────

class _EditTransactionSheet extends StatefulWidget {
  final FinanceTransaction tx;
  final VoidCallback onSaved;
  const _EditTransactionSheet({required this.tx, required this.onSaved});

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late Set<String> _selectedCategories;
  late bool _isEssential;
  late bool _isRecurring;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _merchantCtrl =
        TextEditingController(text: widget.tx.merchantName ?? '');
    _amountCtrl = TextEditingController(
        text: widget.tx.amount.abs().toStringAsFixed(2));
    _notesCtrl = TextEditingController(text: widget.tx.notes ?? '');
    _selectedCategories = Set<String>.from(
      widget.tx.categories.where((c) => _allCategories.contains(c)),
    );
    if (_selectedCategories.isEmpty) {
      _selectedCategories.add(widget.tx.category);
    }
    _isEssential = widget.tx.isEssential ?? false;
    _isRecurring = widget.tx.isRecurring;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'categories': _selectedCategories.toList(),
        'category': _selectedCategories.first,
        'is_essential': _isEssential,
        'is_recurring': _isRecurring,
      };

      final newMerchant = _merchantCtrl.text.trim();
      if (newMerchant.isNotEmpty && newMerchant != widget.tx.merchantName) {
        body['merchant_name'] = newMerchant;
      }
      final newAmount = double.tryParse(_amountCtrl.text.trim());
      if (newAmount != null && newAmount != widget.tx.amount.abs()) {
        body['amount'] = newAmount;
      }
      final newNotes = _notesCtrl.text.trim();
      if (newNotes != (widget.tx.notes ?? '')) {
        body['notes'] = newNotes.isEmpty ? null : newNotes;
      }

      await apiClient.dio.put(
        '${ApiConstants.financeTransactions}/${widget.tx.id}',
        data: body,
      );
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Text('Edit Transaction',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.tx.rawText != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Raw: ${widget.tx.rawText}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 20),

            // Merchant name
            TextField(
              controller: _merchantCtrl,
              decoration: InputDecoration(
                labelText: 'Merchant Name',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.store, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                isDense: true,
                prefixText: '\$ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.notes, size: 20),
              ),
            ),
            const SizedBox(height: 18),

            // Toggles
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Essential',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Necessary expense',
                        style: TextStyle(fontSize: 11)),
                    value: _isEssential,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _isEssential = v),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Recurring',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Monthly/regular',
                        style: TextStyle(fontSize: 11)),
                    value: _isRecurring,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _isRecurring = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Category chips (multi-select)
            Text('Categories',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _allCategories.map((c) {
                    final selected = _selectedCategories.contains(c);
                    return FilterChip(
                      label: Text(_catLabel(c),
                          style: const TextStyle(fontSize: 12)),
                      avatar: Icon(_catIcon(c),
                          size: 16,
                          color: selected ? Colors.white : _catColor(c)),
                      selected: selected,
                      selectedColor: _catColor(c),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedCategories.add(c);
                          } else if (_selectedCategories.length > 1) {
                            _selectedCategories.remove(c);
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary tile (reused in detail sheets) ───────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 2 — Analytics
// ═════════════════════════════════════════════════════════════════════════════

class _AnalyticsTab extends ConsumerStatefulWidget {
  const _AnalyticsTab();

  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  String _period = 'month';
  bool _downloading = false;

  Future<void> _downloadReport() async {
    setState(() => _downloading = true);
    try {
      final res = await apiClient.dio.get(
        ApiConstants.financeReport,
        queryParameters: {'period': _period},
      );
      final data = res.data as Map<String, dynamic>;

      if (!mounted) return;

      final pdfBytes = await _buildModernPdf(data);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'vitalis_finance_report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate report. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openCategoryDrillDown(String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, ctrl) => _CategoryDrillDownSheet(
          category: category,
          period: _period,
          scrollController: ctrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spendAsync = ref.watch(financeSpendingProvider(_period));
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector + download button
          Row(
            children: [
              Text('Period:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: '3month', label: Text('3 Mo')),
                    ButtonSegment(value: '6month', label: Text('6 Mo')),
                    ButtonSegment(value: 'year', label: Text('Year')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) =>
                      setState(() => _period = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _downloading ? null : _downloadReport,
                icon: _downloading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                tooltip: 'Download Report',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Spending data
          spendAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => FriendlyError(error: e, context: 'financial spending'),
            data: (spending) {
              if (spending.byCategory.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 64, color: cs.outline),
                        const SizedBox(height: 16),
                        const Text('No spending data yet'),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload bank statements to see analytics',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Essential vs Discretionary summary
                  _EssentialDiscretionaryRow(spending: spending),
                  const SizedBox(height: 24),

                  // Pie chart
                  Text('Spending by Category',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Tap a category to view & edit transactions',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _SpendingPieChart(spending: spending),
                  const SizedBox(height: 20),

                  // Category list (tappable)
                  ...spending.byCategory.map(
                    (cat) => _CategoryListItem(
                      cat: cat,
                      spending: spending,
                      onTap: () => _openCategoryDrillDown(cat.category),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Essential vs Discretionary row ───────────────────────────────────────────

class _EssentialDiscretionaryRow extends StatelessWidget {
  final FinanceSpending spending;
  const _EssentialDiscretionaryRow({required this.spending});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text('Essential',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fmt.format(spending.essentialSpend),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spending.totalSpend > 0
                        ? '${(spending.essentialSpend / spending.totalSpend * 100).toStringAsFixed(0)}% of total'
                        : '0% of total',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text('Discretionary',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fmt.format(spending.discretionarySpend),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spending.totalSpend > 0
                        ? '${(spending.discretionarySpend / spending.totalSpend * 100).toStringAsFixed(0)}% of total'
                        : '0% of total',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Spending pie chart ───────────────────────────────────────────────────────

class _SpendingPieChart extends StatelessWidget {
  final FinanceSpending spending;
  const _SpendingPieChart({required this.spending});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final cats = spending.byCategory;

    // Show top 8 categories, group rest as "Other"
    final topCats = cats.length > 8 ? cats.sublist(0, 8) : cats;
    final otherAmount = cats.length > 8
        ? cats.sublist(8).fold(0.0, (s, c) => s + c.amount)
        : 0.0;
    final otherPct = cats.length > 8
        ? cats.sublist(8).fold(0.0, (s, c) => s + c.percentage)
        : 0.0;

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                ...topCats.map((c) => PieChartSectionData(
                      value: c.amount,
                      color: _catColor(c.category),
                      radius: 45,
                      title: c.percentage >= 8
                          ? '${c.percentage.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    )),
                if (otherAmount > 0)
                  PieChartSectionData(
                    value: otherAmount,
                    color: Colors.grey.shade400,
                    radius: 45,
                    title: otherPct >= 8
                        ? '${otherPct.toStringAsFixed(0)}%'
                        : '',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
          // Center total
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(
                fmt.format(spending.totalSpend),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Category list item ───────────────────────────────────────────────────────

class _CategoryListItem extends StatelessWidget {
  final FinanceCategorySpend cat;
  final FinanceSpending spending;
  final VoidCallback? onTap;
  const _CategoryListItem({required this.cat, required this.spending, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '\$');
    final color = _catColor(cat.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_catIcon(cat.category), size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_catLabel(cat.category),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.count} transaction${cat.count != 1 ? 's' : ''}',
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt.format(cat.amount),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color)),
                    const SizedBox(height: 2),
                    Text(
                      '${cat.percentage.toStringAsFixed(1)}%',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 3 — Budget
// ═════════════════════════════════════════════════════════════════════════════

class _BudgetTab extends ConsumerWidget {
  const _BudgetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(financeBudgetProvider);
    final cs = Theme.of(context).colorScheme;

    return budgetAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'budget'),
      data: (budget) {
        if (budget.budget.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 64, color: cs.outline),
                const SizedBox(height: 16),
                const Text('No budget data yet'),
                const SizedBox(height: 8),
                const Text(
                  'Upload bank statements to generate\nyour spending budget',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final fmt = NumberFormat.currency(symbol: '\$');
        final essentialItems =
            budget.budget.where((b) => b.isEssential).toList();
        final discretionaryItems =
            budget.budget.where((b) => !b.isEssential).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(financeBudgetProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Income vs Expenses summary
              _IncomeExpensesSummary(budget: budget, fmt: fmt),
              const SizedBox(height: 16),

              // Recommendation badge
              _RecommendationBadge(recommendation: budget.recommendation),
              const SizedBox(height: 20),

              // Income Needed card
              _IncomeNeededCard(budget: budget, fmt: fmt),
              const SizedBox(height: 24),

              // Essential section
              if (essentialItems.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Essential',
                  icon: Icons.shield_outlined,
                  color: Colors.blue,
                  subtitle: fmt.format(budget.essentialMonthly),
                ),
                const SizedBox(height: 8),
                ...essentialItems
                    .map((item) => _BudgetItemCard(item: item, fmt: fmt)),
                const SizedBox(height: 20),
              ],

              // Discretionary section
              if (discretionaryItems.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Discretionary',
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.orange,
                  subtitle: fmt.format(budget.discretionaryMonthly),
                ),
                const SizedBox(height: 8),
                ...discretionaryItems
                    .map((item) => _BudgetItemCard(item: item, fmt: fmt)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Income vs Expenses summary ───────────────────────────────────────────────

class _IncomeExpensesSummary extends StatelessWidget {
  final FinanceBudget budget;
  final NumberFormat fmt;
  const _IncomeExpensesSummary({required this.budget, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSurplus = budget.surplusDeficit >= 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.account_balance,
                    size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text('Monthly Summary',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: cs.primary)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.arrow_upward,
                          size: 24, color: Colors.green.shade600),
                      const SizedBox(height: 4),
                      Text('Income',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(budget.averageMonthlyIncome),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: cs.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.arrow_downward,
                          size: 24, color: Colors.red.shade600),
                      const SizedBox(height: 4),
                      Text('Expenses',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(budget.totalMonthlyBudget),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: cs.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        isSurplus
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 24,
                        color: isSurplus
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                      const SizedBox(height: 4),
                      Text(isSurplus ? 'Surplus' : 'Deficit',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        '${isSurplus ? '+' : ''}${fmt.format(budget.surplusDeficit)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSurplus
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recommendation badge ─────────────────────────────────────────────────────

class _RecommendationBadge extends StatelessWidget {
  final String recommendation;
  const _RecommendationBadge({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    switch (recommendation) {
      case 'surplus':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        label = 'You have a healthy surplus. Consider saving or investing the extra.';
      case 'deficit':
        color = Colors.red;
        icon = Icons.warning_amber_outlined;
        label =
            'You are spending more than you earn. Review discretionary expenses.';
      case 'tight':
      default:
        color = Colors.orange;
        icon = Icons.info_outline;
        label =
            'Your budget is tight. Small changes in discretionary spending can help.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Income Needed card ───────────────────────────────────────────────────────

class _IncomeNeededCard extends StatelessWidget {
  final FinanceBudget budget;
  final NumberFormat fmt;
  const _IncomeNeededCard({required this.budget, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calculate_outlined,
                  color: Colors.indigo, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Income Needed',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade700)),
                  const SizedBox(height: 2),
                  Text(
                    'Estimated annual income to sustain current spending',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              fmt.format(budget.incomeNeeded),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.indigo.shade800),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  const _SectionHeader(
      {required this.title,
      required this.icon,
      required this.color,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        const Spacer(),
        Text(subtitle,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        const Text('/mo',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Budget item card ─────────────────────────────────────────────────────────

class _BudgetItemCard extends StatelessWidget {
  final BudgetItem item;
  final NumberFormat fmt;
  const _BudgetItemCard({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _catColor(item.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_catIcon(item.category), size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _catLabel(item.category),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(item.monthlyAverage)}/mo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.format(item.quarterlyTotal)} / quarter',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Category Drill-Down Sheet — tap a category in Analytics to see & edit txns
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryDrillDownSheet extends ConsumerStatefulWidget {
  final String category;
  final String period;
  final ScrollController scrollController;
  const _CategoryDrillDownSheet({
    required this.category,
    required this.period,
    required this.scrollController,
  });

  @override
  ConsumerState<_CategoryDrillDownSheet> createState() =>
      _CategoryDrillDownSheetState();
}

class _CategoryDrillDownSheetState
    extends ConsumerState<_CategoryDrillDownSheet> {
  List<FinanceTransaction>? _transactions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final res = await apiClient.dio.get(
        ApiConstants.financeSpendingTxns,
        queryParameters: {
          'period': widget.period,
          'category': widget.category,
        },
      );
      final list = (res.data['transactions'] as List)
          .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _transactions = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _showEditTransaction(FinanceTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditTransactionSheet(
          tx: tx,
          onSaved: () {
            _loadTransactions();
            // Also invalidate analytics so the pie chart updates
            ref.invalidate(financeSpendingProvider(widget.period));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '\$');
    final color = _catColor(widget.category);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_catIcon(widget.category), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _catLabel(widget.category),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tap a transaction to edit',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_transactions != null)
                  Text(
                    '${_transactions!.length} txns',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(friendlyErrorMessage(_error!, context: 'transactions'), textAlign: TextAlign.center)))
          else if (_transactions!.isEmpty)
            const Expanded(child: Center(child: Text('No transactions')))
          else
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _transactions!.length,
                itemBuilder: (_, i) => _TransactionRow(
                  tx: _transactions![i],
                  fmt: fmt,
                  onEdit: () => _showEditTransaction(_transactions![i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Modern PDF Report Builder
// ═════════════════════════════════════════════════════════════════════════════

const _pdfPrimary = PdfColor.fromInt(0xFF0D6E4F);
const _pdfAccent = PdfColor.fromInt(0xFF10B981);
const _pdfDark = PdfColor.fromInt(0xFF1B1B1F);
const _pdfMuted = PdfColor.fromInt(0xFF6B7280);
const _pdfBg = PdfColor.fromInt(0xFFF9FAFB);
const _pdfWhite = PdfColors.white;
const _pdfRed = PdfColor.fromInt(0xFFEF4444);
const _pdfAmber = PdfColor.fromInt(0xFFF59E0B);

final _pdfChartColors = [
  const PdfColor.fromInt(0xFF0D6E4F),
  const PdfColor.fromInt(0xFF10B981),
  const PdfColor.fromInt(0xFF3B82F6),
  const PdfColor.fromInt(0xFFF59E0B),
  const PdfColor.fromInt(0xFFEF4444),
  const PdfColor.fromInt(0xFF8B5CF6),
  const PdfColor.fromInt(0xFFEC4899),
  const PdfColor.fromInt(0xFF14B8A6),
  const PdfColor.fromInt(0xFFF97316),
  const PdfColor.fromInt(0xFF6366F1),
];

Future<Uint8List> _buildModernPdf(Map<String, dynamic> data) async {
  final doc = pw.Document();
  final summary = data['summary'] as Map<String, dynamic>? ?? {};
  final sections = data['sections'] as Map<String, dynamic>? ?? {};
  final period = data['period'] as String? ?? 'month';
  final periodLabels = {'month': 'Last Month', '3month': 'Last 3 Months',
                        '6month': 'Last 6 Months', 'year': 'Last Year'};
  final periodLabel = periodLabels[period] ?? period;

  final categories = (sections['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final monthlyTrends = (sections['monthly_trends'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final topMerchants = (sections['top_merchants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final freqMerchants = (sections['frequent_merchants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final dayOfWeek = (sections['day_of_week'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final biggestTxns = (sections['biggest_transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final impulse = (sections['impulse_spending'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final anomalies = (sections['anomalies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final recurring = (sections['recurring'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final insights = (sections['insights'] as List?)?.cast<String>() ?? [];
  final catChanges = (sections['category_changes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final weekendWeekday = sections['weekend_vs_weekday'] as Map<String, dynamic>? ?? {};
  final velocity = sections['velocity'] as Map<String, dynamic>? ?? {};
  final autoPayments = sections['auto_payments'] as Map<String, dynamic>? ?? {};

  final totalSpend = (summary['total_spend'] as num?)?.toDouble() ?? 0;
  final totalIncome = (summary['total_income'] as num?)?.toDouble() ?? 0;
  final net = (summary['net'] as num?)?.toDouble() ?? 0;
  final essentialSpend = (summary['essential_spend'] as num?)?.toDouble() ?? 0;
  final discretionarySpend = (summary['discretionary_spend'] as num?)?.toDouble() ?? 0;
  final healthScore = (summary['health_score'] as num?)?.toInt() ?? 0;
  final healthGrade = summary['health_grade'] as String? ?? '-';
  final txnCount = (summary['transaction_count'] as num?)?.toInt() ?? 0;

  final nf = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final nfShort = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  // ── Styles ──
  final titleStyle = pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pdfWhite);
  final h1 = pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _pdfPrimary);
  final h2 = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _pdfDark);
  final body = pw.TextStyle(fontSize: 9, color: _pdfDark);
  final bodyMuted = pw.TextStyle(fontSize: 8, color: _pdfMuted);
  final bodyBold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfDark);
  final numStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfDark, font: pw.Font.courierBold());

  // ── Helper: section header ──
  pw.Widget sectionHeader(String title) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _pdfAccent, width: 2)),
    ),
    child: pw.Text(title, style: h1),
  );

  // ── Helper: stat card ──
  pw.Widget statCard(String label, String value, {PdfColor color = _pdfDark}) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _pdfBg,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: bodyMuted),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    ),
  );

  // ── Helper: horizontal bar ──
  pw.Widget hBar(double pct, {PdfColor color = _pdfAccent, double maxW = 180}) => pw.Container(
    width: maxW * (pct / 100).clamp(0.01, 1.0),
    height: 10,
    decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
  );

  // ── Helper: table row ──
  pw.Widget tRow(List<String> cells, {bool header = false, List<int>? flex}) {
    final s = header ? bodyBold : body;
    final bg = header ? _pdfBg : _pdfWhite;
    final flexes = flex ?? List.filled(cells.length, 1);
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Row(
        children: List.generate(cells.length, (i) =>
          pw.Expanded(flex: flexes[i], child: pw.Text(cells[i], style: s)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD PAGES
  // ═══════════════════════════════════════════════════════════════════════════
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox.shrink() : pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Vitalis Finance Report', style: pw.TextStyle(fontSize: 8, color: _pdfMuted)),
          pw.Text(periodLabel, style: pw.TextStyle(fontSize: 8, color: _pdfMuted)),
        ],
      ),
    ),
    footer: (ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB))),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by Vitalis', style: pw.TextStyle(fontSize: 7, color: _pdfMuted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: _pdfMuted)),
        ],
      ),
    ),
    build: (ctx) => [
      // ── Cover / Header Banner ──
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(
          color: _pdfPrimary,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('VITALIS', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF86EFAC), fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
            pw.SizedBox(height: 4),
            pw.Text('Finance Intelligence Report', style: titleStyle),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(0x33FFFFFF), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(periodLabel, style: pw.TextStyle(fontSize: 9, color: _pdfWhite)),
              ),
              pw.SizedBox(width: 12),
              pw.Text(DateFormat('d MMM yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xCCFFFFFF))),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 16),

      // ── Executive Summary Cards ──
      pw.Row(children: [
        pw.Expanded(child: statCard('Total Income', nf.format(totalIncome), color: _pdfPrimary)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: statCard('Total Spending', nf.format(totalSpend), color: _pdfRed)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: statCard('Net Cash Flow', nf.format(net), color: net >= 0 ? _pdfPrimary : _pdfRed)),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(child: statCard('Transactions', '$txnCount debits')),
        pw.SizedBox(width: 8),
        pw.Expanded(child: statCard('Essential', nf.format(essentialSpend))),
        pw.SizedBox(width: 8),
        pw.Expanded(child: statCard('Discretionary', nf.format(discretionarySpend))),
      ]),

      // ── Health Score ──
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: healthScore >= 60 ? _pdfAccent : _pdfAmber, width: 1.5),
        ),
        child: pw.Row(children: [
          pw.Container(
            width: 48, height: 48,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: healthScore >= 80 ? _pdfPrimary : healthScore >= 60 ? _pdfAmber : _pdfRed,
            ),
            child: pw.Center(child: pw.Text(healthGrade, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pdfWhite))),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Financial Health Score: $healthScore / 100', style: h2),
              pw.SizedBox(height: 4),
              pw.Stack(children: [
                pw.Container(height: 8, width: 400, decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE5E7EB), borderRadius: pw.BorderRadius.circular(4))),
                pw.Container(height: 8, width: 400 * (healthScore / 100.0), decoration: pw.BoxDecoration(
                  color: healthScore >= 80 ? _pdfPrimary : healthScore >= 60 ? _pdfAmber : _pdfRed,
                  borderRadius: pw.BorderRadius.circular(4),
                )),
              ]),
            ],
          )),
        ]),
      ),

      // ── Spending by Category ──
      if (categories.isNotEmpty) ...[
        sectionHeader('Spending by Category'),
        ...categories.take(12).map((c) {
          final pct = (c['pct'] as num?)?.toDouble() ?? 0;
          final idx = categories.indexOf(c) % _pdfChartColors.length;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(children: [
              pw.SizedBox(width: 100, child: pw.Text(
                (c['name'] as String? ?? '').replaceAll('_', ' '),
                style: body,
              )),
              pw.SizedBox(width: 4),
              pw.Expanded(child: hBar(pct, color: _pdfChartColors[idx], maxW: 250)),
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 65, child: pw.Text(nf.format((c['amount'] as num?)?.toDouble() ?? 0), style: numStyle, textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 35, child: pw.Text('${pct.toStringAsFixed(1)}%', style: bodyMuted, textAlign: pw.TextAlign.right)),
            ]),
          );
        }),
      ],

      // ── Category Trends ──
      if (catChanges.isNotEmpty) ...[
        sectionHeader('Category Trends vs Prior Period'),
        ...catChanges.where((c) => ((c['change_pct'] as num?)?.abs() ?? 0) > 10).take(8).map((c) {
          final pct = (c['change_pct'] as num?)?.toDouble() ?? 0;
          final isUp = pct > 0;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(children: [
              pw.SizedBox(width: 100, child: pw.Text((c['category'] as String? ?? '').replaceAll('_', ' '), style: body)),
              pw.Text(isUp ? '▲' : '▼', style: pw.TextStyle(fontSize: 8, color: isUp ? _pdfRed : _pdfPrimary)),
              pw.SizedBox(width: 4),
              pw.SizedBox(width: 65, child: pw.Text(nf.format((c['current'] as num?)?.toDouble() ?? 0), style: numStyle, textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 8),
              pw.Text('was ${nf.format((c['previous'] as num?)?.toDouble() ?? 0)}', style: bodyMuted),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: isUp ? PdfColor.fromInt(0x1AEF4444) : PdfColor.fromInt(0x1A10B981),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('${pct > 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: isUp ? _pdfRed : _pdfPrimary)),
              ),
            ]),
          );
        }),
      ],

      // ── Monthly Trends (detailed) ──
      if (monthlyTrends.isNotEmpty) ...[
        sectionHeader('Monthly Intelligence'),
        ...monthlyTrends.skip(monthlyTrends.length > 12 ? monthlyTrends.length - 12 : 0).map((m) {
          final mNet = (m['net'] as num?)?.toDouble() ?? 0;
          final topCats = (m['top_categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final topMerch = m['top_merchant'] as Map<String, dynamic>?;
          final recur = (m['recurring'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Month header row
                pw.Row(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(color: _pdfPrimary, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(m['month'] as String? ?? '', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfWhite)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text('Income ', style: bodyMuted),
                  pw.Text(nfShort.format((m['income'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 9, color: _pdfPrimary, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 10),
                  pw.Text('Spend ', style: bodyMuted),
                  pw.Text(nfShort.format((m['expenses'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 9, color: _pdfRed, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 10),
                  pw.Text('Net ', style: bodyMuted),
                  pw.Text(nfShort.format(mNet), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: mNet >= 0 ? _pdfPrimary : _pdfRed)),
                ]),
                pw.SizedBox(height: 6),
                // Top categories + top merchant + recurring in columns
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Top categories
                    pw.Expanded(flex: 3, child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Top Categories', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfMuted)),
                        pw.SizedBox(height: 2),
                        ...topCats.map((c) {
                          final catAmt = (c['amount'] as num?)?.toDouble() ?? 0;
                          final monthExp = (m['expenses'] as num?)?.toDouble() ?? 1;
                          final pct = monthExp > 0 ? (catAmt / monthExp * 100) : 0.0;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 1),
                            child: pw.Row(children: [
                              pw.SizedBox(width: 75, child: pw.Text(
                                (c['name'] as String? ?? '').replaceAll('_', ' '),
                                style: pw.TextStyle(fontSize: 7, color: _pdfDark),
                              )),
                              pw.Expanded(child: pw.Stack(children: [
                                pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE5E7EB), borderRadius: pw.BorderRadius.circular(3))),
                                pw.Container(height: 6, width: 100 * (pct / 100).clamp(0.01, 1.0),
                                  decoration: pw.BoxDecoration(color: _pdfAccent, borderRadius: pw.BorderRadius.circular(3))),
                              ])),
                              pw.SizedBox(width: 4),
                              pw.Text(nfShort.format(catAmt), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfDark)),
                            ]),
                          );
                        }),
                      ],
                    )),
                    pw.SizedBox(width: 10),
                    // Top merchant
                    pw.Expanded(flex: 2, child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Top Merchant', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfMuted)),
                        pw.SizedBox(height: 2),
                        if (topMerch != null) ...[
                          pw.Text(topMerch['name'] as String? ?? '', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfDark)),
                          pw.Text(nf.format((topMerch['amount'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 8, color: _pdfRed)),
                        ] else
                          pw.Text('-', style: bodyMuted),
                      ],
                    )),
                    pw.SizedBox(width: 10),
                    // Recurring
                    pw.Expanded(flex: 2, child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Recurring', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfMuted)),
                        pw.SizedBox(height: 2),
                        if (recur.isNotEmpty)
                          ...recur.map((r) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 1),
                            child: pw.Row(children: [
                              pw.Expanded(child: pw.Text(r['name'] as String? ?? '', style: pw.TextStyle(fontSize: 7, color: _pdfDark), maxLines: 1)),
                              pw.Text(nfShort.format((r['amount'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfAmber)),
                            ]),
                          ))
                        else
                          pw.Text('-', style: bodyMuted),
                      ],
                    )),
                  ],
                ),
              ],
            ),
          );
        }),
      ],

      // ── Top Merchants ──
      if (topMerchants.isNotEmpty) ...[
        sectionHeader('Top Merchants'),
        tRow(['Merchant', 'Spend', 'Visits'], header: true, flex: [4, 2, 1]),
        ...topMerchants.map((m) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6)))),
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: 4, child: pw.Text(m['name'] as String? ?? '', style: body)),
            pw.Expanded(flex: 2, child: pw.Text(nf.format((m['amount'] as num?)?.toDouble() ?? 0), style: numStyle)),
            pw.Expanded(flex: 1, child: pw.Text('${m['visits'] ?? 0}', style: bodyMuted, textAlign: pw.TextAlign.center)),
          ]),
        )),
      ],

      // ── Day of Week ──
      if (dayOfWeek.isNotEmpty) ...[
        sectionHeader('Spending by Day of Week'),
        ...() {
          final maxAmt = dayOfWeek.fold<double>(0, (m, d) => ((d['amount'] as num?)?.toDouble() ?? 0) > m ? (d['amount'] as num).toDouble() : m);
          return dayOfWeek.map((d) {
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            final pct = maxAmt > 0 ? (amt / maxAmt * 100) : 0.0;
            final isWeekend = (d['day'] == 'Saturday' || d['day'] == 'Sunday');
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(children: [
                pw.SizedBox(width: 65, child: pw.Text(d['day'] as String? ?? '', style: isWeekend ? bodyBold : body)),
                pw.Expanded(child: hBar(pct, color: isWeekend ? _pdfAmber : _pdfAccent, maxW: 250)),
                pw.SizedBox(width: 8),
                pw.SizedBox(width: 65, child: pw.Text(nf.format(amt), style: numStyle, textAlign: pw.TextAlign.right)),
                pw.SizedBox(width: 35, child: pw.Text('${d['count'] ?? 0} txns', style: bodyMuted, textAlign: pw.TextAlign.right)),
              ]),
            );
          });
        }(),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFFEF3C7), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Weekend: ${nf.format((weekendWeekday['weekend'] as num?)?.toDouble() ?? 0)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfAmber)),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFD1FAE5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Weekday: ${nf.format((weekendWeekday['weekday'] as num?)?.toDouble() ?? 0)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfPrimary)),
          ),
        ]),
      ],

      // ── Spending Velocity ──
      if (velocity.isNotEmpty) ...[
        sectionHeader('Spending Velocity'),
        pw.Row(children: [
          pw.Expanded(child: statCard('Daily Average', nf.format((velocity['daily_avg'] as num?)?.toDouble() ?? 0))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: statCard('Projected Monthly', nf.format((velocity['projected_monthly'] as num?)?.toDouble() ?? 0))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: statCard('Highest Day', '${nf.format((velocity['highest_day'] as num?)?.toDouble() ?? 0)}\n${velocity['highest_day_date'] ?? ''}')),
        ]),
      ],

      // ── Largest Transactions ──
      if (biggestTxns.isNotEmpty) ...[
        sectionHeader('Largest Transactions'),
        tRow(['Date', 'Merchant', 'Category', 'Amount'], header: true, flex: [2, 4, 2, 2]),
        ...biggestTxns.map((t) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6)))),
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Text(t['date'] as String? ?? '', style: bodyMuted)),
            pw.Expanded(flex: 4, child: pw.Text(t['merchant'] as String? ?? '', style: body)),
            pw.Expanded(flex: 2, child: pw.Text((t['category'] as String? ?? '').replaceAll('_', ' '), style: bodyMuted)),
            pw.Expanded(flex: 2, child: pw.Text(nf.format((t['amount'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfRed), textAlign: pw.TextAlign.right)),
          ]),
        )),
      ],

      // ── Impulse Spending ──
      if (impulse.isNotEmpty) ...[
        sectionHeader('Impulse Spending Analysis'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFEF2F2),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFFECACA)),
          ),
          child: pw.Row(children: [
            pw.Text('Total impulse spending: ', style: body),
            pw.Text(nf.format(impulse.fold<double>(0, (s, i) => s + ((i['total'] as num?)?.toDouble() ?? 0))),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfRed)),
            pw.Text('  •  Potential monthly savings (30% cut): ', style: body),
            pw.Text(nf.format(impulse.fold<double>(0, (s, i) => s + ((i['total'] as num?)?.toDouble() ?? 0)) * 0.3),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfPrimary)),
          ]),
        ),
        pw.SizedBox(height: 6),
        tRow(['Category', 'Total', 'Txns', 'Avg'], header: true, flex: [3, 2, 1, 2]),
        ...impulse.take(8).map((i) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6)))),
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: 3, child: pw.Text((i['category'] as String? ?? '').replaceAll('_', ' '), style: body)),
            pw.Expanded(flex: 2, child: pw.Text(nf.format((i['total'] as num?)?.toDouble() ?? 0), style: numStyle)),
            pw.Expanded(flex: 1, child: pw.Text('${i['count'] ?? 0}', style: bodyMuted, textAlign: pw.TextAlign.center)),
            pw.Expanded(flex: 2, child: pw.Text(nf.format((i['avg'] as num?)?.toDouble() ?? 0), style: bodyMuted)),
          ]),
        )),
      ],

      // ── Recurring Expenses ──
      if (recurring.isNotEmpty) ...[
        sectionHeader('Recurring Expenses & Subscriptions'),
        tRow(['Merchant', 'Amount', 'Category'], header: true, flex: [4, 2, 2]),
        ...recurring.take(10).map((r) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6)))),
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: 4, child: pw.Text(r['merchant'] as String? ?? '', style: body)),
            pw.Expanded(flex: 2, child: pw.Text(nf.format((r['amount'] as num?)?.toDouble() ?? 0), style: numStyle)),
            pw.Expanded(flex: 2, child: pw.Text((r['category'] as String? ?? '').replaceAll('_', ' '), style: bodyMuted)),
          ]),
        )),
      ],

      // ── Unusual Transactions ──
      if (anomalies.isNotEmpty) ...[
        sectionHeader('Unusual Transactions'),
        pw.Text('Transactions significantly above their category averages:', style: bodyMuted),
        pw.SizedBox(height: 6),
        ...anomalies.take(6).map((a) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFFFBEB),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFFDE68A)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 55, child: pw.Text(a['date'] as String? ?? '', style: bodyMuted)),
            pw.Expanded(child: pw.Text(a['merchant'] as String? ?? '', style: body)),
            pw.Text(nf.format((a['amount'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfRed)),
            pw.SizedBox(width: 8),
            pw.Text('avg: ${nf.format((a['category_avg'] as num?)?.toDouble() ?? 0)}', style: bodyMuted),
          ]),
        )),
      ],

      // ── Insights & Recommendations ──
      if (insights.isNotEmpty) ...[
        sectionHeader('Insights & Recommendations'),
        ...insights.asMap().entries.map((e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: e.key == 0 ? PdfColor.fromInt(0xFFECFDF5) : _pdfBg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: e.key == 0 ? PdfColor.fromInt(0xFFA7F3D0) : PdfColor.fromInt(0xFFE5E7EB)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18, height: 18,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: _pdfPrimary,
                ),
                child: pw.Center(child: pw.Text('${e.key + 1}', style: pw.TextStyle(fontSize: 8, color: _pdfWhite, fontWeight: pw.FontWeight.bold))),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(e.value, style: body)),
            ],
          ),
        )),
      ],

      // ── Auto-Payments ──
      if ((autoPayments['total'] as num?)?.toInt() != null && (autoPayments['total'] as num).toInt() > 0) ...[
        sectionHeader('Auto-Payments (Excluded from Spending)'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF0F9FF),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFBAE6FD)),
          ),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Successful Payments', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfPrimary)),
                pw.Text('${autoPayments['paid'] ?? 0} payments  •  ${nf.format((autoPayments['paid_amount'] as num?)?.toDouble() ?? 0)}',
                  style: pw.TextStyle(fontSize: 9, color: _pdfDark)),
              ],
            )),
            pw.SizedBox(width: 16),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Dishonoured / Bounced', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                  color: ((autoPayments['dishonoured'] as num?)?.toInt() ?? 0) > 0 ? _pdfRed : _pdfPrimary)),
                pw.Text('${autoPayments['dishonoured'] ?? 0} payments  •  ${nf.format((autoPayments['dishonoured_amount'] as num?)?.toDouble() ?? 0)}',
                  style: pw.TextStyle(fontSize: 9, color: _pdfDark)),
              ],
            )),
          ]),
        ),
        if ((autoPayments['items'] as List?)?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 6),
          tRow(['Date', 'Merchant', 'Amount', 'Status'], header: true, flex: [2, 4, 2, 2]),
          ...(autoPayments['items'] as List).cast<Map<String, dynamic>>().take(10).map((a) => pw.Container(
            decoration: pw.BoxDecoration(
              color: (a['status'] as String?) == 'dishonoured' ? PdfColor.fromInt(0x0DEF4444) : _pdfWhite,
              border: const pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6))),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            child: pw.Row(children: [
              pw.Expanded(flex: 2, child: pw.Text(a['date'] as String? ?? '', style: bodyMuted)),
              pw.Expanded(flex: 4, child: pw.Text(a['merchant'] as String? ?? '', style: body)),
              pw.Expanded(flex: 2, child: pw.Text(nf.format((a['amount'] as num?)?.toDouble() ?? 0), style: numStyle)),
              pw.Expanded(flex: 2, child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: (a['status'] as String?) == 'dishonoured' ? PdfColor.fromInt(0x1AEF4444) : PdfColor.fromInt(0x1A10B981),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  (a['status'] as String?) == 'dishonoured' ? 'BOUNCED' : 'PAID',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold,
                    color: (a['status'] as String?) == 'dishonoured' ? _pdfRed : _pdfPrimary),
                  textAlign: pw.TextAlign.center,
                ),
              )),
            ]),
          )),
        ],
      ],

      // ── Footer ──
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _pdfPrimary,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(child: pw.Text(
          'Vitalis Finance Intelligence  •  Your money, your insights',
          style: pw.TextStyle(fontSize: 9, color: _pdfWhite),
        )),
      ),
    ],
  ));

  return doc.save();
}
