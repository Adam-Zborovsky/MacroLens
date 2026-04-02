import 'package:flutter/material.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import '../../core/models/case_file.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import 'notched_haptic_slider.dart';

class DetectiveOverlay extends StatefulWidget {
  final Map<String, dynamic> caseFileJson;
  final ApiService apiService;

  const DetectiveOverlay({
    super.key,
    required this.caseFileJson,
    required this.apiService,
  });

  @override
  State<DetectiveOverlay> createState() => _DetectiveOverlayState();
}

class _DetectiveOverlayState extends State<DetectiveOverlay>
    with TickerProviderStateMixin {
  late CaseFile _caseFile;
  int _selectedItemIndex = 0;
  bool _isSaving = false;

  // Odometer animation controllers — one per macro
  late AnimationController _caloriesAnim;
  late AnimationController _proteinAnim;
  late AnimationController _carbsAnim;
  late AnimationController _fatAnim;

  NutritionProfile? _prevTotals;

  @override
  void initState() {
    super.initState();
    _caseFile = CaseFile.fromJson(widget.caseFileJson);
    _initOdometerControllers();
  }

  void _initOdometerControllers() {
    _caloriesAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _proteinAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _carbsAnim    = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fatAnim      = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _caloriesAnim.dispose();
    _proteinAnim.dispose();
    _carbsAnim.dispose();
    _fatAnim.dispose();
    super.dispose();
  }

  DetectedItem get _selectedItem => _caseFile.detectedItems[_selectedItemIndex];

  void _onMassChanged(double newMassGrams) {
    _prevTotals = _caseFile.mealTotals;

    final updatedItem = _selectedItem.copyWith(
      userAdjustedMassGrams: newMassGrams,
      nutritionTotal: NutritionProfile.fromPer100gAndMass(_selectedItem.nutritionPer100g, newMassGrams),
      verificationStatus: VerificationStatus.userCorrected,
    );

    final updatedItems = List<DetectedItem>.from(_caseFile.detectedItems)..[_selectedItemIndex] = updatedItem;
    final newTotals = _recomputeTotals(updatedItems);

    setState(() {
      _caseFile = _caseFile.copyWith(detectedItems: updatedItems, mealTotals: newTotals);
    });

    // Trigger odometer animations for changed values
    _caloriesAnim.forward(from: 0);
    _proteinAnim.forward(from: 0);
    _carbsAnim.forward(from: 0);
    _fatAnim.forward(from: 0);
  }

  NutritionProfile _recomputeTotals(List<DetectedItem> items) {
    double cal = 0, prot = 0, carbs = 0, fat = 0, fiber = 0;
    for (final item in items) {
      cal   += item.effectiveNutritionTotal.calories;
      prot  += item.effectiveNutritionTotal.proteinGrams;
      carbs += item.effectiveNutritionTotal.carbohydratesGrams;
      fat   += item.effectiveNutritionTotal.fatGrams;
      fiber += item.effectiveNutritionTotal.fiberGrams;
    }
    return NutritionProfile(
      calories: cal, proteinGrams: prot,
      carbohydratesGrams: carbs, fatGrams: fat, fiberGrams: fiber,
    );
  }

  Future<void> _confirmLog() async {
    setState(() => _isSaving = true);
    await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
    try {
      final corrections = _caseFile.detectedItems
          .where((i) => i.userAdjustedMassGrams != null || i.verificationStatus != VerificationStatus.aiVerified)
          .map((i) => {
                'itemId': i.itemId,
                if (i.userAdjustedMassGrams != null) 'userAdjustedMassGrams': i.userAdjustedMassGrams,
                'verificationStatus': _verificationStatusKey(i.verificationStatus),
              })
          .toList();

      if (corrections.isNotEmpty) {
        await widget.apiService.patchCaseFile(_caseFile.id, {'itemCorrections': corrections});
      }

      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError)),
          backgroundColor: MLColors.bgCard,
        ));
      }
    }
  }

  String _verificationStatusKey(VerificationStatus s) => switch (s) {
        VerificationStatus.userConfirmed => 'user_confirmed',
        VerificationStatus.userCorrected => 'user_corrected',
        VerificationStatus.customEntry   => 'custom_entry',
        _                                => 'user_confirmed',
      };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: MLColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: MLColors.border)),
        ),
        child: Column(
          children: [
            _DragHandle(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: MLSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(caseFile: _caseFile),
                    const SizedBox(height: MLSpacing.md),
                    _MacroTotalsBar(
                      totals: _caseFile.mealTotals,
                      prevTotals: _prevTotals,
                      caloriesAnim: _caloriesAnim,
                      proteinAnim:  _proteinAnim,
                      carbsAnim:    _carbsAnim,
                      fatAnim:      _fatAnim,
                    ),
                    const SizedBox(height: MLSpacing.lg),
                    _ItemSelector(
                      items: _caseFile.detectedItems,
                      selectedIndex: _selectedItemIndex,
                      onSelect: (i) => setState(() => _selectedItemIndex = i),
                    ),
                    const SizedBox(height: MLSpacing.lg),
                    _ItemDetailPanel(
                      item: _selectedItem,
                      onMassChanged: _onMassChanged,
                      onAlternativeSelected: (alt) {
                        // Replace item with selected alternative candidate
                        final updated = _selectedItem.copyWith(
                          name: alt.name,
                          usdaSearchTerm: alt.usdaSearchTerm,
                          nutritionPer100g: alt.nutritionPer100g,
                          nutritionTotal: NutritionProfile.fromPer100gAndMass(
                              alt.nutritionPer100g, _selectedItem.effectiveMassGrams),
                          verificationStatus: VerificationStatus.userCorrected,
                        );
                        final updatedItems = List<DetectedItem>.from(_caseFile.detectedItems)
                          ..[_selectedItemIndex] = updated;
                        setState(() {
                          _caseFile = _caseFile.copyWith(
                            detectedItems: updatedItems,
                            mealTotals: _recomputeTotals(updatedItems),
                          );
                        });
                        FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
                      },
                    ),
                    const SizedBox(height: MLSpacing.xxl),
                  ],
                ),
              ),
            ),
            _ConfirmButton(isSaving: _isSaving, onConfirm: _confirmLog),
            SizedBox(height: MediaQuery.of(context).padding.bottom + MLSpacing.sm),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-components ───────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: MLSpacing.md),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MLColors.border,
              borderRadius: BorderRadius.circular(MLRadius.pill),
            ),
          ),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  final CaseFile caseFile;
  const _SheetHeader({required this.caseFile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DETECTIVE ANALYSIS', style: MLTextStyles.labelCaps),
              const SizedBox(height: 4),
              Text(
                'Case File ${caseFile.caseFileId.substring(0, 8).toUpperCase()}',
                style: MLTextStyles.headingSmall,
              ),
            ],
          ),
        ),
        _ConfidenceBadge(confidence: caseFile.overallConfidence),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final OverallConfidence confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (confidence) {
      OverallConfidence.high   => ('HIGH', MLColors.statusVerified, MLColors.confidenceHigh),
      OverallConfidence.medium => ('MED',  MLColors.statusWarning,  MLColors.confidenceMedium),
      OverallConfidence.low    => ('LOW',  MLColors.statusError,    MLColors.confidenceLow),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MLRadius.pill),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: MLTextStyles.dataSmall.copyWith(color: fg, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _MacroTotalsBar extends StatelessWidget {
  final NutritionProfile totals;
  final NutritionProfile? prevTotals;
  final AnimationController caloriesAnim;
  final AnimationController proteinAnim;
  final AnimationController carbsAnim;
  final AnimationController fatAnim;

  const _MacroTotalsBar({
    required this.totals,
    required this.prevTotals,
    required this.caloriesAnim,
    required this.proteinAnim,
    required this.carbsAnim,
    required this.fatAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MLSpacing.md),
      decoration: BoxDecoration(
        color: MLColors.surfaceGlass,
        borderRadius: BorderRadius.circular(MLRadius.md),
        border: Border.all(color: MLColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _OdometerValue(label: 'KCAL',  value: totals.calories,           color: MLColors.textPrimary, controller: caloriesAnim, decimals: 0),
          _Divider(),
          _OdometerValue(label: 'PROT',  value: totals.proteinGrams,       color: MLColors.macroProtein, controller: proteinAnim, unit: 'g'),
          _Divider(),
          _OdometerValue(label: 'CARBS', value: totals.carbohydratesGrams, color: MLColors.macroCarbs,   controller: carbsAnim,   unit: 'g'),
          _Divider(),
          _OdometerValue(label: 'FAT',   value: totals.fatGrams,           color: MLColors.macroFat,     controller: fatAnim,     unit: 'g'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: MLColors.border);
}

/// Odometer-style rolling number display.
class _OdometerValue extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final AnimationController controller;
  final String unit;
  final int decimals;

  const _OdometerValue({
    required this.label,
    required this.value,
    required this.color,
    required this.controller,
    this.unit = '',
    this.decimals = 1,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = decimals == 0 ? value.round().toString() : value.toStringAsFixed(decimals);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Transform.translate(
          offset: Offset(0, -4 * t * (1 - t) * 4), // subtle bounce on change
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: MLTextStyles.dataMedium.copyWith(color: color),
                  children: [
                    TextSpan(text: formatted),
                    if (unit.isNotEmpty) TextSpan(text: unit, style: MLTextStyles.dataSmall.copyWith(color: color)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: MLTextStyles.labelCaps),
            ],
          ),
        );
      },
    );
  }
}

class _ItemSelector extends StatelessWidget {
  final List<DetectedItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ItemSelector({required this.items, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DETECTED ITEMS', style: MLTextStyles.labelCaps),
        const SizedBox(height: MLSpacing.sm),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: MLSpacing.sm),
            itemBuilder: (_, i) {
              final item = items[i];
              final isSelected = i == selectedIndex;
              final (_, confidenceColor, _) = _confidenceColors(item.compositionConfidence);
              return GestureDetector(
                onTap: () {
                  FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
                  onSelect(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: MLSpacing.md, vertical: MLSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? MLColors.accentCyanGlow : MLColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(MLRadius.md),
                    border: Border.all(color: isSelected ? MLColors.accentCyan : MLColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: confidenceColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(item.name,
                          style: MLTextStyles.bodyRegular.copyWith(
                            color: isSelected ? MLColors.accentCyan : MLColors.textPrimary,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  (Color, Color, Color) _confidenceColors(CompositionConfidence c) => switch (c) {
        CompositionConfidence.high   => (MLColors.confidenceHigh, MLColors.statusVerified, MLColors.confidenceHigh),
        CompositionConfidence.medium => (MLColors.confidenceMedium, MLColors.statusWarning, MLColors.confidenceMedium),
        CompositionConfidence.low    => (MLColors.confidenceLow, MLColors.statusError, MLColors.confidenceLow),
      };
}

class _ItemDetailPanel extends StatelessWidget {
  final DetectedItem item;
  final ValueChanged<double> onMassChanged;
  final ValueChanged<AlternativeCandidate> onAlternativeSelected;

  const _ItemDetailPanel({
    required this.item,
    required this.onMassChanged,
    required this.onAlternativeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name + verification badge
        Row(
          children: [
            Expanded(
              child: Text(item.name, style: MLTextStyles.headingMedium),
            ),
            if (item.verificationStatus == VerificationStatus.userConfirmed ||
                item.verificationStatus == VerificationStatus.userCorrected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MLColors.confidenceHigh,
                  borderRadius: BorderRadius.circular(MLRadius.pill),
                ),
                child: Text('VERIFIED', style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusVerified)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(item.usdaSearchTerm, style: MLTextStyles.bodyMuted.copyWith(fontSize: 12)),
        const SizedBox(height: MLSpacing.lg),

        // Notched Haptic Slider
        Text('MASS ADJUSTMENT', style: MLTextStyles.labelCaps),
        const SizedBox(height: MLSpacing.sm),
        NotchedHapticSlider(
          value: item.effectiveMassGrams,
          min: 5,
          max: 800,
          notchInterval: 5,
          onChanged: onMassChanged,
        ),
        const SizedBox(height: MLSpacing.lg),

        // Per-100g breakdown
        _NutritionBreakdown(per100g: item.nutritionPer100g, total: item.effectiveNutritionTotal),
        const SizedBox(height: MLSpacing.lg),

        // Alternative candidates
        if (item.alternativeCandidates.isNotEmpty) ...[
          Text('AI CONSIDERED ALTERNATIVES', style: MLTextStyles.labelCaps),
          const SizedBox(height: MLSpacing.sm),
          ...item.alternativeCandidates.map((alt) => _AlternativeRow(
                alt: alt,
                onTap: () => onAlternativeSelected(alt),
              )),
        ],
      ],
    );
  }
}

class _NutritionBreakdown extends StatelessWidget {
  final NutritionProfile per100g;
  final NutritionProfile total;
  const _NutritionBreakdown({required this.per100g, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MLSpacing.md),
      decoration: BoxDecoration(
        color: MLColors.bgCard,
        borderRadius: BorderRadius.circular(MLRadius.md),
        border: Border.all(color: MLColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text('NUTRIENT', style: MLTextStyles.labelCaps)),
            Text('PER 100g', style: MLTextStyles.labelCaps),
            const SizedBox(width: MLSpacing.xl),
            Text('TOTAL',    style: MLTextStyles.labelCaps),
          ]),
          const SizedBox(height: MLSpacing.sm),
          Divider(color: MLColors.border, height: 1),
          const SizedBox(height: MLSpacing.sm),
          _NutrientRow('CALORIES', per100g.calories, total.calories, MLColors.textPrimary, unit: 'kcal'),
          _NutrientRow('PROTEIN',  per100g.proteinGrams,       total.proteinGrams,       MLColors.macroProtein),
          _NutrientRow('CARBS',    per100g.carbohydratesGrams, total.carbohydratesGrams, MLColors.macroCarbs),
          _NutrientRow('FAT',      per100g.fatGrams,           total.fatGrams,           MLColors.macroFat),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final double per100g;
  final double total;
  final Color color;
  final String unit;

  const _NutrientRow(this.label, this.per100g, this.total, this.color, {this.unit = 'g'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: color, margin: const EdgeInsets.only(right: 8)),
          Expanded(child: Text(label, style: MLTextStyles.labelCaps)),
          Text(
            '${per100g.toStringAsFixed(1)} $unit',
            style: MLTextStyles.dataSmall.copyWith(color: MLColors.textMuted),
          ),
          const SizedBox(width: MLSpacing.xl),
          Text(
            '${total.toStringAsFixed(1)} $unit',
            style: MLTextStyles.dataSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  final AlternativeCandidate alt;
  final VoidCallback onTap;
  const _AlternativeRow({required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: MLSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: MLSpacing.md, vertical: MLSpacing.sm),
        decoration: BoxDecoration(
          color: MLColors.surfaceGlass,
          borderRadius: BorderRadius.circular(MLRadius.md),
          border: Border.all(color: MLColors.border),
        ),
        child: Row(
          children: [
            Expanded(child: Text(alt.name, style: MLTextStyles.bodyRegular.copyWith(fontSize: 13))),
            Text(
              '${alt.nutritionPer100g.calories.round()} kcal/100g',
              style: MLTextStyles.dataSmall,
            ),
            const SizedBox(width: MLSpacing.sm),
            const Icon(Icons.swap_horiz, color: MLColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onConfirm;
  const _ConfirmButton({required this.isSaving, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MLSpacing.md, vertical: MLSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isSaving ? null : onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: MLColors.accentCyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MLRadius.md)),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  'CONFIRM & LOG CASE FILE',
                  style: MLTextStyles.labelCaps.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
        ),
      ),
    );
  }
}
