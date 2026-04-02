import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/camera_vision/viewfinder_screen.dart';
import 'features/nutrition_dashboard/dashboard_screen.dart';
import 'features/meal_history/meal_history_screen.dart';

const _kApiBaseUrl = 'http://localhost:3000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Lock to portrait — volumetric estimation calibrated for portrait angle
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final cameras = await availableCameras();

  runApp(MacroLensApp(cameras: cameras));
}

class MacroLensApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MacroLensApp({super.key, required this.cameras});

  @override
  State<MacroLensApp> createState() => _MacroLensAppState();
}

class _MacroLensAppState extends State<MacroLensApp> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroLens',
      debugShowCheckedModeBanner: false,
      theme: buildMLTheme(),
      home: StreamBuilder(
        stream: _authService.authStateChanges(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: MLColors.bgDeep,
              body: Center(
                child: CircularProgressIndicator(color: MLColors.accentCyan),
              ),
            );
          }

          // Authenticated → Shell
          if (snapshot.hasData) {
            return MacroLensShell(cameras: widget.cameras, authService: _authService);
          }

          // Not authenticated → Login
          return LoginScreen(
            onLoginSuccess: () {
              // Auth state change will trigger rebuild via StreamBuilder
            },
          );
        },
      ),
    );
  }
}

/// Bottom-tab shell — 3 primary destinations (≤5 per UX nav guidelines).
class MacroLensShell extends StatefulWidget {
  final List<CameraDescription> cameras;
  final AuthService authService;

  const MacroLensShell({
    super.key,
    required this.cameras,
    required this.authService,
  });

  @override
  State<MacroLensShell> createState() => _MacroLensShellState();
}

class _MacroLensShellState extends State<MacroLensShell> {
  int _tabIndex = 1; // Default to Viewfinder (center)

  late final ApiService _apiService = ApiService(
    baseUrl: _kApiBaseUrl,
    authService: widget.authService,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          DashboardScreen(apiService: _apiService),
          ViewfinderScreen(cameras: widget.cameras, apiService: _apiService),
          MealHistoryScreen(apiService: _apiService),
        ],
      ),
      bottomNavigationBar: _MLBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _MLBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _MLBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Container(
      decoration: const BoxDecoration(
        color: MLColors.bgBase,
        border: Border(top: BorderSide(color: MLColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.bar_chart_rounded,       label: 'COMMAND', index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.camera_enhance_outlined, label: 'CAPTURE', index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.folder_outlined,         label: 'ARCHIVE', index: 2, current: currentIndex, onTap: onTap),
              _MenuButton(authService: authService),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? MLColors.accentCyan : MLColors.textDim,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: MLTextStyles.dataSmall.copyWith(
                fontSize: 8,
                color: isActive ? MLColors.accentCyan : MLColors.textDim,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MLColors.bgDeep,
        body: Center(child: Text(label, style: MLTextStyles.labelCaps)),
      );
}

class _MenuButton extends StatelessWidget {
  final AuthService authService;
  const _MenuButton({required this.authService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 56),
          items: [
            PopupMenuItem(
              child: const Text('Sign Out'),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
              },
            ),
          ],
        );
      },
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, color: MLColors.textDim, size: 22),
            const SizedBox(height: 2),
            Text('MENU', style: MLTextStyles.dataSmall.copyWith(fontSize: 8, color: MLColors.textDim, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}
