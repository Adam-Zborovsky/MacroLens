import 'package:flutter/material.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ManualEntryScreen extends StatelessWidget {
  const ManualEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "MANUAL_ENTRY_V1.0",
          style: GoogleFonts.firaCode(
            color: AppTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Text("QUERY_DATABASE", style: AppTheme.darkTheme.textTheme.labelMedium),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: "SEARCH_USDA_CATALOG...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 48),

            // Macro Quick Input
            Text("MACRO_QUICK_INPUT", style: AppTheme.darkTheme.textTheme.labelMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
              ),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildQuickInput("CALORIES", "KCAL"),
                  _buildQuickInput("PROTEIN", "G"),
                  _buildQuickInput("CARBS", "G"),
                  _buildQuickInput("FAT", "G"),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Quick Wins
            Text("QUICK_WINS", style: AppTheme.darkTheme.textTheme.labelMedium),
            const SizedBox(height: 16),
            _buildQuickWin("ESPRESSO", "5 KCAL | 0G PRO"),
            _buildQuickWin("WHEY_PROTEIN", "120 KCAL | 24G PRO"),
            _buildQuickWin("OATS_50G", "190 KCAL | 7G PRO"),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("EXECUTE_LOG"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInput(String label, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary)),
        const SizedBox(height: 4),
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixText: unit,
              suffixStyle: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickWin(String name, String macros) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(macros, style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.secondary)),
        ],
      ),
    );
  }
}
