import 'package:flutter/material.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macro_lens_mobile/core/models/preset.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  List<Preset> _presets = [];
  bool _isLoadingPresets = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await _apiService.fetchPresets();
      setState(() {
        _presets = presets;
        _isLoadingPresets = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPresets = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("ERR_LOAD_PRESETS: $e", style: GoogleFonts.firaCode(fontSize: 12)),
          ),
        );
      }
    }
  }

  Future<void> _saveAsPreset() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ERR_NAME_REQUIRED", style: GoogleFonts.firaCode(fontSize: 12)),
        ),
      );
      return;
    }

    final preset = Preset(
      userId: '', // Set by backend
      name: _nameController.text,
      calories: double.tryParse(_caloriesController.text) ?? 0,
      proteinGrams: double.tryParse(_proteinController.text) ?? 0,
      carbohydratesGrams: double.tryParse(_carbsController.text) ?? 0,
      fatGrams: double.tryParse(_fatController.text) ?? 0,
    );

    try {
      await _apiService.createPreset(preset);
      _loadPresets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryContainer,
            content: Text("PRESET_SAVED_SUCCESSFULLY", style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("ERR_SAVE_PRESET: $e", style: GoogleFonts.firaCode(fontSize: 12)),
          ),
        );
      }
    }
  }

  Future<void> _executeLog() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ERR_NAME_REQUIRED", style: GoogleFonts.firaCode(fontSize: 12)),
        ),
      );
      return;
    }

    try {
      await _apiService.createManualMeal(
        name: _nameController.text,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        proteinGrams: double.tryParse(_proteinController.text) ?? 0,
        carbohydratesGrams: double.tryParse(_carbsController.text) ?? 0,
        fatGrams: double.tryParse(_fatController.text) ?? 0,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryContainer,
            content: Text("MEAL_LOGGED_SUCCESSFULLY", style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("ERR_LOG_MEAL: $e", style: GoogleFonts.firaCode(fontSize: 12)),
          ),
        );
      }
    }
  }

  void _applyPreset(Preset preset) {
    setState(() {
      _nameController.text = preset.name;
      _caloriesController.text = preset.calories.toStringAsFixed(0);
      _proteinController.text = preset.proteinGrams.toStringAsFixed(0);
      _carbsController.text = preset.carbohydratesGrams.toStringAsFixed(0);
      _fatController.text = preset.fatGrams.toStringAsFixed(0);
    });
  }

  Future<void> _deletePreset(String id) async {
    try {
      await _apiService.deletePreset(id);
      _loadPresets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_DELETE_PRESET: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTheme.darkTheme.textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "MANUAL_ENTRY",
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject Name
            Text("MEAL_NAME", style: textTheme.labelMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: GoogleFonts.firaSans(color: AppTheme.ghostWhite, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Enter meal name...",
                prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 32),

            // Macro Quick Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("NUTRITION_FACTS", style: textTheme.labelMedium),
                TextButton.icon(
                  onPressed: _saveAsPreset,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: Text("SAVE_AS_FAVORITE", style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.primary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildMacroField("CALORIES", "KCAL", _caloriesController)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMacroField("PROTEIN", "G", _proteinController)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildMacroField("CARBS", "G", _carbsController)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMacroField("FAT", "G", _fatController)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Presets
            Text("YOUR_FAVORITES", style: textTheme.labelMedium),
            const SizedBox(height: 16),
            if (_isLoadingPresets)
              const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            else if (_presets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    "NO_FAVORITES_FOUND",
                    style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.secondary.withOpacity(0.5)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  return _buildPresetItem(preset);
                },
              ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _executeLog,
                child: const Text("LOG_MEAL"),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroField(String label, String unit, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            fillColor: Colors.transparent,
            suffixText: unit,
            suffixStyle: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.outlineVariant)),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetItem(Preset preset) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withOpacity(0.5),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => _applyPreset(preset),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text("DELETE_PRESET", style: GoogleFonts.firaCode(color: Colors.redAccent, fontSize: 16)),
              content: Text("PERMANENTLY_PURGE_${preset.name.toUpperCase()}?", style: GoogleFonts.firaCode(fontSize: 12)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("CANCEL", style: GoogleFonts.firaCode(color: AppTheme.secondary)),
                ),
                TextButton(
                  onPressed: () {
                    _deletePreset(preset.id!);
                    Navigator.pop(context);
                  },
                  child: Text("PURGE", style: GoogleFonts.firaCode(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name.toUpperCase(),
                      style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.ghostWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${preset.calories.toInt()} KCAL | ${preset.proteinGrams.toInt()}G P | ${preset.carbohydratesGrams.toInt()}G C | ${preset.fatGrams.toInt()}G F",
                      style: GoogleFonts.firaCode(fontSize: 10, color: AppTheme.secondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.outlineVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
