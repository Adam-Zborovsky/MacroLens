class Preset {
  final String? id;
  final String userId;
  final String name;
  final double calories;
  final double proteinGrams;
  final double carbohydratesGrams;
  final double fatGrams;
  final double amount;

  Preset({
    this.id,
    required this.userId,
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbohydratesGrams,
    required this.fatGrams,
    this.amount = 1.0,
  });

  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      id: json['_id'],
      userId: json['userId'],
      name: json['name'],
      calories: (json['calories'] as num).toDouble(),
      proteinGrams: (json['proteinGrams'] as num).toDouble(),
      carbohydratesGrams: (json['carbohydratesGrams'] as num).toDouble(),
      fatGrams: (json['fatGrams'] as num).toDouble(),
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbohydratesGrams': carbohydratesGrams,
      'fatGrams': fatGrams,
      'amount': amount,
    };
  }
}
