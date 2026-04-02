import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final ApiService _apiService = ApiService();
  String _currentPhase = "MAINTAIN";
  
  final _calController = TextEditingController(text: "2500");
  final _proteinController = TextEditingController(text: "180");
  final _carbsController = TextEditingController(text: "250");
  final _fatController = TextEditingController(text: "70");

  void _saveGoals() async {
    HapticFeedback.mediumImpact();
    try {
      await _apiService.updateGoals({
        'currentPhase': _currentPhase.toLowerCase(),
        'dailyTargets': {
          'calories': double.parse(_calController.text),
          'proteinGrams': double.parse(_proteinController.text),
          'carbohydratesGrams': double.parse(_carbsController.text),
          'fatGrams': double.parse(_fatController.text),
        }
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("METABOLIC_TARGETS_UPDATED", style: GoogleFonts.firaCode(fontSize: 10)),
            backgroundColor: AppTheme.primaryContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_UPDATE_FAILED: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("CALIBRATION_HUB_V1.0", style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TRAINING_PHASE_SELECT", style: AppTheme.darkTheme.textTheme.labelMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildPhaseButton("CUT"),
                const SizedBox(width: 12),
                _buildPhaseButton("MAINTAIN"),
                const SizedBox(width: 12),
                _buildPhaseButton("BULK"),
              ],
            ),
            const SizedBox(height: 48),
            Text("DAILY_MACRO_TARGETS", style: AppTheme.darkTheme.textTheme.labelMedium),
            const SizedBox(height: 24),
            _buildTargetInput("ENERGY_CAP", "KCAL", _calController),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildTargetInput("PROTEIN", "G", _proteinController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTargetInput("CARBS", "G", _carbsController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTargetInput("FATS", "G", _fatController)),
              ],
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveGoals,
                child: const Text("SAVE_METABOLIC_CONFIG"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseButton(String phase) {
    final isActive = _currentPhase == phase;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentPhase = phase);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow,
            border: Border.all(color: isActive ? AppTheme.primary : AppTheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              phase,
              style: GoogleFonts.firaCode(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetInput(String label, String unit, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 9, color: AppTheme.secondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.firaCode(color: AppTheme.ghostWhite),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
          ),
        ),
      ],
    );
  }
}
