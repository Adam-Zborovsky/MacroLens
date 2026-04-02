import 'package:flutter/material.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Meal>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _mealsFuture = _apiService.fetchMeals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "ARCHIVE_V1.0",
          style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: FutureBuilder<List<Meal>>(
              future: _mealsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("ERR_FETCH_FAILED: ${snapshot.error}", style: GoogleFonts.firaCode(fontSize: 10, color: Colors.redAccent)));
                }
                final meals = snapshot.data ?? [];
                if (meals.isEmpty) {
                  return Center(child: Text("ZERO_RECORDS_FOUND", style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.secondary)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: meals.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 24),
                  itemBuilder: (context, index) => _buildArchiveEntry(meals[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "SEARCH_FILES...",
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FilterChip(label: "VERIFIED", isActive: true),
              _FilterChip(label: "LATEST"),
              _FilterChip(label: "HIGH_PROTEIN"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveEntry(Meal meal) {
    final timeStr = DateFormat('hh:mm_a').format(meal.loggedAt).toUpperCase();
    final specimenName = meal.detectedItems.isNotEmpty ? meal.detectedItems[0].name.toUpperCase() : "UNKNOWN_SPECIMEN";

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 100,
            color: AppTheme.surfaceContainerHighest,
            child: const Icon(Icons.photo_outlined, color: AppTheme.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CASE_FILE_#${meal.id?.substring(0, 4) ?? 'NULL'}",
                        style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.primary),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specimenName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MacroIndicator(label: "P", value: "${meal.mealTotals.proteinGrams.toInt()}g"),
                      const SizedBox(width: 12),
                      _MacroIndicator(label: "C", value: "${meal.mealTotals.carbohydratesGrams.toInt()}g"),
                      const SizedBox(width: 12),
                      _MacroIndicator(label: "F", value: "${meal.mealTotals.fatGrams.toInt()}g"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.secondary),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  const _FilterChip({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryContainer : Colors.transparent,
        border: Border.all(color: isActive ? AppTheme.primary : AppTheme.outlineVariant),
      ),
      child: Text(label, style: GoogleFonts.firaCode(fontSize: 8, fontWeight: FontWeight.bold, color: isActive ? Colors.white : AppTheme.secondary)),
    );
  }
}

class _MacroIndicator extends StatelessWidget {
  final String label;
  final String value;
  const _MacroIndicator({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary)),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
