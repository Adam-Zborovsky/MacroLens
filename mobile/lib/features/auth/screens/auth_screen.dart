import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/features/camera_vision/screens/camera_home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ApiService _apiService = ApiService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  void _executeAccess() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isLogin) {
        await _apiService.login(_emailController.text, _passwordController.text);
      } else {
        await _apiService.signup(_emailController.text, _passwordController.text);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CameraHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ACCESS_DENIED: ${e.toString().replaceAll('Exception: ', '')}", 
              style: GoogleFonts.firaCode(fontSize: 10)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Scanning Grid (Subtle)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: GridPainter()),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 48),

                  // Access Card (Glassmorphism)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow.withOpacity(0.8),
                      border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin ? "IDENTITY_VERIFICATION" : "NEW_SUBJECT_REGISTRATION",
                          style: AppTheme.darkTheme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 24),
                        _buildField("EMAIL_ADDRESS", _emailController, false),
                        const SizedBox(height: 20),
                        _buildField("SECURITY_KEY", _passwordController, true),
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _executeAccess,
                            child: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("EXECUTE_ACCESS"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Toggle Action
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? "[ CREATE_NEW_PROFILE ]" : "[ EXISTING_SUBJECT_LOGIN ]",
                      style: GoogleFonts.firaCode(
                        color: AppTheme.primary.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(Icons.security_rounded, size: 48, color: AppTheme.primary),
        const SizedBox(height: 16),
        Text(
          "ACCESS_CONTROL",
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: AppTheme.ghostWhite,
          ),
        ),
        Text(
          "MACROLENS_LABORATORY_V2.5",
          style: GoogleFonts.firaCode(
            fontSize: 10,
            color: AppTheme.primary.withOpacity(0.6),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool obscure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.firaCode(color: AppTheme.primary, fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
