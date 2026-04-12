import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/features/auth/screens/auth_screen.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TutorialProvider()),
      ],
      child: const MacroLensApp(),
    ),
  );
}

class MacroLensApp extends StatelessWidget {
  const MacroLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthScreen(),
    );
  }
}
