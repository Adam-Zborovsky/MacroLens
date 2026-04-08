import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'tutorial_keys.dart';

class TutorialService {
  static TutorialCoachMark createTutorial({
    required BuildContext context,
    required List<TargetFocus> targets,
    Function()? onFinish,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: AppTheme.background,
      opacityShadow: 0.9,
      paddingFocus: 10,
      onFinish: onFinish,
      onSkip: () {
        if (onFinish != null) onFinish();
        return true;
      },
      onClickTarget: (target) {},
      alignSkip: Alignment.topRight,
      textSkip: "SKIP_TUTORIAL",
      textStyleSkip: GoogleFonts.firaCode(
        color: AppTheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static List<TargetFocus> getDashboardTargets() {
    return [
      _createTarget(
        identify: "Calories",
        key: TutorialKeys.dashboardCalories,
        title: "CALORIE_SUMMARY",
        description: "Your total daily energy. Track how many calories you have left for your goal.",
      ),
      _createTarget(
        identify: "Macros",
        key: TutorialKeys.dashboardMacros,
        title: "MACRO_NUTRIENTS",
        description: "Your Protein, Carbs, and Fats. Keep these balanced to reach your target.",
      ),
      _createTarget(
        identify: "Timeline",
        key: TutorialKeys.dashboardTimeline,
        title: "TODAY_MEALS",
        description: "A list of all the meals you have scanned or logged today.",
      ),
      _createTarget(
        identify: "Tune",
        key: TutorialKeys.dashboardTune,
        title: "CHANGE_GOALS",
        description: "Set your daily calorie and macro targets here. Update them as you progress.",
      ),
    ];
  }

  static List<TargetFocus> getCameraTargets() {
    return [
      _createTarget(
        identify: "Shutter",
        key: TutorialKeys.cameraShutter,
        title: "TAKE_PHOTO",
        description: "Take a photo of your food. Keep the food in the center for the best scan result.",
      ),
      _createTarget(
        identify: "Gallery",
        key: TutorialKeys.cameraGallery,
        title: "PICK_PHOTO",
        description: "Upload a photo from your phone's gallery to scan for nutrition data.",
      ),
      _createTarget(
        identify: "Manual",
        key: TutorialKeys.cameraManual,
        title: "MANUAL_ENTRY",
        description: "Type your meal data manually if you do not have a photo of your food.",
      ),
      _createTarget(
        identify: "History",
        key: TutorialKeys.cameraHistory,
        title: "MEAL_LOGS",
        description: "Look at all your past meals and history records here.",
      ),
      _createTarget(
        identify: "Home",
        key: TutorialKeys.cameraHome,
        title: "DASHBOARD",
        description: "Go back to the main screen to see your daily summary and progress.",
      ),
    ];
  }

  static TargetFocus _createTarget({
    required String identify,
    required GlobalKey key,
    required String title,
    required String description,
    ContentAlign align = ContentAlign.bottom,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: key,
      alignSkip: Alignment.topRight,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: 0, // No rounded corners as per design system
    );
  }
}
