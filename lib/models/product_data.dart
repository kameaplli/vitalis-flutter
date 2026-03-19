/// Phase 4: Product Scanner data models
library;

class ProductEntry {
  final String id;
  final String productName;
  final String? productType;
  final String? brand;
  final String? barcode;
  final double? safetyScore;
  final List<FlaggedIrritant> flaggedIrritants;
  final String? startedUsing;
  final String? stoppedUsing;
  final int? rating;
  final String? createdAt;

  ProductEntry({
    required this.id,
    required this.productName,
    this.productType,
    this.brand,
    this.barcode,
    this.safetyScore,
    this.flaggedIrritants = const [],
    this.startedUsing,
    this.stoppedUsing,
    this.rating,
    this.createdAt,
  });

  factory ProductEntry.fromJson(Map<String, dynamic> json) {
    return ProductEntry(
      id: json['id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      productType: json['product_type'] as String?,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      safetyScore: (json['safety_score'] as num?)?.toDouble(),
      flaggedIrritants: (json['flagged_irritants'] as List<dynamic>?)
              ?.map((f) => FlaggedIrritant.fromJson(f as Map<String, dynamic>))
              .toList() ??
          const [],
      startedUsing: json['started_using'] as String?,
      stoppedUsing: json['stopped_using'] as String?,
      rating: json['rating'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isActive => stoppedUsing == null;
}

class FlaggedIrritant {
  final String ingredient;
  final String category;
  final String risk;
  final String? note;

  FlaggedIrritant({
    required this.ingredient,
    required this.category,
    required this.risk,
    this.note,
  });

  factory FlaggedIrritant.fromJson(Map<String, dynamic> json) {
    return FlaggedIrritant(
      ingredient: json['ingredient'] as String? ?? '',
      category: json['category'] as String? ?? '',
      risk: json['risk'] as String? ?? 'medium',
      note: json['note'] as String?,
    );
  }
}

class ProductCorrelation {
  final String productName;
  final String? brand;
  final String started;
  final String? stopped;
  final double avgItchDuring;
  final double avgItchBefore;
  final double change;
  final int daysUsed;
  final String verdict;

  ProductCorrelation({
    required this.productName,
    this.brand,
    required this.started,
    this.stopped,
    required this.avgItchDuring,
    required this.avgItchBefore,
    required this.change,
    required this.daysUsed,
    required this.verdict,
  });

  factory ProductCorrelation.fromJson(Map<String, dynamic> json) {
    return ProductCorrelation(
      productName: json['product_name'] as String? ?? '',
      brand: json['brand'] as String?,
      started: json['started'] as String? ?? '',
      stopped: json['stopped'] as String?,
      avgItchDuring: (json['avg_itch_during'] as num?)?.toDouble() ?? 0,
      avgItchBefore: (json['avg_itch_before'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      daysUsed: json['days_used'] as int? ?? 0,
      verdict: json['verdict'] as String? ?? 'neutral',
    );
  }
}
