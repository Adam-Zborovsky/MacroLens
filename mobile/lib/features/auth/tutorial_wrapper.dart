import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tutorial_provider.dart';
import 'tutorial_service.dart';

class TutorialWrapper extends StatefulWidget {
  final Widget child;
  final TutorialStep step;

  const TutorialWrapper({
    super.key,
    required this.child,
    required this.step,
  });

  @override
  State<TutorialWrapper> createState() => _TutorialWrapperState();
}

class _TutorialWrapperState extends State<TutorialWrapper> {
  TutorialCoachMark? _tutorial;
  bool _tutorialScheduled = false;
  int? _lastKnownStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkCurrentStep();
    });
  }

  void _checkCurrentStep() {
    final provider = context.read<TutorialProvider>();
    if (provider.isInitialized && 
        provider.currentStep == widget.step && 
        _lastKnownStep != widget.step.value) {
      _lastKnownStep = widget.step.value;
      _scheduleTutorial();
    }
  }

  void _scheduleTutorial() {
    if (_tutorialScheduled) return;
    _tutorialScheduled = true;
    
    // Slight delay to ensure the screen is fully rendered
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _showTutorial();
    });
  }

  void _showTutorial() {
    final targets = _buildTargets();
    if (targets.isEmpty) {
      _tutorialScheduled = false;
      return;
    }

    _tutorial = TutorialService.createTutorial(
      context: context,
      targets: targets,
      onFinish: () {
        if (!mounted) return;
        context.read<TutorialProvider>().completeStep(widget.step);
        _tutorialScheduled = false;
      },
    );

    _tutorial?.show(context: context);
  }

  List<TargetFocus> _buildTargets() {
    switch (widget.step) {
      case TutorialStep.dashboard:
        return TutorialService.getDashboardTargets();
      case TutorialStep.camera:
        return TutorialService.getCameraTargets();
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _tutorial = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the tutorial provider
    final provider = context.watch<TutorialProvider>();
    
    if (provider.isInitialized) {
      if (provider.currentStep == widget.step && _lastKnownStep != widget.step.value) {
        _lastKnownStep = widget.step.value;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleTutorial();
        });
      } else if (provider.currentStep != widget.step) {
        // Step moved away, allow re-trigger if it comes back (reset)
        _lastKnownStep = provider.currentStep.value;
      }
    }

    return widget.child;
  }
}
