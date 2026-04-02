import 'package:flutter/material.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../core/models/case_file.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  const DashboardScreen({super.key, required this.apiService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _dailyTotals;
  List<CaseFile> _todayCaseFiles = [];
  bool _loading = true;
  String? _error;
  String? _macroFilter; // null = all; 'protein'|'carbs'|'fat'

  // Odometer animation
  late AnimationController _ringAnimController;
  late Animation<double> _ringAnim;

  // Stub targets — in production sourced from User.dailyTargets
  final _targets = const NutritionProfile(
    calories: 2400,
    proteinGrams: 180,
    carbohydratesGrams: 240,
    fatGrams: 80,
  );

  @override
  void initState() {
    super.initState();
    _ringAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ringAnim = CurvedAnimation(parent: _ringAnimController, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _ringAnimController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.apiService.fetchDailyTotals(),
        widget.apiService.fetchCaseFiles(date: DateTime.now().toIso8601String().split('T')[0]),
      ]);
      _dailyTotals    = results[0] as Map<String, dynamic>;
      _todayCaseFiles = results[1] as List<CaseFile>;
      setState(() => _loading = false);
      _ringAnimController.forward(from: 0);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: SafeArea(
        child: _loading
            ? const _LoadingTerminal()
            : _error != null
                ? _ErrorState(error: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: MLColors.accentCyan,
                    backgroundColor: MLColors.bgCard,
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _DashboardHeader()),
                        SliverToBoxAdapter(
                          child: _MacroRingsPanel(
                            totals: _dailyTotals!,
                            targets: _targets,
                            ringAnim: _ringAnim,
                            macroFilter: _macroFilter,
                            onRingTap: (macro) {
                              FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
                              setState(() => _macroFilter = _macroFilter == macro ? null : macro);
                            },
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _ProgressBars(
                            totals: _dailyTotals!,
                            targets: _targets,
                            ringAnim: _ringAnim,
                          ),
                        ),
                        SliverToBoxAdapter(child: _SectionLabel(label: 'TODAY\'S CASE FILES')),
                        if (_todayCaseFiles.isEmpty)
                          const SliverToBoxAdapter(child: _EmptyFeed())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final cf = _todayCaseFiles[i];
                                if (_macroFilter != null) {
                                  // Filter only shows if item contributes meaningfully
                                  final passes = _caseFilePassesFilter(cf, _macroFilter!);
                                  if (!passes) return const SizedBox.shrink();
                                }
                                return _CaseFileTile(caseFile: cf);
                              },
                              childCount: _todayCaseFiles.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
      ),
    );
  }

  bool _caseFilePassesFilter(CaseFile cf, String macro) {
    final t = cf.mealTotals;
    return switch (macro) {
      'protein' => t.proteinGrams > 10,
      'carbs'   => t.carbohydratesGrams > 15,
      'fat'     => t.fatGrams > 5,
      _         => true,
    };
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(MLSpacing.md, MLSpacing.md, MLSpacing.md, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMMAND CENTER', style: MLTextStyles.labelCaps),
              const SizedBox(height: 2),
              Text(dateStr, style: MLTextStyles.dataSmall.copyWith(color: MLColors.accentCyan)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MLColors.surfaceGlass,
              borderRadius: BorderRadius.circular(MLRadius.pill),
              border: Border.all(color: MLColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: MLColors.statusVerified, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE', style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusVerified)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Macro rings ─────────────────────────────────────────────────────────────

class _MacroRingsPanel extends StatelessWidget {
  final Map<String, dynamic> totals;
  final NutritionProfile targets;
  final Animation<double> ringAnim;
  final String? macroFilter;
  final ValueChanged<String> onRingTap;

  const _MacroRingsPanel({
    required this.totals,
    required this.targets,
    required this.ringAnim,
    required this.macroFilter,
    required this.onRingTap,
  });

  double get _calories =>  (totals['totalCalories']           as num? ?? 0).toDouble();
  double get _protein  =>  (totals['totalProteinGrams']       as num? ?? 0).toDouble();
  double get _carbs    =>  (totals['totalCarbohydratesGrams'] as num? ?? 0).toDouble();
  double get _fat      =>  (totals['totalFatGrams']           as num? ?? 0).toDouble();

  double _pct(double actual, double target) =>
      target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MLSpacing.md),
      child: AnimatedBuilder(
        animation: ringAnim,
        builder: (_, __) => Row(
          children: [
            // Central calorie ring
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 68,
                    lineWidth: 7,
                    percent: _pct(_calories, targets.calories) * ringAnim.value,
                    backgroundColor: MLColors.border,
                    progressColor: MLColors.accentCyan,
                    circularStrokeCap: CircularStrokeCap.round,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_calories * ringAnim.value).round()}',
                          style: MLTextStyles.dataMedium,
                        ),
                        Text('kcal', style: MLTextStyles.dataSmall),
                        Text(
                          '/ ${targets.calories.round()}',
                          style: MLTextStyles.dataSmall.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('CALORIES', style: MLTextStyles.labelCaps),
                ],
              ),
            ),
            const SizedBox(width: MLSpacing.md),
            // Macro rings column
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _MacroRingRow(
                    label: 'PROTEIN',
                    value: _protein,
                    target: targets.proteinGrams,
                    color: MLColors.macroProtein,
                    percent: _pct(_protein, targets.proteinGrams) * ringAnim.value,
                    isActive: macroFilter == 'protein',
                    onTap: () => onRingTap('protein'),
                  ),
                  const SizedBox(height: MLSpacing.sm),
                  _MacroRingRow(
                    label: 'CARBS',
                    value: _carbs,
                    target: targets.carbohydratesGrams,
                    color: MLColors.macroCarbs,
                    percent: _pct(_carbs, targets.carbohydratesGrams) * ringAnim.value,
                    isActive: macroFilter == 'carbs',
                    onTap: () => onRingTap('carbs'),
                  ),
                  const SizedBox(height: MLSpacing.sm),
                  _MacroRingRow(
                    label: 'FAT',
                    value: _fat,
                    target: targets.fatGrams,
                    color: MLColors.macroFat,
                    percent: _pct(_fat, targets.fatGrams) * ringAnim.value,
                    isActive: macroFilter == 'fat',
                    onTap: () => onRingTap('fat'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRingRow extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  final double percent;
  final bool isActive;
  final VoidCallback onTap;

  const _MacroRingRow({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    required this.percent,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: MLSpacing.sm, vertical: MLSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(MLRadius.sm),
          border: Border.all(color: isActive ? color.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularPercentIndicator(
                radius: 18,
                lineWidth: 3.5,
                percent: percent,
                backgroundColor: MLColors.border,
                progressColor: color,
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ),
            const SizedBox(width: MLSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MLTextStyles.labelCaps),
                  Text(
                    '${value.toStringAsFixed(1)}g / ${target.round()}g',
                    style: MLTextStyles.dataSmall.copyWith(color: color),
                  ),
                ],
              ),
            ),
            Text(
              '${(percent * 100).round()}%',
              style: MLTextStyles.dataMedium.copyWith(color: color, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress bars ────────────────────────────────────────────────────────────

class _ProgressBars extends StatelessWidget {
  final Map<String, dynamic> totals;
  final NutritionProfile targets;
  final Animation<double> ringAnim;

  const _ProgressBars({required this.totals, required this.targets, required this.ringAnim});

  @override
  Widget build(BuildContext context) {
    final remaining = NutritionProfile(
      calories: (targets.calories - (totals['totalCalories'] as num? ?? 0)).toDouble().clamp(0, double.infinity),
      proteinGrams: (targets.proteinGrams - (totals['totalProteinGrams'] as num? ?? 0)).toDouble().clamp(0, double.infinity),
      carbohydratesGrams: 0,
      fatGrams: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MLSpacing.md),
      padding: const EdgeInsets.all(MLSpacing.md),
      decoration: BoxDecoration(
        color: MLColors.bgCard,
        borderRadius: BorderRadius.circular(MLRadius.md),
        border: Border.all(color: MLColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('METABOLIC STATUS', style: MLTextStyles.labelCaps),
              if (remaining.proteinGrams > 0)
                _GapAlert(proteinGap: remaining.proteinGrams),
            ],
          ),
          const SizedBox(height: MLSpacing.sm),
        ],
      ),
    );
  }
}

class _GapAlert extends StatelessWidget {
  final double proteinGap;
  const _GapAlert({required this.proteinGap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MLColors.macroProtein.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MLRadius.pill),
        border: Border.all(color: MLColors.macroProtein.withOpacity(0.3)),
      ),
      child: Text(
        'PROTEIN GAP: ${proteinGap.round()}g',
        style: MLTextStyles.dataSmall.copyWith(color: MLColors.macroProtein),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(MLSpacing.md, MLSpacing.lg, MLSpacing.md, MLSpacing.sm),
        child: Text(label, style: MLTextStyles.labelCaps),
      );
}

// ─── Case File tile ───────────────────────────────────────────────────────────

class _CaseFileTile extends StatelessWidget {
  final CaseFile caseFile;
  const _CaseFileTile({required this.caseFile});

  @override
  Widget build(BuildContext context) {
    final time = '${caseFile.loggedAt.hour.toString().padLeft(2, '0')}:${caseFile.loggedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(MLSpacing.md, 0, MLSpacing.md, MLSpacing.sm),
      padding: const EdgeInsets.all(MLSpacing.md),
      decoration: BoxDecoration(
        color: MLColors.bgCard,
        borderRadius: BorderRadius.circular(MLRadius.md),
        border: Border.all(color: MLColors.border),
      ),
      child: Row(
        children: [
          // Meal type indicator
          Container(
            width: 4,
            height: 52,
            margin: const EdgeInsets.only(right: MLSpacing.md),
            decoration: BoxDecoration(
              color: caseFile.isVerified ? MLColors.statusVerified : MLColors.statusWarning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      caseFile.detectedItems.map((i) => i.name).take(2).join(', '),
                      style: MLTextStyles.headingSmall.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(time, style: MLTextStyles.dataSmall),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MacroChip('${caseFile.mealTotals.calories.round()} kcal', MLColors.textMuted),
                    const SizedBox(width: 6),
                    _MacroChip('P ${caseFile.mealTotals.proteinGrams.toStringAsFixed(0)}g', MLColors.macroProtein),
                    const SizedBox(width: 6),
                    _MacroChip('C ${caseFile.mealTotals.carbohydratesGrams.toStringAsFixed(0)}g', MLColors.macroCarbs),
                    const SizedBox(width: 6),
                    _MacroChip('F ${caseFile.mealTotals.fatGrams.toStringAsFixed(0)}g', MLColors.macroFat),
                  ],
                ),
              ],
            ),
          ),
          if (caseFile.isVerified)
            Padding(
              padding: const EdgeInsets.only(left: MLSpacing.sm),
              child: Icon(Icons.verified_rounded, color: MLColors.statusVerified, size: 16),
            ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: MLTextStyles.dataSmall.copyWith(color: color, fontSize: 10),
      );
}

// ─── Loading & error states ───────────────────────────────────────────────────

class _LoadingTerminal extends StatelessWidget {
  const _LoadingTerminal();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: MLColors.accentCyan),
            ),
            const SizedBox(height: MLSpacing.md),
            Text('LOADING METABOLIC DATA...', style: MLTextStyles.statusReadout),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MLSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: MLColors.statusError, size: 32),
              const SizedBox(height: MLSpacing.md),
              Text(error, style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError), textAlign: TextAlign.center),
              const SizedBox(height: MLSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: MLColors.accentCyan)),
                child: Text('RETRY', style: MLTextStyles.labelCaps.copyWith(color: MLColors.accentCyan)),
              ),
            ],
          ),
        ),
      );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(MLSpacing.xxl),
        child: Column(
          children: [
            const Icon(Icons.camera_enhance_outlined, color: MLColors.textDim, size: 40),
            const SizedBox(height: MLSpacing.md),
            Text('NO CASE FILES TODAY', style: MLTextStyles.labelCaps),
            const SizedBox(height: 4),
            Text('Capture a meal to begin analysis.', style: MLTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      );
}
