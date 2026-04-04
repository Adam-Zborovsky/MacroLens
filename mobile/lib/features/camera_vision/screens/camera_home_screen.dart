import 'dart:convert';
import 'dart:io' show Directory, File, FileSystemEntity;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:macro_lens_mobile/core/services/api_service.dart';
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/features/detective_refinement/screens/refinement_modal.dart';
import 'package:macro_lens_mobile/features/nutrition_dashboard/screens/dashboard_screen.dart';
import 'package:macro_lens_mobile/features/manual_entry/screens/manual_entry_screen.dart';
import 'package:macro_lens_mobile/features/meal_history/screens/meal_history_screen.dart';
import 'package:macro_lens_mobile/features/camera_vision/screens/barcode_scanner_screen.dart';

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isScanning = false;
  XFile? _capturedImage;
  FlashMode _flashMode = FlashMode.off;
  final ApiService _apiService = ApiService();
  
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    if (!kIsWeb) _cleanupOldCaptures();
    
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(_flashController);
  }

  Future<void> _cleanupOldCaptures() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String path = p.join(directory.path, 'captures');
      final dir = Directory(path);
      if (!await dir.exists()) return;

      final List<FileSystemEntity> files = await dir.list().toList();
      final now = DateTime.now();
      int deletedCount = 0;

      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (now.difference(stat.modified).inDays >= 7) {
            await file.delete();
            deletedCount++;
          }
        }
      }
      if (deletedCount > 0) debugPrint("SHREDDED_${deletedCount}_OLD_SPECIMENS");
    } catch (e) {
      debugPrint("CLEANUP_ERR: $e");
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Future<String?> _saveImageLocally(XFile image) async {
    if (kIsWeb) return null; // No local disk saving on web
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String path = p.join(directory.path, 'captures');
      await Directory(path).create(recursive: true);
      
      final String fileName = 'ML_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = p.join(path, fileName);
      
      await File(image.path).copy(localPath);
      return localPath;
    } catch (e) {
      debugPrint("LOCAL_SAVE_ERR: $e");
      return null;
    }
  }

  void _onCapture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isScanning) return;

    try {
      HapticFeedback.heavyImpact();
      
      // 1. Trigger Flash Animation
      _flashController.forward(from: 0.0);

      // 2. Capture and Freeze
      final image = await _controller!.takePicture();
      
      setState(() {
        _capturedImage = image;
        _isScanning = true;
      });

      // 3. Save Locally (skipped on web)
      if (!kIsWeb) {
        final localPath = await _saveImageLocally(image);
        if (localPath != null) debugPrint("SPECIMEN_SAVED_AT: $localPath");
      }

      // 4. Convert to Base64 for API
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 5. Upload to Backend
      final response = await _apiService.uploadCapture(base64Image);
      final meal = Meal.fromJson(response['caseFile']);
      
      if (!mounted) return;

      setState(() {
        _isScanning = false;
      });

      // 6. Show Refinement Modal
      if (meal.detectedItems.isNotEmpty) {
        final activeItem = meal.detectedItems[0];
        
        RefinementModal.show(
          context,
          item: activeItem,
          alternatives: activeItem.alternativeCandidates,
          onSave: (updatedItem) async {
            HapticFeedback.lightImpact();
            try {
              await _apiService.saveMeal(meal.id!, updatedItem);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("CASE_FILE_#${meal.id!.substring(0, 8)}_LOGGED_SUCCESSFULLY", style: GoogleFonts.firaCode(fontSize: 10)),
                    backgroundColor: AppTheme.primaryContainer,
                  ),
                );
              }
            } catch (e) {
              if (mounted) _showDiagnosticError(e.toString());
            }
          },
        );
      }

      setState(() {
        _capturedImage = null;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _capturedImage = null;
        });
        _showDiagnosticError(e.toString());
      }
    }
  }

  void _showDiagnosticError(String error) {
    String diagnostic = "ERR_VISUAL_OBSCURED";
    if (error.contains("ERR_NO_FOOD_DETECTED")) {
      diagnostic = "ERR_ZERO_SPECIMENS_DETECTED\nADVICE: IMPROVE_LIGHTING_OR_CENTER_ITEM";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("DIAGNOSTIC_FAILURE", style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(diagnostic, style: GoogleFonts.firaCode(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 1)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder (or Frozen Image)
          if (_capturedImage != null)
            kIsWeb 
              ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
              : Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
          else
            CameraPreview(_controller!),

          // 2. Technical Reticle Overlay
          const ReticleOverlay(),

          // 3. Scanning Animation Overlay (Laser Sweep)
          if (_isScanning) IgnorePointer(child: _buildScanningOverlay()),

          // 4. Minimalist UI Overlays
          _buildMinimalistUI(),

          // 5. Shutter Flash Effect
          IgnorePointer(
            child: FadeTransition(
              opacity: _flashAnimation,
              child: Container(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // Top Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MinimalIconButton(
                  icon: _flashMode == FlashMode.torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  onPressed: () async {
                    if (_controller == null) return;
                    HapticFeedback.lightImpact();
                    final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
                    await _controller!.setFlashMode(newMode);
                    setState(() {
                      _flashMode = newMode;
                    });
                  },
                ),
                _MinimalIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                  ),
                ),
                _MinimalIconButton(
                  icon: Icons.history_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MealHistoryScreen()),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Bottom Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MinimalIconButton(
                  icon: Icons.dashboard_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  ),
                  label: "DASHBOARD",
                ),
                // Modern Shutter Button
                _buildModernShutter(),
                _MinimalIconButton(
                  icon: Icons.edit_note_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManualEntryScreen()),
                  ),
                  label: "MANUAL",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernShutter() {
    return GestureDetector(
      onTap: _onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        ),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _isScanning ? Colors.white.withOpacity(0.2) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              if (!_isScanning)
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: _isScanning 
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : null,
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Stack(
      children: [
        Container(color: Colors.black.withOpacity(0.3)),
        const _LaserSweep(),
        Positioned(
          bottom: 150,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "ANALYZING_METABOLIC_DATA",
              style: GoogleFonts.firaCode(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LaserSweep extends StatefulWidget {
  const _LaserSweep();

  @override
  State<_LaserSweep> createState() => _LaserSweepState();
}

class _LaserSweepState extends State<_LaserSweep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _controller.value,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0),
                  AppTheme.primary,
                  AppTheme.primary.withOpacity(0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MinimalIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  const _MinimalIconButton({
    required this.icon,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: GoogleFonts.firaCode(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class ReticleOverlay extends StatelessWidget {
  const ReticleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: ReticlePainter(),
        child: Container(),
      ),
    );
  }
}

class ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    const reticleSize = 250.0;

    final rect = Rect.fromCenter(center: center, width: reticleSize, height: reticleSize);
    
    const cornerLen = 15.0;
    // Top Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLen, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLen), paint);
    // Top Right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLen, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLen), paint);
    // Bottom Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLen, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLen), paint);
    // Bottom Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLen, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLen), paint);

    const textPainter = TextExtentPainter(
      text: "MODE: OPTICAL_DETECTION\nANG: 45.0°",
    );
    textPainter.paint(canvas, Offset(rect.left, rect.bottom + 10));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TextExtentPainter {
  final String text;
  const TextExtentPainter({required this.text});

  void paint(Canvas canvas, Offset offset) {
    final textSpan = TextSpan(
      text: text,
      style: GoogleFonts.firaCode(
        color: AppTheme.primary.withOpacity(0.5),
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }
}
