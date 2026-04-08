import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_keys.dart';
import 'package:macro_lens_mobile/features/auth/screens/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _apiService.fetchCurrentUser();
      setState(() {
        _nameController.text = user['displayName'] ?? '';
        _emailController.text = user['email'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_FETCH_PROFILE: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      final Map<String, dynamic> updates = {
        'displayName': _nameController.text,
        'email': _emailController.text,
      };
      if (_passwordController.text.isNotEmpty) {
        updates['password'] = _passwordController.text;
      }
      
      await _apiService.updateProfile(updates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PROFILE_MODIFIED_SUCCESSFULLY", style: GoogleFonts.firaCode(fontSize: 10)),
            backgroundColor: AppTheme.primaryContainer,
          ),
        );
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_UPDATE_PROFILE: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _restartTutorial() async {
    HapticFeedback.heavyImpact();
    try {
      await _apiService.updateProfile({'hasSeenTutorial': false});
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("TUTORIAL_RESTARTED", style: GoogleFonts.firaCode(fontSize: 10)),
            backgroundColor: AppTheme.primaryContainer,
          ),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERR_RESTART_TUTORIAL: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _logout() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("USER_PROFILE", 
          style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("ACCOUNT_DETAILS"),
                const SizedBox(height: 24),
                _buildField("NAME", _nameController, false),
                const SizedBox(height: 20),
                _buildField("EMAIL", _emailController, false),
                const SizedBox(height: 20),
                _buildField("NEW_PASSWORD", _passwordController, true, hint: "LEAVE_EMPTY_TO_KEEP_SAME"),
                
                const SizedBox(height: 48),
                _buildSectionTitle("TUTORIAL_SETTINGS"),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: TutorialKeys.profileRestart,
                    onPressed: _restartTutorial,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("RESTART_TUTORIAL"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: BorderSide(color: AppTheme.outlineVariant.withOpacity(0.3)),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("SAVE_CHANGES"),
                  ),
                ),
                
                const SizedBox(height: 64),
                
                Center(
                  child: TextButton(
                    onPressed: _logout,
                    child: Text("[ LOG_OUT ]", 
                      style: GoogleFonts.firaCode(color: Colors.redAccent.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.darkTheme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Container(height: 1, width: 40, color: AppTheme.primary),
      ],
    );
  }


  Widget _buildField(String label, TextEditingController controller, bool obscure, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondary,
            letterSpacing: 1,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: GoogleFonts.firaCode(fontSize: 8, color: AppTheme.secondary.withOpacity(0.5))),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.firaCode(color: AppTheme.ghostWhite, fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
