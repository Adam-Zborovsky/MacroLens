import 'package:flutter/material.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/features/goal_engine/screens/goals_screen.dart';
import 'package:macro_lens_mobile/features/auth/screens/profile_screen.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_provider.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Meal>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _apiService.fetchMeals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: TutorialWrapper(
        step: TutorialStep.dashboard,
        child: SafeArea(
          child: FutureBuilder<List<Meal>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            
            final meals = snapshot.data ?? [];
            final today = DateTime.now();
            final todaysMeals = meals.where((m) => 
              m.loggedAt.year == today.year && 
              m.loggedAt.month == today.month && 
              m.loggedAt.day == today.day
            ).toList();

            double totalP = 0, totalC = 0, totalF = 0, totalCals = 0;
            for (var m in todaysMeals) {
              totalP += m.mealTotals.proteinGrams;
              totalC += m.mealTotals.carbohydratesGrams;
              totalF += m.mealTotals.fatGrams;
              totalCals += m.mealTotals.calories;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildEnergyReadout(totalCals, 2500, key: TutorialKeys.dashboardCalories), // Hardcoded target for now
                  const SizedBox(height: 32),
                  _buildMacroRings(totalP, totalC, totalF, key: TutorialKeys.dashboardMacros),
                  const SizedBox(height: 48),
                  _buildTimelineSection(todaysMeals, key: TutorialKeys.dashboardTimeline),
                  const SizedBox(height: 32),
                  _buildHydrationTracker(),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DASHBOARD",
              style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("DAILY_SUMMARY", style: AppTheme.darkTheme.textTheme.headlineMedium),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: TutorialKeys.dashboardTune,
              icon: const Icon(Icons.tune_rounded, color: AppTheme.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalsScreen())),
            ),
            IconButton(
              key: TutorialKeys.dashboardProfile,
              icon: const Icon(Icons.person_outline_rounded, color: AppTheme.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnergyReadout(double current, double target, {Key? key}) {
    final remaining = target - current;
    final percent = (current / target).clamp(0.0, 1.0);

    return Container(
      key: key,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CALORIES", style: AppTheme.darkTheme.textTheme.labelMedium),
              Text("${percent > 1.0 ? 'OVER_GOAL' : 'ON_TRACK'}", 
                style: GoogleFonts.firaCode(fontSize: 10, color: percent > 1.0 ? Colors.redAccent : AppTheme.primary)
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current.toInt().toString(),
                style: GoogleFonts.firaCode(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.ghostWhite),
              ),
              const SizedBox(width: 8),
              Text(
                "/ $target KCAL",
                style: GoogleFonts.firaCode(fontSize: 16, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: AppTheme.surfaceContainerHighest,
            color: percent > 1.0 ? Colors.redAccent : AppTheme.primary,
            minHeight: 2,
          ),
          const SizedBox(height: 12),
          Text(
            "LEFT: ${remaining.toInt()} KCAL",
            style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRings(double p, double c, double f, {Key? key}) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MacroRing(label: "PROTEIN", current: p, target: 180, color: AppTheme.primary),
        _MacroRing(label: "CARBS", current: c, target: 250, color: Colors.blueAccent),
        _MacroRing(label: "FATS", current: f, target: 70, color: Colors.orangeAccent),
      ],
    );
  }

  Widget _buildTimelineSection(List<Meal> meals, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("TODAY'S_MEALS", style: AppTheme.darkTheme.textTheme.labelMedium),
            Text("${meals.length}_ITEMS", style: AppTheme.darkTheme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 16),
        if (meals.isEmpty)
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(color: AppTheme.surfaceContainerLow),
            child: Center(child: Text("NO_MEALS_LOGGED", style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary))),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildTimelineItem(meals[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(Meal meal) {
    final name = meal.detectedItems.isNotEmpty ? meal.detectedItems[0].name.toUpperCase() : "UNKNOWN";
    final time = DateFormat('hh:mm').format(meal.loggedAt);

    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: AppTheme.surfaceContainerHigh,
              child: const Center(child: Icon(Icons.fastfood_outlined, color: AppTheme.secondary, size: 32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.primary)),
                Text(name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationTracker() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("WATER_LOG", style: AppTheme.darkTheme.textTheme.labelMedium),
              Text("1750ML / 2500ML", style: AppTheme.darkTheme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: List.generate(8, (index) {
              final active = index < 5;
              return Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: active ? Colors.blueAccent : AppTheme.surfaceContainerHighest,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text("ADD_CUP"),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  const _MacroRing({required this.label, required this.current, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = (current / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(value: percent, strokeWidth: 4, backgroundColor: AppTheme.surfaceContainerHighest, color: color),
            ),
            Column(
              children: [
                Text(current.toInt().toString(), style: GoogleFonts.firaCode(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.ghostWhite)),
                Text("G", style: GoogleFonts.firaCode(fontSize: 8, color: AppTheme.secondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
      ],
    );
  }
}
