import 'package:flutter/material.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
      await _authService.signInWithGoogle();
      if (mounted) widget.onLoginSuccess();
    } catch (e) {
      setState(() { _error = e.toString(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!, style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError)),
            backgroundColor: MLColors.bgCard,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MLSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: MLSpacing.xxl),
              Text('MACROLENS', style: MLTextStyles.displayLarge.copyWith(color: MLColors.accentCyan)),
              const SizedBox(height: MLSpacing.sm),
              Text(
                'Vision-First Nutrition Laboratory',
                style: MLTextStyles.bodyMuted,
              ),
              const SizedBox(height: MLSpacing.xxl),
              Text(
                'Your meal analysis takes less time than eating it.',
                style: MLTextStyles.bodyRegular,
              ),
              const SizedBox(height: MLSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(MLSpacing.lg),
                decoration: BoxDecoration(
                  color: MLColors.bgCard,
                  borderRadius: BorderRadius.circular(MLRadius.md),
                  border: Border.all(color: MLColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ABOUT MACROLENS', style: MLTextStyles.labelCaps),
                    const SizedBox(height: MLSpacing.md),
                    _FeatureBullet('AI-powered food analysis via Gemini 2.5 Flash'),
                    const SizedBox(height: MLSpacing.sm),
                    _FeatureBullet('Precision mass adjustment (5g haptic increments)'),
                    const SizedBox(height: MLSpacing.sm),
                    _FeatureBullet('Real-time macro tracking & daily goals'),
                    const SizedBox(height: MLSpacing.sm),
                    _FeatureBullet('Forensic meal history with search'),
                  ],
                ),
              ),
              const Spacer(),
              _GoogleSignInButton(
                loading: _loading,
                onPressed: _handleGoogleSignIn,
              ),
              const SizedBox(height: MLSpacing.sm),
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy.',
                style: MLTextStyles.bodyMuted.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MLSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String text;
  const _FeatureBullet(this.text);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: MLTextStyles.bodyRegular.copyWith(color: MLColors.accentCyan)),
          Expanded(
            child: Text(text, style: MLTextStyles.bodyRegular, softWrap: true),
          ),
        ],
      );
}

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: MLColors.accentCyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MLRadius.md)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 18),
                    const SizedBox(width: MLSpacing.sm),
                    Text(
                      'SIGN IN WITH GOOGLE',
                      style: MLTextStyles.labelCaps.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      );
}
