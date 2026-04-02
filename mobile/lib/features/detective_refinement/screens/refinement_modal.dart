import 'package:flutter/material.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/features/detective_refinement/widgets/notched_haptic_slider.dart';
import 'package:google_fonts/google_fonts.dart';

class RefinementModal extends StatefulWidget {
  final DetectedItem item;
  final List<AlternativeCandidate> alternatives;
  final Function(DetectedItem updatedItem) onSave;

  const RefinementModal({
    super.key,
    required this.item,
    required this.alternatives,
    required this.onSave,
  });

  static void show(BuildContext context, {
    required DetectedItem item,
    required List<AlternativeCandidate> alternatives,
    required Function(DetectedItem) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RefinementModal(
        item: item,
        alternatives: alternatives,
        onSave: onSave,
      ),
    );
  }

  @override
  State<RefinementModal> createState() => _RefinementModalState();
}

class _RefinementModalState extends State<RefinementModal> {
  late double _currentMass;
  late DetectedItem _activeItem;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.item;
    _currentMass = widget.item.massGrams;
  }

  // Real-time macro calculation based on current mass
  double _calculateMacro(double per100g) {
    return (per100g * _currentMass) / 100;
  }

  void _showSwapOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("SELECT_ALTERNATIVE_SPECIMEN", style: AppTheme.darkTheme.textTheme.labelMedium),
              const SizedBox(height: 16),
              ...widget.alternatives.map((alt) => ListTile(
                title: Text(alt.name.toUpperCase(), style: GoogleFonts.firaCode(color: Colors.white, fontSize: 14)),
                subtitle: Text("${alt.nutritionPer100g.calories.toInt()} KCAL/100G", style: GoogleFonts.firaCode(fontSize: 10)),
                onTap: () {
                  setState(() {
                    _activeItem = DetectedItem(
                      itemId: _activeItem.itemId,
                      name: alt.name,
                      usdaSearchTerm: alt.usdaSearchTerm,
                      massGrams: _currentMass,
                      compositionConfidence: "high", // User selected, so high
                      preparationState: _activeItem.preparationState,
                      cookingMethod: _activeItem.cookingMethod, 
                      nutritionPer100g: alt.nutritionPer100g,

                      nutritionTotal: alt.nutritionPer100g, // Will be recalculated
                      verificationStatus: "user_corrected",
                    );
                  });
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = _activeItem.nutritionPer100g;
    
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeItem.name.toUpperCase(),
                      style: AppTheme.darkTheme.textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    _buildConfidenceBadge(),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.secondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text("CALIBRATE_MASS", style: AppTheme.darkTheme.textTheme.labelMedium),
          const SizedBox(height: 16),
          NotchedHapticSlider(
            initialValue: _currentMass,
            onChanged: (value) {
              setState(() {
                _currentMass = value;
              });
            },
          ),
          const SizedBox(height: 32),

          // Macro Readout Terminal (Now Reactive)
          _buildMacroReadout(nutrition),
          const SizedBox(height: 32),

          // Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _showSwapOptions,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text("SWAP", style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_activeItem); // In a real app, this would update the Case File
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("VERIFY_&_LOG"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    final color = _activeItem.compositionConfidence == 'high' ? AppTheme.primary : Colors.amber;
    final status = _activeItem.verificationStatus == 'user_corrected' ? 'USER_VERIFIED' : 'GUESSED: ${_activeItem.compositionConfidence.toUpperCase()}_CONFIDENCE';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: GoogleFonts.firaCode(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMacroReadout(NutritionProfile p) {
    final protein = _calculateMacro(p.proteinGrams);
    final carbs = _calculateMacro(p.carbohydratesGrams);
    final fat = _calculateMacro(p.fatGrams);
    final cals = _calculateMacro(p.calories);
    final totalMacros = protein + carbs + fat;

    String getPct(double val) => totalMacros > 0 ? "${((val / totalMacros) * 100).toStringAsFixed(0)}%" : "0%";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _MacroRow(label: "PROTEIN", value: "${protein.toStringAsFixed(1)}G", percentage: getPct(protein)),
          const Divider(color: AppTheme.outlineVariant, height: 24, thickness: 0.5),
          _MacroRow(label: "CARBS", value: "${carbs.toStringAsFixed(1)}G", percentage: getPct(carbs)),
          const Divider(color: AppTheme.outlineVariant, height: 24, thickness: 0.5),
          _MacroRow(label: "FAT", value: "${fat.toStringAsFixed(1)}G", percentage: getPct(fat)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ESTIMATED_ENERGY", style: AppTheme.darkTheme.textTheme.bodySmall),
              Text(
                "${cals.toInt()} KCAL",
                style: GoogleFonts.firaCode(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.ghostWhite),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final String percentage;
  const _MacroRow({required this.label, required this.value, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.darkTheme.textTheme.labelMedium),
        Row(
          children: [
            Text(value, style: GoogleFonts.firaCode(color: AppTheme.ghostWhite, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text("($percentage)", style: AppTheme.darkTheme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
