class GroceryReceipt {
  final String id;
  final String status;
  final String? storeName;
  final String? storeChain;
  final String? currency;
  final DateTime? receiptDate;
  final double? totalAmount;
  final double? subtotalAmount;
  final double? taxAmount;
  final double? totalFoodSpend;
  final String? imageUrl;
  final int itemCount;
  final int foodItemCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? processedAt;
  final List<GroceryItem>? items;

  const GroceryReceipt({
    required this.id,
    required this.status,
    this.storeName,
    this.storeChain,
    this.currency,
    this.receiptDate,
    this.totalAmount,
    this.subtotalAmount,
    this.taxAmount,
    this.totalFoodSpend,
    this.imageUrl,
    required this.itemCount,
    required this.foodItemCount,
    this.errorMessage,
    required this.createdAt,
    this.processedAt,
    this.items,
  });

  factory GroceryReceipt.fromJson(Map<String, dynamic> j) => GroceryReceipt(
        id:             j['id'] as String,
        status:         j['status'] as String? ?? 'pending',
        storeName:      j['store_name'] as String?,
        storeChain:     j['store_chain'] as String?,
        currency:       j['currency'] as String?,
        receiptDate:    j['receipt_date'] != null
            ? DateTime.tryParse(j['receipt_date'] as String)
            : null,
        totalAmount:    (j['total_amount'] as num?)?.toDouble(),
        subtotalAmount: (j['subtotal_amount'] as num?)?.toDouble(),
        taxAmount:      (j['tax_amount'] as num?)?.toDouble(),
        totalFoodSpend: (j['total_food_spend'] as num?)?.toDouble(),
        imageUrl:       j['image_url'] as String?,
        itemCount:      (j['item_count'] as num?)?.toInt() ?? 0,
        foodItemCount:  (j['food_item_count'] as num?)?.toInt() ?? 0,
        errorMessage:   j['error_message'] as String?,
        createdAt:      DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        processedAt:    j['processed_at'] != null
            ? DateTime.tryParse(j['processed_at'] as String)
            : null,
        items: j['items'] != null
            ? (j['items'] as List).map((e) => GroceryItem.fromJson(e as Map<String, dynamic>)).toList()
            : null,
      );
}

class GroceryItem {
  final String id;
  final String receiptId;
  final String? rawText;
  final String? normalizedName;
  final String? brand;
  final String? unit;
  final String category;
  final double quantity;
  final double? unitPrice;
  final double? totalPrice;
  final bool isFoodItem;
  final String? matchedFoodId;
  final double? estCalories;
  final double? estProtein;
  final double? estCarbs;
  final double? estFat;

  const GroceryItem({
    required this.id,
    required this.receiptId,
    this.rawText,
    this.normalizedName,
    this.brand,
    this.unit,
    required this.category,
    required this.quantity,
    this.unitPrice,
    this.totalPrice,
    required this.isFoodItem,
    this.matchedFoodId,
    this.estCalories,
    this.estProtein,
    this.estCarbs,
    this.estFat,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> j) => GroceryItem(
        id:             j['id'] as String,
        receiptId:      j['receipt_id'] as String,
        rawText:        j['raw_text'] as String?,
        normalizedName: j['normalized_name'] as String?,
        brand:          j['brand'] as String?,
        unit:           j['unit'] as String?,
        category:       j['category'] as String? ?? 'other',
        quantity:       (j['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice:      (j['unit_price'] as num?)?.toDouble(),
        totalPrice:     (j['total_price'] as num?)?.toDouble(),
        isFoodItem:     j['is_food_item'] as bool? ?? true,
        matchedFoodId:  j['matched_food_id'] as String?,
        estCalories:    (j['est_calories'] as num?)?.toDouble(),
        estProtein:     (j['est_protein'] as num?)?.toDouble(),
        estCarbs:       (j['est_carbs'] as num?)?.toDouble(),
        estFat:         (j['est_fat'] as num?)?.toDouble(),
      );
}

class GroceryCategorySpend {
  final String category;
  final double amount;
  final double percentage;
  final int itemCount;

  const GroceryCategorySpend({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.itemCount,
  });

  factory GroceryCategorySpend.fromJson(Map<String, dynamic> j) => GroceryCategorySpend(
        category:   j['category'] as String,
        amount:     (j['amount'] as num).toDouble(),
        percentage: (j['percentage'] as num).toDouble(),
        itemCount:  (j['item_count'] as num).toInt(),
      );
}

class GrocerySpending {
  final double totalSpend;
  final double foodSpend;
  final double nonFoodSpend;
  final List<GroceryCategorySpend> byCategory;

  const GrocerySpending({
    required this.totalSpend,
    required this.foodSpend,
    required this.nonFoodSpend,
    required this.byCategory,
  });

  factory GrocerySpending.fromJson(Map<String, dynamic> j) => GrocerySpending(
        totalSpend:    (j['total_spend'] as num).toDouble(),
        foodSpend:     (j['food_spend'] as num).toDouble(),
        nonFoodSpend:  (j['non_food_spend'] as num).toDouble(),
        byCategory:    (j['by_category'] as List)
            .map((e) => GroceryCategorySpend.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GroceryCategoryNutrition {
  final String category;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int itemCount;
  final double percentage;

  const GroceryCategoryNutrition({
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.itemCount,
    required this.percentage,
  });

  factory GroceryCategoryNutrition.fromJson(Map<String, dynamic> j) => GroceryCategoryNutrition(
        category:   j['category'] as String,
        calories:   (j['calories'] as num).toDouble(),
        protein:    (j['protein'] as num).toDouble(),
        carbs:      (j['carbs'] as num).toDouble(),
        fat:        (j['fat'] as num).toDouble(),
        itemCount:  (j['item_count'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
      );
}

class GroceryNutritionSpectrum {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final List<GroceryCategoryNutrition> byCategory;

  const GroceryNutritionSpectrum({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.byCategory,
  });

  factory GroceryNutritionSpectrum.fromJson(Map<String, dynamic> j) => GroceryNutritionSpectrum(
        totalCalories: (j['total_calories'] as num).toDouble(),
        totalProtein:  (j['total_protein'] as num).toDouble(),
        totalCarbs:    (j['total_carbs'] as num).toDouble(),
        totalFat:      (j['total_fat'] as num).toDouble(),
        byCategory:    (j['by_category'] as List)
            .map((e) => GroceryCategoryNutrition.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GroceryCategoryItemDetail {
  final String name;
  final double totalSpend;
  final double quantity;
  final int occurrences;
  final double? caloriesEst;

  const GroceryCategoryItemDetail({
    required this.name,
    required this.totalSpend,
    required this.quantity,
    required this.occurrences,
    this.caloriesEst,
  });

  factory GroceryCategoryItemDetail.fromJson(Map<String, dynamic> j) =>
      GroceryCategoryItemDetail(
        name:        j['name'] as String? ?? '',
        totalSpend:  (j['total_spend'] as num?)?.toDouble() ?? 0,
        quantity:    (j['quantity'] as num?)?.toDouble() ?? 0,
        occurrences: (j['occurrences'] as num?)?.toInt() ?? 0,
        caloriesEst: (j['calories_est'] as num?)?.toDouble(),
      );
}

class GroceryCategoryItems {
  final String category;
  final List<GroceryCategoryItemDetail> items;

  const GroceryCategoryItems({required this.category, required this.items});

  factory GroceryCategoryItems.fromJson(Map<String, dynamic> j) => GroceryCategoryItems(
        category: j['category'] as String,
        items: (j['items'] as List)
            .map((e) => GroceryCategoryItemDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
