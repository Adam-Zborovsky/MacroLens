import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/features/detective_refinement/screens/refinement_modal.dart';

class MealReviewScreen extends StatefulWidget {
  final Meal initialMeal;
  final String captureId;

  const MealReviewScreen({
    super.key,
    required this.initialMeal,
    required this.captureId,
  });

  @override
  State<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends State<MealReviewScreen> {
  late Meal _meal;
  bool _isSaving = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _meal = widget.initialMeal;
  }

  void _recalculateTotals() {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var item in _meal.detectedItems) {
      calories += (item.nutritionPer100g.calories * item.massGrams) / 100;
      protein += (item.nutritionPer100g.proteinGrams * item.massGrams) / 100;
      carbs += (item.nutritionPer100g.carbohydratesGrams * item.massGrams) / 100;
      fat += (item.nutritionPer100g.fatGrams * item.massGrams) / 100;
    }

    setState(() {
      _meal = Meal(
        userId: _meal.userId,
        captureId: _meal.captureId,
        mealType: _meal.mealType,
        overallConfidence: _meal.overallConfidence,
        detectedItems: _meal.detectedItems,
        mealTotals: NutritionProfile(
          calories: calories,
          proteinGrams: protein,
          carbohydratesGrams: carbs,
          fatGrams: fat,
          fiberGrams: 0,
        ),
        volumetricAnchors: _meal.volumetricAnchors,
        entryMethod: _meal.entryMethod,
      );
    });
  }

  void _editItem(int index) {
    RefinementModal.show(
      context,
      item: _meal.detectedItems[index],
      alternatives: _meal.detectedItems[index].alternativeCandidates,
      onSave: (updatedItem) {
        setState(() {
          _meal.detectedItems[index] = updatedItem;
        });
        _recalculateTotals();
      },
      onDelete: () {
        setState(() {
          _meal.detectedItems.removeAt(index);
        });
        _recalculateTotals();
      },
    );
  }

  Future<void> _saveMeal() async {
    setState(() => _isSaving = true);
    try {
      final mealData = _meal.toJson();
      mealData['captureId'] = widget.captureId;
      await _apiService.confirmMeal(mealData);
      
      if (mounted) {
        Navigator.pop(context); // Back to camera
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("MEAL_LOGGED_SUCCESSFULLY", style: GoogleFonts.firaCode(fontSize: 10)),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("SAVE_ERROR: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("CASE_FILE: ${_meal.mealType.toUpperCase()}", style: AppTheme.darkTheme.textTheme.labelLarge),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _meal.detectedItems.length,
              itemBuilder: (context, index) {
                final item = _meal.detectedItems[index];
                return _buildItemTile(item, index);
              },
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MacroStat(label: "CAL", value: _meal.mealTotals.calories.toInt().toString()),
              _MacroStat(label: "PRO", value: "${_meal.mealTotals.proteinGrams.toStringAsFixed(1)}g"),
              _MacroStat(label: "CARB", value: "${_meal.mealTotals.carbohydratesGrams.toStringAsFixed(1)}g"),
              _MacroStat(label: "FAT", value: "${_meal.mealTotals.fatGrams.toStringAsFixed(1)}g"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(DetectedItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.primary.withOpacity(0.5), width: 2)),
        color: AppTheme.surfaceContainerLow.withOpacity(0.5),
      ),
      child: ListTile(
        onTap: () => _editItem(index),
        title: Text(item.name.toUpperCase(), style: GoogleFonts.firaCode(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text("${item.massGrams.toInt()}G | ${((item.nutritionPer100g.calories * item.massGrams) / 100).toInt()} KCAL", style: GoogleFonts.firaCode(fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _meal.detectedItems.removeAt(index);
            });
            _recalculateTotals();
          },
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveMeal,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            backgroundColor: AppTheme.primary,
          ),
          child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text("LOG_SPECIMEN_TO_HISTORY"),
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  const _MacroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.firaCode(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
