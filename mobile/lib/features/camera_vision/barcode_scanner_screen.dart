import 'dart:convert';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/case_file.dart';
import '../detective_refinement/detective_overlay.dart';

/// Triggered when the user taps the BARCODE mode toggle in the ViewfinderScreen.
/// Launches the device's native barcode scanner, looks up the result in
/// Open Food Facts via the backend, then drops into the Detective Overlay.
class BarcodeScannerScreen extends StatefulWidget {
  final ApiService apiService;
  const BarcodeScannerScreen({super.key, required this.apiService});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  _ScanPhase _phase = _ScanPhase.idle;
  String? _errorMessage;
  Map<String, dynamic>? _productData;

  @override
  void initState() {
    super.initState();
    // Auto-launch scanner on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    setState(() { _phase = _ScanPhase.scanning; _errorMessage = null; });

    try {
      final result = await BarcodeScanner.scan(
        options: const ScanOptions(
          strings: {'cancel': 'CANCEL', 'flash_on': 'FLASH ON', 'flash_off': 'FLASH OFF'},
          useCamera: -1,
          autoEnableFlash: false,
          android: AndroidOptions(useAutoFocus: true),
        ),
      );

      if (result.type == ResultType.Cancelled) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (result.rawContent.isEmpty) {
        setState(() { _phase = _ScanPhase.idle; _errorMessage = 'ERR_BARCODE_EMPTY: No barcode detected.'; });
        return;
      }

      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
      setState(() => _phase = _ScanPhase.fetching);
      await _fetchProduct(result.rawContent);
    } on PlatformException catch (e) {
      setState(() {
        _phase = _ScanPhase.idle;
        _errorMessage = 'ERR_SCANNER_UNAVAILABLE: ${e.message}';
      });
    }
  }

  Future<void> _fetchProduct(String barcode) async {
    try {
      final productData = await widget.apiService.lookupBarcode(barcode);
      setState(() {
        _productData = productData;
        _phase = _ScanPhase.found;
      });
      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
    } catch (e) {
      setState(() {
        _phase = _ScanPhase.idle;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _logProduct() async {
    if (_productData == null) return;
    final product = _productData!;

    // Build a minimal CaseFile-shaped map so DetectiveOverlay can display it
    final nutrition = product['nutritionPer100g'] as Map<String, dynamic>;
    final estGrams  = (product['estimatedGrams'] as num).toDouble();
    final mult      = estGrams / 100.0;

    final caseFileJson = {
      '_id':          'barcode_${DateTime.now().millisecondsSinceEpoch}',
      'caseFileId':   'bc_${product['barcode']}',
      'userId':       '',
      'mealType':     'snack',
      'loggedAt':     DateTime.now().toIso8601String(),
      'overallConfidence': 'high',
      'detectedItems': [
        {
          'itemId':           'item_0',
          'name':             product['name'] as String,
          'usdaSearchTerm':   product['name'] as String,
          'usdaFoodId':       null,
          'massGrams':        estGrams,
          'compositionConfidence': 'high',
          'preparationState': 'processed',
          'cookingMethod':    'unknown',
          'nutritionPer100g': nutrition,
          'nutritionTotal': {
            'calories':           _mult(nutrition['calories'], mult),
            'proteinGrams':       _mult(nutrition['proteinGrams'], mult),
            'carbohydratesGrams': _mult(nutrition['carbohydratesGrams'], mult),
            'fatGrams':           _mult(nutrition['fatGrams'], mult),
            'fiberGrams':         _mult(nutrition['fiberGrams'], mult),
          },
          'alternativeCandidates': const [],
          'verificationStatus':    'ai_verified',
        }
      ],
      'mealTotals': {
        'calories':           _mult(nutrition['calories'], mult),
        'proteinGrams':       _mult(nutrition['proteinGrams'], mult),
        'carbohydratesGrams': _mult(nutrition['carbohydratesGrams'], mult),
        'fatGrams':           _mult(nutrition['fatGrams'], mult),
        'fiberGrams':         _mult(nutrition['fiberGrams'], mult),
      },
      'nutritionDataVerified': true,
      'notes': null,
    };

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetectiveOverlay(
        caseFileJson: caseFileJson,
        apiService: widget.apiService,
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  double _mult(dynamic v, double mult) => ((v as num).toDouble() * mult);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(MLSpacing.md, MLSpacing.md, MLSpacing.md, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back, color: MLColors.textMuted),
                  ),
                  const SizedBox(width: MLSpacing.md),
                  Text('BARCODE SCAN', style: MLTextStyles.headingSmall),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_phase) {
      _ScanPhase.idle    => _IdleState(error: _errorMessage, onRetry: _startScan),
      _ScanPhase.scanning => const _ScanningState(),
      _ScanPhase.fetching => const _FetchingState(),
      _ScanPhase.found   => _ProductCard(product: _productData!, onLog: _logProduct, onRescan: _startScan),
    };
  }
}

enum _ScanPhase { idle, scanning, fetching, found }

// ─── States ───────────────────────────────────────────────────────────────────

class _ScanningState extends StatelessWidget {
  const _ScanningState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2, color: MLColors.accentCyan),
            ),
            const SizedBox(height: MLSpacing.md),
            Text('AWAITING BARCODE INPUT...', style: MLTextStyles.statusReadout),
          ],
        ),
      );
}

class _FetchingState extends StatelessWidget {
  const _FetchingState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2, color: MLColors.accentCyan),
            ),
            const SizedBox(height: MLSpacing.md),
            Text('QUERYING OPEN FOOD FACTS...', style: MLTextStyles.statusReadout),
          ],
        ),
      );
}

class _IdleState extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _IdleState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MLSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, color: MLColors.textDim, size: 56),
              const SizedBox(height: MLSpacing.lg),
              if (error != null) ...[
                Text(error!, style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError), textAlign: TextAlign.center),
                const SizedBox(height: MLSpacing.lg),
              ],
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: MLColors.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MLRadius.md)),
                ),
                child: Text('SCAN BARCODE', style: MLTextStyles.labelCaps.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onLog;
  final VoidCallback onRescan;
  const _ProductCard({required this.product, required this.onLog, required this.onRescan});

  @override
  Widget build(BuildContext context) {
    final nutrition = product['nutritionPer100g'] as Map<String, dynamic>;
    final brand = product['brand'] as String?;
    final nutriscore = product['nutriscore'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MLSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product identity
          Container(
            padding: const EdgeInsets.all(MLSpacing.md),
            decoration: BoxDecoration(
              color: MLColors.bgCard,
              borderRadius: BorderRadius.circular(MLRadius.md),
              border: Border.all(color: MLColors.accentCyan.withAlpha(60)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] as String, style: MLTextStyles.headingMedium),
                      if (brand != null)
                        Text(brand, style: MLTextStyles.bodyMuted.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                if (nutriscore != null) _NutriScoreBadge(grade: nutriscore),
              ],
            ),
          ),
          const SizedBox(height: MLSpacing.md),

          // Barcode info
          Row(
            children: [
              const Icon(Icons.qr_code, color: MLColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(product['barcode'] as String, style: MLTextStyles.dataSmall),
              const Spacer(),
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
          const SizedBox(height: MLSpacing.lg),

          // Nutrition per 100g
          Text('PER 100g', style: MLTextStyles.labelCaps),
          const SizedBox(height: MLSpacing.sm),
          _NutritionGrid(nutrition: nutrition),
          const SizedBox(height: MLSpacing.xl),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRescan,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MLColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MLRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('RESCAN', style: MLTextStyles.labelCaps.copyWith(color: MLColors.textMuted)),
                ),
              ),
              const SizedBox(width: MLSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onLog,
                  style: FilledButton.styleFrom(
                    backgroundColor: MLColors.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MLRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('LOG THIS PRODUCT', style: MLTextStyles.labelCaps.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  final Map<String, dynamic> nutrition;
  const _NutritionGrid({required this.nutrition});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(MLSpacing.md),
        decoration: BoxDecoration(
          color: MLColors.surfaceGlass,
          borderRadius: BorderRadius.circular(MLRadius.md),
          border: Border.all(color: MLColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Cell('${(nutrition['calories'] as num).round()}', 'KCAL', MLColors.textPrimary),
            _Cell('${(nutrition['proteinGrams'] as num).toStringAsFixed(1)}g', 'PROT', MLColors.macroProtein),
            _Cell('${(nutrition['carbohydratesGrams'] as num).toStringAsFixed(1)}g', 'CARBS', MLColors.macroCarbs),
            _Cell('${(nutrition['fatGrams'] as num).toStringAsFixed(1)}g', 'FAT', MLColors.macroFat),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Cell(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: MLTextStyles.dataMedium.copyWith(color: color, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: MLTextStyles.labelCaps),
        ],
      );
}

class _NutriScoreBadge extends StatelessWidget {
  final String grade;
  const _NutriScoreBadge({required this.grade});

  static const _colors = {'A': Color(0xFF22C55E), 'B': Color(0xFF84CC16), 'C': Color(0xFFF59E0B), 'D': Color(0xFFF97316), 'E': Color(0xFFEF4444)};

  @override
  Widget build(BuildContext context) {
    final color = _colors[grade] ?? MLColors.textMuted;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(MLRadius.sm),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Center(
        child: Text(grade, style: MLTextStyles.dataMedium.copyWith(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
