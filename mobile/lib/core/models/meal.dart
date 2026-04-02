class Meal {
  final String? id;
  final String userId;
  final String? captureId;
  final String caseFileId;
  final String mealType;
  final DateTime loggedAt;
  final String overallConfidence;
  final List<DetectedItem> detectedItems;
  final NutritionProfile mealTotals;
  final VolumetricAnchors volumetricAnchors;
  final String entryMethod;
  final bool nutritionDataVerified;
  final String? notes;

  Meal({
    this.id,
    required this.userId,
    this.captureId,
    required this.caseFileId,
    required this.mealType,
    required this.loggedAt,
    required this.overallConfidence,
    required this.detectedItems,
    required this.mealTotals,
    required this.volumetricAnchors,
    required this.entryMethod,
    this.nutritionDataVerified = false,
    this.notes,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['_id'],
      userId: json['userId'],
      captureId: json['captureId'],
      caseFileId: json['caseFileId'],
      mealType: json['mealType'],
      loggedAt: DateTime.parse(json['loggedAt']),
      overallConfidence: json['overallConfidence'],
      detectedItems: (json['detectedItems'] as List)
          .map((i) => DetectedItem.fromJson(i))
          .toList(),
      mealTotals: NutritionProfile.fromJson(json['mealTotals']),
      volumetricAnchors: VolumetricAnchors.fromJson(json['volumetricAnchors']),
      entryMethod: json['entryMethod'],
      nutritionDataVerified: json['nutritionDataVerified'] ?? false,
      notes: json['notes'],
    );
  }
}

class DetectedItem {
  final String itemId;
  final String name;
  final String usdaSearchTerm;
  final String? usdaFoodId;
  final List<double> boundingBox2D;
  final double massGrams;
  final double? userAdjustedMassGrams;
  final String compositionConfidence;
  final String preparationState;
  final String cookingMethod;
  final NutritionProfile nutritionPer100g;
  final NutritionProfile nutritionTotal;
  final List<AlternativeCandidate> alternativeCandidates;
  final String verificationStatus;

  DetectedItem({
    required this.itemId,
    required this.name,
    required this.usdaSearchTerm,
    this.usdaFoodId,
    this.boundingBox2D = const [],
    required this.massGrams,
    this.userAdjustedMassGrams,
    required this.compositionConfidence,
    required this.preparationState,
    required this.cookingMethod,
    required this.nutritionPer100g,
    required this.nutritionTotal,
    this.alternativeCandidates = const [],
    required this.verificationStatus,
  });

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    return DetectedItem(
      itemId: json['itemId'],
      name: json['name'],
      usdaSearchTerm: json['usdaSearchTerm'],
      usdaFoodId: json['usdaFoodId'],
      boundingBox2D: (json['boundingBox2D'] as List?)?.cast<double>() ?? [],
      massGrams: (json['massGrams'] as num).toDouble(),
      userAdjustedMassGrams: (json['userAdjustedMassGrams'] as num?)?.toDouble(),
      compositionConfidence: json['compositionConfidence'],
      preparationState: json['preparationState'],
      cookingMethod: json['cookingMethod'],
      nutritionPer100g: NutritionProfile.fromJson(json['nutritionPer100g']),
      nutritionTotal: NutritionProfile.fromJson(json['nutritionTotal']),
      alternativeCandidates: (json['alternativeCandidates'] as List?)
              ?.map((i) => AlternativeCandidate.fromJson(i))
              .toList() ??
          [],
      verificationStatus: json['verificationStatus'],
    );
  }
}

class NutritionProfile {
  final double calories;
  final double proteinGrams;
  final double carbohydratesGrams;
  final double fatGrams;
  final double fiberGrams;

  NutritionProfile({
    required this.calories,
    required this.proteinGrams,
    required this.carbohydratesGrams,
    required this.fatGrams,
    this.fiberGrams = 0,
  });

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    return NutritionProfile(
      calories: (json['calories'] as num).toDouble(),
      proteinGrams: (json['proteinGrams'] as num).toDouble(),
      carbohydratesGrams: (json['carbohydratesGrams'] as num).toDouble(),
      fatGrams: (json['fatGrams'] as num).toDouble(),
      fiberGrams: (json['fiberGrams'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AlternativeCandidate {
  final String name;
  final String usdaSearchTerm;
  final NutritionProfile nutritionPer100g;

  AlternativeCandidate({
    required this.name,
    required this.usdaSearchTerm,
    required this.nutritionPer100g,
  });

  factory AlternativeCandidate.fromJson(Map<String, dynamic> json) {
    return AlternativeCandidate(
      name: json['name'],
      usdaSearchTerm: json['usdaSearchTerm'],
      nutritionPer100g: NutritionProfile.fromJson(json['nutritionPer100g']),
    );
  }
}

class VolumetricAnchors {
  final double? estimatedPlateDiameterCm;
  final String? anchorObjectDetected;
  final String calibrationMethod;

  VolumetricAnchors({
    this.estimatedPlateDiameterCm,
    this.anchorObjectDetected,
    required this.calibrationMethod,
  });

  factory VolumetricAnchors.fromJson(Map<String, dynamic> json) {
    return VolumetricAnchors(
      estimatedPlateDiameterCm:
          (json['estimatedPlateDiameterCm'] as num?)?.toDouble(),
      anchorObjectDetected: json['anchorObjectDetected'],
      calibrationMethod: json['calibrationMethod'],
    );
  }
}
