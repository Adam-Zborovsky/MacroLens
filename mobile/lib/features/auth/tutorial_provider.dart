import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TutorialStep {
  dashboard(0),
  camera(1),
  completed(100);

  final int value;
  const TutorialStep(this.value);

  static TutorialStep fromValue(int value) {
    return TutorialStep.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TutorialStep.dashboard,
    );
  }
}

class TutorialProvider with ChangeNotifier {
  static const _keyStep = 'tutorial_step';
  static const _keyCompleted = 'tutorial_completed';

  TutorialStep _currentStep = TutorialStep.dashboard;
  bool _isInitialized = false;

  TutorialStep get currentStep => _currentStep;
  bool get isInitialized => _isInitialized;

  TutorialProvider() {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyCompleted) ?? false) {
      _currentStep = TutorialStep.completed;
    } else {
      final stepValue = prefs.getInt(_keyStep) ?? 0;
      _currentStep = TutorialStep.fromValue(stepValue);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> completeStep(TutorialStep step) async {
    if (step.value >= _currentStep.value) {
      final nextStepValue = step.value + 1;
      // If we don't have a next step, we might be done or we just stay at this one
      // For MacroLens, we have dashboard (0) and camera (1).
      if (nextStepValue > 1) {
        await completeAll();
      } else {
        _currentStep = TutorialStep.fromValue(nextStepValue);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyStep, nextStepValue);
        notifyListeners();
      }
    }
  }

  Future<void> completeAll() async {
    _currentStep = TutorialStep.completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
    notifyListeners();
  }

  Future<void> resetTutorial() async {
    _currentStep = TutorialStep.dashboard;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompleted);
    await prefs.remove(_keyStep);
    notifyListeners();
  }
}
