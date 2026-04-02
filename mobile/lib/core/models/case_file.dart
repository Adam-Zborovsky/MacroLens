/// MacroLens domain models — mirrors the API output schema.
/// Uses domain language from context.md throughout.

class NutritionProfile {
  final double calories;
  final double proteinGrams;
  final double carbohydratesGrams;
  final double fatGrams;
  final double fiberGrams;

  const NutritionProfile({
    required this.calories,
    required this.proteinGrams,
    required this.carbohydratesGrams,
    required this.fatGrams,
    this.fiberGrams = 0,
  });

  factory NutritionProfile.fromJson(Map<String, dynamic> j) => NutritionProfile(
        calories:           (j['calories'] as num).toDouble(),
        proteinGrams:       (j['proteinGrams'] as num).toDouble(),
        carbohydratesGrams: (j['carbohydratesGrams'] as num).toDouble(),
        fatGrams:           (j['fatGrams'] as num).toDouble(),
        fiberGrams:         (j['fiberGrams'] as num? ?? 0).toDouble(),
      );

  NutritionProfile copyWith({
    double? calories,
    double? proteinGrams,
    double? carbohydratesGrams,
    double? fatGrams,
    double? fiberGrams,
  }) =>
      NutritionProfile(
        calories:           calories           ?? this.calories,
        proteinGrams:       proteinGrams       ?? this.proteinGrams,
        carbohydratesGrams: carbohydratesGrams ?? this.carbohydratesGrams,
        fatGrams:           fatGrams           ?? this.fatGrams,
        fiberGrams:         fiberGrams         ?? this.fiberGrams,
      );

  /// Recompute total from per-100g values and effective mass.
  static NutritionProfile fromPer100gAndMass(NutritionProfile per100g, double massGrams) {
    final m = massGrams / 100.0;
    return NutritionProfile(
      calories:           per100g.calories * m,
      proteinGrams:       per100g.proteinGrams * m,
      carbohydratesGrams: per100g.carbohydratesGrams * m,
      fatGrams:           per100g.fatGrams * m,
      fiberGrams:         per100g.fiberGrams * m,
    );
  }
}

class AlternativeCandidate {
  final String name;
  final String usdaSearchTerm;
  final NutritionProfile nutritionPer100g;

  const AlternativeCandidate({
    required this.name,
    required this.usdaSearchTerm,
    required this.nutritionPer100g,
  });

  factory AlternativeCandidate.fromJson(Map<String, dynamic> j) => AlternativeCandidate(
        name:            j['name'] as String,
        usdaSearchTerm:  j['usdaSearchTerm'] as String,
        nutritionPer100g: NutritionProfile.fromJson(j['nutritionPer100g'] as Map<String, dynamic>),
      );
}

enum CompositionConfidence { high, medium, low }
enum VerificationStatus { aiVerified, userConfirmed, userCorrected, customEntry }
enum PreparationState { cooked, raw, processed, unknown }

class DetectedItem {
  final String itemId;
  final String name;
  final String usdaSearchTerm;
  final String? usdaFoodId;
  final double massGrams;
  final double? userAdjustedMassGrams;
  final CompositionConfidence compositionConfidence;
  final PreparationState preparationState;
  final NutritionProfile nutritionPer100g;
  final NutritionProfile nutritionTotal;
  final List<AlternativeCandidate> alternativeCandidates;
  final VerificationStatus verificationStatus;

  const DetectedItem({
    required this.itemId,
    required this.name,
    required this.usdaSearchTerm,
    this.usdaFoodId,
    required this.massGrams,
    this.userAdjustedMassGrams,
    required this.compositionConfidence,
    this.preparationState = PreparationState.unknown,
    required this.nutritionPer100g,
    required this.nutritionTotal,
    this.alternativeCandidates = const [],
    this.verificationStatus = VerificationStatus.aiVerified,
  });

  double get effectiveMassGrams => userAdjustedMassGrams ?? massGrams;

  NutritionProfile get effectiveNutritionTotal =>
      NutritionProfile.fromPer100gAndMass(nutritionPer100g, effectiveMassGrams);

  factory DetectedItem.fromJson(Map<String, dynamic> j) => DetectedItem(
        itemId:         j['itemId'] as String,
        name:           j['name'] as String,
        usdaSearchTerm: j['usdaSearchTerm'] as String,
        usdaFoodId:     j['usdaFoodId'] as String?,
        massGrams:      (j['massGrams'] as num).toDouble(),
        userAdjustedMassGrams: (j['userAdjustedMassGrams'] as num?)?.toDouble(),
        compositionConfidence: _parseConfidence(j['compositionConfidence'] as String),
        preparationState:      _parsePreparation(j['preparationState'] as String? ?? 'unknown'),
        nutritionPer100g: NutritionProfile.fromJson(j['nutritionPer100g'] as Map<String, dynamic>),
        nutritionTotal:   NutritionProfile.fromJson(j['nutritionTotal'] as Map<String, dynamic>),
        alternativeCandidates: (j['alternativeCandidates'] as List? ?? [])
            .map((e) => AlternativeCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        verificationStatus: _parseVerification(j['verificationStatus'] as String? ?? 'ai_verified'),
      );

  DetectedItem copyWith({
    String? name,
    String? usdaSearchTerm,
    String? usdaFoodId,
    double? massGrams,
    double? userAdjustedMassGrams,
    NutritionProfile? nutritionPer100g,
    NutritionProfile? nutritionTotal,
    VerificationStatus? verificationStatus,
  }) =>
      DetectedItem(
        itemId:               itemId,
        name:                 name               ?? this.name,
        usdaSearchTerm:       usdaSearchTerm     ?? this.usdaSearchTerm,
        usdaFoodId:           usdaFoodId         ?? this.usdaFoodId,
        massGrams:            massGrams          ?? this.massGrams,
        userAdjustedMassGrams: userAdjustedMassGrams ?? this.userAdjustedMassGrams,
        compositionConfidence: compositionConfidence,
        preparationState:      preparationState,
        nutritionPer100g:      nutritionPer100g  ?? this.nutritionPer100g,
        nutritionTotal:        nutritionTotal    ?? this.nutritionTotal,
        alternativeCandidates: alternativeCandidates,
        verificationStatus:    verificationStatus ?? this.verificationStatus,
      );

  static CompositionConfidence _parseConfidence(String s) =>
      switch (s) { 'high' => CompositionConfidence.high, 'medium' => CompositionConfidence.medium, _ => CompositionConfidence.low };

  static PreparationState _parsePreparation(String s) =>
      switch (s) { 'cooked' => PreparationState.cooked, 'raw' => PreparationState.raw, 'processed' => PreparationState.processed, _ => PreparationState.unknown };

  static VerificationStatus _parseVerification(String s) =>
      switch (s) { 'user_confirmed' => VerificationStatus.userConfirmed, 'user_corrected' => VerificationStatus.userCorrected, 'custom_entry' => VerificationStatus.customEntry, _ => VerificationStatus.aiVerified };
}

enum OverallConfidence { high, medium, low }
enum MealType { breakfast, lunch, dinner, snack, unknown }

class CaseFile {
  final String id;
  final String caseFileId;
  final String userId;
  final MealType mealType;
  final DateTime loggedAt;
  final OverallConfidence overallConfidence;
  final List<DetectedItem> detectedItems;
  final NutritionProfile mealTotals;
  final bool nutritionDataVerified;
  final String? notes;

  const CaseFile({
    required this.id,
    required this.caseFileId,
    required this.userId,
    required this.mealType,
    required this.loggedAt,
    required this.overallConfidence,
    required this.detectedItems,
    required this.mealTotals,
    this.nutritionDataVerified = false,
    this.notes,
  });

  bool get isVerified => nutritionDataVerified && overallConfidence == OverallConfidence.high;

  factory CaseFile.fromJson(Map<String, dynamic> j) => CaseFile(
        id:           j['_id'] as String,
        caseFileId:   j['caseFileId'] as String,
        userId:       j['userId'] as String,
        mealType:     _parseMealType(j['mealType'] as String? ?? 'unknown'),
        loggedAt:     DateTime.parse(j['loggedAt'] as String),
        overallConfidence: _parseConfidence(j['overallConfidence'] as String),
        detectedItems: (j['detectedItems'] as List)
            .map((e) => DetectedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        mealTotals:          NutritionProfile.fromJson(j['mealTotals'] as Map<String, dynamic>),
        nutritionDataVerified: j['nutritionDataVerified'] as bool? ?? false,
        notes:               j['notes'] as String?,
      );

  CaseFile copyWith({List<DetectedItem>? detectedItems, NutritionProfile? mealTotals, String? notes}) =>
      CaseFile(
        id: id, caseFileId: caseFileId, userId: userId,
        mealType: mealType, loggedAt: loggedAt,
        overallConfidence: overallConfidence,
        detectedItems: detectedItems ?? this.detectedItems,
        mealTotals:    mealTotals    ?? this.mealTotals,
        nutritionDataVerified: nutritionDataVerified,
        notes: notes ?? this.notes,
      );

  /// Roundtrip to JSON — needed when passing to DetectiveOverlay from Meal History.
  Map<String, dynamic> toJson() => {
        '_id':          id,
        'caseFileId':   caseFileId,
        'userId':       userId,
        'mealType':     mealType.name,
        'loggedAt':     loggedAt.toIso8601String(),
        'overallConfidence': overallConfidence.name,
        'detectedItems': detectedItems.map((item) => {
          'itemId':         item.itemId,
          'name':           item.name,
          'usdaSearchTerm': item.usdaSearchTerm,
          'usdaFoodId':     item.usdaFoodId,
          'massGrams':      item.massGrams,
          'userAdjustedMassGrams': item.userAdjustedMassGrams,
          'compositionConfidence': item.compositionConfidence.name,
          'preparationState':      item.preparationState.name,
          'cookingMethod':         'unknown',
          'nutritionPer100g': {
            'calories': item.nutritionPer100g.calories,
            'proteinGrams': item.nutritionPer100g.proteinGrams,
            'carbohydratesGrams': item.nutritionPer100g.carbohydratesGrams,
            'fatGrams': item.nutritionPer100g.fatGrams,
            'fiberGrams': item.nutritionPer100g.fiberGrams,
          },
          'nutritionTotal': {
            'calories': item.nutritionTotal.calories,
            'proteinGrams': item.nutritionTotal.proteinGrams,
            'carbohydratesGrams': item.nutritionTotal.carbohydratesGrams,
            'fatGrams': item.nutritionTotal.fatGrams,
            'fiberGrams': item.nutritionTotal.fiberGrams,
          },
          'alternativeCandidates': item.alternativeCandidates.map((a) => {
            'name': a.name,
            'usdaSearchTerm': a.usdaSearchTerm,
            'nutritionPer100g': {
              'calories': a.nutritionPer100g.calories,
              'proteinGrams': a.nutritionPer100g.proteinGrams,
              'carbohydratesGrams': a.nutritionPer100g.carbohydratesGrams,
              'fatGrams': a.nutritionPer100g.fatGrams,
              'fiberGrams': a.nutritionPer100g.fiberGrams,
            },
          }).toList(),
          'verificationStatus': item.verificationStatus.name,
        }).toList(),
        'mealTotals': {
          'calories': mealTotals.calories,
          'proteinGrams': mealTotals.proteinGrams,
          'carbohydratesGrams': mealTotals.carbohydratesGrams,
          'fatGrams': mealTotals.fatGrams,
          'fiberGrams': mealTotals.fiberGrams,
        },
        'nutritionDataVerified': nutritionDataVerified,
        'notes': notes,
      };

  static OverallConfidence _parseConfidence(String s) =>
      switch (s) { 'high' => OverallConfidence.high, 'medium' => OverallConfidence.medium, _ => OverallConfidence.low };

  static MealType _parseMealType(String s) =>
      switch (s) { 'breakfast' => MealType.breakfast, 'lunch' => MealType.lunch, 'dinner' => MealType.dinner, 'snack' => MealType.snack, _ => MealType.unknown };
}
