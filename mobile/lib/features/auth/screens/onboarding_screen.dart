import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/features/camera_vision/screens/camera_home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final ApiService _apiService = ApiService();

  // Data
  double? _currentWeight;
  double? _targetWeight;
  String? _progressRate; // 'slow', 'moderate', 'fast'
  
  // Manual overrides
  bool _useManualMacros = false;
  final _calController = TextEditingController();
  final _proController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    HapticFeedback.heavyImpact();
    
    Map<String, dynamic> goals = {};

    if (_useManualMacros) {
      goals['dailyTargets'] = {
        'calories': double.tryParse(_calController.text) ?? 2000,
        'proteinGrams': double.tryParse(_proController.text) ?? 150,
        'carbohydratesGrams': double.tryParse(_carbController.text) ?? 200,
        'fatGrams': double.tryParse(_fatController.text) ?? 70,
      };
    } else {
      // Basic mapping to backend's current logic
      String phase = 'maintain';
      if (_currentWeight != null && _targetWeight != null) {
        if (_targetWeight! > _currentWeight!) {
          phase = 'bulk';
        } else if (_targetWeight! < _currentWeight!) {
          phase = 'cut';
        }
      }

      goals['biometrics'] = {
        'massKilograms': _currentWeight,
        // Default values if not asked
        'heightCentimeters': 175,
        'ageYears': 30,
        'biologicalSex': 'male',
        'activityMultiplier': 1.55,
      };
      goals['currentPhase'] = phase;
      
      // Map progress rate to macro split or intensity (simplified for now)
      if (_progressRate == 'fast') {
        goals['macroSplit'] = {'proteinRatio': 0.35, 'carbohydratesRatio': 0.35, 'fatRatio': 0.3};
      } else if (_progressRate == 'slow') {
        goals['macroSplit'] = {'proteinRatio': 0.25, 'carbohydratesRatio': 0.45, 'fatRatio': 0.3};
      }
    }

    try {
      await _apiService.updateGoals(goals);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CameraHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_ONBOARDING: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildWeightPage("CURRENT_BODY_WEIGHT", (val) => _currentWeight = val),
                  _buildWeightPage("TARGET_BODY_WEIGHT", (val) => _targetWeight = val),
                  _buildRatePage(),
                  _buildSummaryOrManualPage(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: index <= _currentPage 
                ? AppTheme.primary 
                : AppTheme.primary.withOpacity(0.1),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeightPage(String title, Function(double) onSaved) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.ghostWhite,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "ENTER_VALUE_IN_KILOGRAMS",
            style: GoogleFonts.firaCode(
              fontSize: 10,
              color: AppTheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 48),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.firaCode(fontSize: 48, color: AppTheme.primary),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: "00.0",
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) => onSaved(double.tryParse(val) ?? 0.0),
          ),
        ],
      ),
    );
  }

  Widget _buildRatePage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PROGRESS_VELOCITY",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.ghostWhite,
            ),
          ),
          const SizedBox(height: 48),
          _buildRateOption("SLOW", "Sustainable, long-term focus", 'slow'),
          const SizedBox(height: 16),
          _buildRateOption("MODERATE", "Balanced approach", 'moderate'),
          const SizedBox(height: 16),
          _buildRateOption("FAST", "Aggressive results oriented", 'fast'),
        ],
      ),
    );
  }

  Widget _buildRateOption(String title, String subtitle, String value) {
    bool isSelected = _progressRate == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _progressRate = value);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaCode(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : AppTheme.ghostWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.secondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryOrManualPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CALIBRATION_SUMMARY",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.ghostWhite,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("USE_MANUAL_OVERRIDE", style: GoogleFonts.firaCode(fontSize: 12)),
              Switch(
                value: _useManualMacros,
                onChanged: (val) => setState(() => _useManualMacros = val),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_useManualMacros) ...[
            _buildManualField("DAILY_CALORIES", _calController),
            const SizedBox(height: 16),
            _buildManualField("PROTEIN_GRAMS", _proController),
            const SizedBox(height: 16),
            _buildManualField("CARB_GRAMS", _carbController),
            const SizedBox(height: 16),
            _buildManualField("FAT_GRAMS", _fatController),
          ] else ...[
            _buildSummaryRow("CURRENT_WEIGHT", "${_currentWeight ?? 0} kg"),
            _buildSummaryRow("TARGET_WEIGHT", "${_targetWeight ?? 0} kg"),
            _buildSummaryRow("RATE", _progressRate?.toUpperCase() ?? "NOT_SET"),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.primary.withOpacity(0.05),
              child: Text(
                "AI_CALCULATION_WILL_DETERMINE_OPTIMAL_MACROS_UPON_EXECUTION.",
                style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.primary.withOpacity(0.8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary)),
          Text(value, style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildManualField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.firaCode(color: AppTheme.primary),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text("BACK", style: GoogleFonts.firaCode(color: AppTheme.secondary)),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: _nextPage,
            child: Text(_currentPage == 3 ? "EXECUTE_CALIBRATION" : "NEXT_PHASE"),
          ),
        ],
      ),
    );
  }
}
