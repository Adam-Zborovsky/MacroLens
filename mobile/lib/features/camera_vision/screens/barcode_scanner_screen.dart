import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/features/detective_refinement/screens/refinement_modal.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  
  bool _isProcessing = false;
  final ApiService _apiService = ApiService();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.displayValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      // 1. Fetch from backend
      final data = await _apiService.getNutritionByBarcode(code);
      
      // 2. Map to DetectedItem (stub for RefinementModal)
      final nutrition = data['nutritionPer100g'];
      final item = DetectedItem(
        itemId: "barcode_${DateTime.now().millisecondsSinceEpoch}",
        name: data['name'] ?? "Unknown Product",
        usdaSearchTerm: code,
        massGrams: (data['estimatedGrams'] as num?)?.toDouble() ?? 100.0,
        compositionConfidence: "high",
        nutritionPer100g: NutritionProfile(
          calories: (nutrition['calories'] as num).toDouble(),
          proteinGrams: (nutrition['proteinGrams'] as num).toDouble(),
          carbohydratesGrams: (nutrition['carbohydratesGrams'] as num).toDouble(),
          fatGrams: (nutrition['fatGrams'] as num).toDouble(),
          fiberGrams: (nutrition['fiberGrams'] as num?)?.toDouble() ?? 0.0,
        ),
        nutritionTotal: NutritionProfile(
          calories: (nutrition['calories'] as num).toDouble(),
          proteinGrams: (nutrition['proteinGrams'] as num).toDouble(),
          carbohydratesGrams: (nutrition['carbohydratesGrams'] as num).toDouble(),
          fatGrams: (nutrition['fatGrams'] as num).toDouble(),
          fiberGrams: (nutrition['fiberGrams'] as num?)?.toDouble() ?? 0.0,
        ),
        verificationStatus: "ai_verified",
        alternativeCandidates: [],
      );

      if (!mounted) return;

      // 3. Close scanner and show modal
      Navigator.pop(context);
      
      RefinementModal.show(
        context,
        item: item,
        alternatives: [],
        onSave: (updatedItem) async {
          // Note: Barcode doesn't have a Meal record yet in this flow
          // Usually we'd create a meal from barcode on the backend first
          // For now, let's just log success as a placeholder
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("BARCODE_ITEM_LOGGED: ${updatedItem.name}"),
              backgroundColor: AppTheme.primary,
            ),
          );
        },
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ERR_BARCODE_LOOKUP: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SCAN_PRODUCT_BARCODE",
          style: GoogleFonts.firaCode(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Custom Overlay
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ALIGN_BARCODE_WITHIN_FRAME",
                style: GoogleFonts.firaCode(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
