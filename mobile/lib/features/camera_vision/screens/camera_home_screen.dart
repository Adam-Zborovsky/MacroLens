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
import 'package:macro_lens_mobile/features/detective_refinement/screens/meal_review_screen.dart';
import 'package:macro_lens_mobile/features/nutrition_dashboard/screens/dashboard_screen.dart';
import 'package:macro_lens_mobile/features/manual_entry/screens/manual_entry_screen.dart';
import 'package:macro_lens_mobile/features/meal_history/screens/meal_history_screen.dart';
import 'package:macro_lens_mobile/features/camera_vision/screens/barcode_scanner_screen.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_keys.dart';
import 'package:macro_lens_mobile/features/auth/tutorial_service.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isMultiAngleMode = false;
  bool _isShutterPressed = false;
  XFile? _capturedImage;
  final List<XFile> _multiAngleImages = [];
  FlashMode _flashMode = FlashMode.off;
  final ApiService _apiService = ApiService();
  
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  bool _tutorialScheduled = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    if (!kIsWeb) _cleanupOldCaptures();
    _checkTutorial();
    
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(_flashController);
  }

  Future<void> _checkTutorial() async {
    if (_tutorialScheduled) return;
    try {
      final user = await _apiService.fetchCurrentUser();
      // We use a different flag or check if dashboard tutorial is done
      // For simplicity, let's assume camera tutorial is part of the same "hasSeenTutorial"
      // But we only show it here if they've seen the dashboard one? 
      // Actually, let's just show it if they haven't seen tutorial yet.
      final bool hasSeenTutorial = user['hasSeenTutorial'] ?? false;
      
      if (!hasSeenTutorial && mounted) {
        _tutorialScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTutorial();
        });
      }
    } catch (e) {
      debugPrint("ERR_CHECK_TUTORIAL: $e");
    }
  }

  void _showTutorial() {
    final tutorial = TutorialService.createTutorial(
      context: context,
      targets: TutorialService.getCameraTargets(),
      onFinish: () async {
        try {
          // Marking as seen only if they finish the whole flow might be better
          // but for now let's just mark it.
          await _apiService.updateProfile({'hasSeenTutorial': true});
        } catch (e) {
          debugPrint("ERR_UPDATE_TUTORIAL_STATUS: $e");
        }
      },
    );
    tutorial.show(context: context);
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
      // Find all back cameras
      List<CameraDescription> backCameras = _cameras!.where((c) => c.lensDirection == CameraLensDirection.back).toList();
      
      // On many modern devices, the first back camera might be the ultra-wide (0.5x).
      // The main camera is often the one at index 0 or sometimes we need to set the zoom level.
      // We'll pick the first back camera and explicitly set zoom to 1.0 if possible.
      final selectedCamera = backCameras.isNotEmpty ? backCameras[0] : _cameras![0];

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      // Ensure we are at 1.0x zoom (to avoid starting on ultra-wide 0.5x if that's the default)
      try {
        double minZoom = await _controller!.getMinZoomLevel();
        double maxZoom = await _controller!.getMaxZoomLevel();
        // If min zoom is less than 1.0 (e.g. 0.5), explicitly set it to 1.0
        if (minZoom < 1.0 && maxZoom >= 1.0) {
          await _controller!.setZoomLevel(1.0);
        }
      } catch (e) {
        debugPrint("ZOOM_INIT_ERR: $e");
      }

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

      // 2. Capture
      final image = await _controller!.takePicture();
      
      if (_isMultiAngleMode) {
        setState(() {
          _multiAngleImages.add(image);
        });
        // Save locally in background
        if (!kIsWeb) _saveImageLocally(image);
      } else {
        _processImages([image]);
      }
    } catch (e) {
      if (mounted) _showDiagnosticError(e.toString());
    }
  }

  void _onPickFromGallery() async {
    if (_isScanning) return;
    
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        if (_isMultiAngleMode) {
          setState(() {
            _multiAngleImages.add(image);
          });
        } else {
          _processImages([image]);
        }
      }
    } catch (e) {
      if (mounted) _showDiagnosticError(e.toString());
    }
  }

  void _processImages(List<XFile> images) async {
    try {
      setState(() {
        _isScanning = true;
        if (!_isMultiAngleMode) _capturedImage = images.first;
      });

      // 1. Save Locally (skipped on web)
      if (!kIsWeb && !_isMultiAngleMode) {
        final localPath = await _saveImageLocally(images.first);
        if (localPath != null) debugPrint("SPECIMEN_SAVED_AT: $localPath");
      }

      // 2. Convert to Base64 for API
      List<String> base64Images = [];
      for (var img in images) {
        final bytes = await img.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

      // 3. Upload to Backend (Analysis only, not saved yet)
      final response = await _apiService.uploadCapture(base64Images);
      
      // response['caseFile'] is now transient meal data
      final transientMeal = Meal.fromJson(response['caseFile']);
      final captureId = response['capture']['_id'];
      
      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _capturedImage = null; // Unfreeze UI
        _multiAngleImages.clear();
      });

      // 4. Navigate to Meal Review Screen
      if (transientMeal.detectedItems.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealReviewScreen(
              initialMeal: transientMeal,
              captureId: captureId,
            ),
          ),
        );
      } else {
        // Handle case where no food is detected
        if (mounted) {
           _showDiagnosticError("ERR_NO_FOOD_DETECTED");
        }
      }

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
    String diagnostic = "TRY_AGAIN";
    if (error.contains("ERR_NO_FOOD_DETECTED")) {
      diagnostic = "NO_FOOD_FOUND\nTRY_BETTER_LIGHT_OR_CENTER_ITEM";
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
            Text("ERROR", style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 12)),
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

          // 4. Multi-Angle Thumbnails
          if (_isMultiAngleMode && _multiAngleImages.isNotEmpty && !_isScanning)
            _buildMultiAngleThumbnails(),

          // 5. Minimalist UI Overlays
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MinimalIconButton(
                  isActive: _flashMode == FlashMode.torch,
                  label: "FLASH",
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
                  isActive: _isMultiAngleMode,
                  icon: _isMultiAngleMode ? Icons.layers_rounded : Icons.layers_outlined,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isMultiAngleMode = !_isMultiAngleMode;
                      if (!_isMultiAngleMode) _multiAngleImages.clear();
                    });
                  },
                  label: "MULTI",
                ),
                _MinimalIconButton(
                  label: "SCAN",
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () async {
                    if (_controller != null && _controller!.value.isStreamingImages) {
                      await _controller!.stopImageStream();
                    }
                    await _controller?.dispose();
                    setState(() {
                      _isInitialized = false;
                      _controller = null;
                    });
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                    );
                    _initializeCamera();
                  },
                ),
                _MinimalIconButton(
                  key: TutorialKeys.cameraGallery,
                  label: "GALLERY",
                  icon: Icons.photo_library_rounded,
                  onPressed: _onPickFromGallery,
                ),
                _MinimalIconButton(
                  key: TutorialKeys.cameraHistory,
                  label: "HISTORY",
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
                  key: TutorialKeys.cameraHome,
                  icon: Icons.dashboard_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  ),
                  label: "HOME",
                ),
                // Modern Shutter Button
                _buildModernShutter(key: TutorialKeys.cameraShutter),
                _MinimalIconButton(
                  key: TutorialKeys.cameraManual,
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

  Widget _buildModernShutter({Key? key}) {
    return GestureDetector(
      key: key,
      onTapDown: (_) => setState(() => _isShutterPressed = true),
      onTapUp: (_) => setState(() => _isShutterPressed = false),
      onTapCancel: () => setState(() => _isShutterPressed = false),
      onTap: _onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isShutterPressed ? AppTheme.primary : Colors.white.withOpacity(0.5), 
            width: _isShutterPressed ? 4 : 2,
          ),
        ),
        child: AnimatedScale(
          scale: _isShutterPressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _isScanning 
                  ? Colors.white.withOpacity(0.2) 
                  : (_isShutterPressed ? AppTheme.primary : Colors.white),
              shape: BoxShape.circle,
              boxShadow: [
                if (!_isScanning)
                  BoxShadow(
                    color: (_isShutterPressed ? AppTheme.primary : Colors.white).withOpacity(0.3),
                    blurRadius: _isShutterPressed ? 25 : 15,
                    spreadRadius: _isShutterPressed ? 5 : 2,
                  ),
              ],
            ),
            child: _isScanning 
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiAngleThumbnails() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _multiAngleImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(_multiAngleImages[index].path, width: 80, height: 80, fit: BoxFit.cover)
                            : Image.file(File(_multiAngleImages[index].path), width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _multiAngleImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7), 
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _processImages(_multiAngleImages);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 8,
              shadowColor: AppTheme.primary.withOpacity(0.5),
            ),
            child: Text(
              "ANALYZE_${_multiAngleImages.length}_ANGLES",
              style: GoogleFonts.firaCode(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
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
              "ANALYZING_MEAL...",
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
  final bool isActive;

  const _MinimalIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            icon, 
            color: isActive ? AppTheme.primary : Colors.white, 
            size: 26
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            backgroundColor: isActive ? AppTheme.primary.withOpacity(0.15) : Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, // Keep forensic look
              side: BorderSide(
                color: isActive ? AppTheme.primary.withOpacity(0.5) : Colors.white10,
                width: 1,
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!,
            style: GoogleFonts.firaCode(
              color: isActive ? AppTheme.primary : Colors.white.withOpacity(0.6),
              fontSize: 8,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.5,
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
