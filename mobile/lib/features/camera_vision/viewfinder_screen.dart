import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../detective_refinement/detective_overlay.dart';

enum ViewfinderMode { vision, barcode }
enum ScanState { ready, scanning, verified, failed }

class ViewfinderScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ApiService apiService;

  const ViewfinderScreen({
    super.key,
    required this.cameras,
    required this.apiService,
  });

  @override
  State<ViewfinderScreen> createState() => _ViewfinderScreenState();
}

class _ViewfinderScreenState extends State<ViewfinderScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _flashOn = false;
  bool _multiShotEnabled = false;
  int _queuedShots = 0;
  ViewfinderMode _mode = ViewfinderMode.vision;
  ScanState _scanState = ScanState.ready;

  // Animations
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;
  late AnimationController _shutterPulseController;
  late Animation<double> _shutterPulseAnim;
  late AnimationController _reticleFlashController;
  late Animation<double> _reticleFlashAnim;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _initAnimations() {
    // Scan laser sweeps top→bottom while analyzing
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Shutter button breathes when ready
    _shutterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shutterPulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _shutterPulseController, curve: Curves.easeInOut),
    );

    // Reticle flickers cyan when scanning
    _reticleFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _reticleFlashAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _reticleFlashController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    _shutterPulseController.dispose();
    _reticleFlashController.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    if (_scanState == ScanState.scanning) return;

    await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
    setState(() => _scanState = ScanState.scanning);
    _scanLineController.repeat();
    _reticleFlashController.repeat(reverse: true);

    try {
      File imageFile;
      if (_cameraReady && _cameraController != null) {
        final xFile = await _cameraController!.takePicture();
        imageFile = File(xFile.path);
      } else {
        // Simulator fallback — pick from gallery
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) {
          setState(() => _scanState = ScanState.ready);
          return;
        }
        imageFile = File(picked.path);
      }

      final result = await widget.apiService.submitCapture(imageFile);
      _scanLineController.stop();
      _reticleFlashController.stop();

      await FlutterHapticFeedback.impact(ImpactFeedbackStyle.medium);
      setState(() => _scanState = ScanState.verified);

      if (!mounted) return;

      // Open Detective Overlay bottom sheet with the returned Case File
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DetectiveOverlay(
          caseFileJson: result['caseFile'] as Map<String, dynamic>,
          apiService: widget.apiService,
        ),
      );

      if (mounted) setState(() => _scanState = ScanState.ready);
    } catch (e) {
      _scanLineController.stop();
      _reticleFlashController.stop();
      await FlutterHapticFeedback.notification(NotificationFeedbackType.error);
      setState(() => _scanState = ScanState.failed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: MLTextStyles.dataSmall.copyWith(color: MLColors.statusError),
            ),
            backgroundColor: MLColors.bgCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _scanState = ScanState.ready);
      }
    }
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
  }

  void _toggleMultiShot() {
    setState(() => _multiShotEnabled = !_multiShotEnabled);
    FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
  }

  void _toggleMode() {
    setState(() => _mode = _mode == ViewfinderMode.vision ? ViewfinderMode.barcode : ViewfinderMode.vision);
    FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: MLColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(color: MLColors.bgDeep),

          // ── Scanning laser line ─────────────────────────────────────
          if (_scanState == ScanState.scanning)
            AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) => Positioned(
                top: MediaQuery.of(context).size.height * _scanLineAnim.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      MLColors.accentCyan.withOpacity(0.8),
                      Colors.transparent,
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: MLColors.accentCyan.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Top bar (glass) ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + MLSpacing.sm,
                left: MLSpacing.md,
                right: MLSpacing.md,
                bottom: MLSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Flash toggle
                  _IconToggleButton(
                    icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                    active: _flashOn,
                    onTap: _toggleFlash,
                  ),
                  // Wordmark
                  Text(
                    'MACROLENS',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MLColors.accentCyan,
                      letterSpacing: 3.0,
                    ),
                  ),
                  // Multi-shot toggle
                  Stack(
                    children: [
                      _IconToggleButton(
                        icon: Icons.photo_library_outlined,
                        active: _multiShotEnabled,
                        onTap: _toggleMultiShot,
                      ),
                      if (_queuedShots > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: MLColors.accentCyan,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_queuedShots',
                              style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Reticle ─────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _reticleFlashAnim,
              builder: (_, __) {
                final color = _scanState == ScanState.scanning
                    ? MLColors.accentCyan.withOpacity(_reticleFlashAnim.value)
                    : _scanState == ScanState.verified
                        ? MLColors.statusVerified.withOpacity(0.8)
                        : MLColors.accentCyan.withOpacity(0.6);
                return _PrecisionReticle(
                  color: color,
                  mode: _mode,
                  isScanning: _scanState == ScanState.scanning,
                );
              },
            ),
          ),

          // ── Bottom controls (glass) ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + MLSpacing.md,
                top: MLSpacing.xl,
                left: MLSpacing.xl,
                right: MLSpacing.xl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status readout
                  _StatusReadout(scanState: _scanState),
                  const SizedBox(height: MLSpacing.lg),
                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Mode toggle
                      _ModeToggleButton(mode: _mode, onTap: _toggleMode),

                      // Shutter
                      AnimatedBuilder(
                        animation: _shutterPulseAnim,
                        builder: (_, __) => Transform.scale(
                          scale: _scanState == ScanState.ready ? _shutterPulseAnim.value : 1.0,
                          child: _ShutterButton(
                            scanState: _scanState,
                            onTap: _onCapture,
                          ),
                        ),
                      ),

                      // Dashboard nav hint
                      GestureDetector(
                        onTap: () {
                          FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
                          // TODO: navigate to Dashboard via go_router
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(MLRadius.sm),
                                border: Border.all(color: MLColors.border),
                                color: MLColors.surfaceGlass,
                              ),
                              child: const Icon(Icons.bar_chart_rounded, color: MLColors.textMuted, size: 20),
                            ),
                            const SizedBox(height: 4),
                            Text('DASHBOARD', style: MLTextStyles.dataSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reticle painter ─────────────────────────────────────────────────────────

class _PrecisionReticle extends StatelessWidget {
  final Color color;
  final ViewfinderMode mode;
  final bool isScanning;

  const _PrecisionReticle({required this.color, required this.mode, required this.isScanning});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.72;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _ReticlePainter(color: color, mode: mode)),
        ),
        const SizedBox(height: 12),
        Text(
          mode == ViewfinderMode.vision ? 'POSITION PLATE AT 45°' : 'ALIGN BARCODE IN FRAME',
          style: MLTextStyles.dataSmall.copyWith(
            color: color.withOpacity(0.8),
            letterSpacing: 1.5,
          ),
        ),
        if (isScanning) ...[
          const SizedBox(height: 8),
          Text(
            'ANALYZING COMPOSITION...',
            style: MLTextStyles.dataSmall.copyWith(
              color: MLColors.accentCyan,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  final ViewfinderMode mode;

  _ReticlePainter({required this.color, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = size.width * 0.12;
    final corners = [
      Offset(0, 0), Offset(size.width, 0),
      Offset(0, size.height), Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      final isRight  = corner.dx > 0;
      final isBottom = corner.dy > 0;
      final xDir = isRight  ? -1.0 : 1.0;
      final yDir = isBottom ? -1.0 : 1.0;

      // L-shaped corner bracket
      canvas.drawLine(corner, Offset(corner.dx + cornerLength * xDir, corner.dy), paint);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + cornerLength * yDir), paint);
    }

    // Center crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx - 8, cy), Offset(cx + 8, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), crossPaint);
    canvas.drawCircle(Offset(cx, cy), 2.5, paint..style = PaintingStyle.fill);

    if (mode == ViewfinderMode.vision) {
      // 45-degree diagonal guide lines — very subtle
      final guidePaint = Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), guidePaint);
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), guidePaint);
    } else {
      // Barcode mode: horizontal guide lines
      final barPaint = Paint()
        ..color = color.withOpacity(0.25)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(cornerLength, cy - 20), Offset(size.width - cornerLength, cy - 20), barPaint);
      canvas.drawLine(Offset(cornerLength, cy + 20), Offset(size.width - cornerLength, cy + 20), barPaint);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color || old.mode != mode;
}

// ─── Shutter button ───────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  final ScanState scanState;
  final VoidCallback onTap;

  const _ShutterButton({required this.scanState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isScanning = scanState == ScanState.scanning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isScanning ? MLColors.bgElevated : Colors.white,
          border: Border.all(
            color: isScanning ? MLColors.accentCyan : MLColors.accentCyan,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: MLColors.accentCyan.withOpacity(isScanning ? 0.6 : 0.3),
              blurRadius: isScanning ? 20 : 12,
              spreadRadius: isScanning ? 4 : 2,
            ),
          ],
        ),
        child: isScanning
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(MLColors.accentCyan),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ─── Mode toggle button ───────────────────────────────────────────────────────

class _ModeToggleButton extends StatelessWidget {
  final ViewfinderMode mode;
  final VoidCallback onTap;
  const _ModeToggleButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBarcode = mode == ViewfinderMode.barcode;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MLRadius.sm),
              border: Border.all(color: isBarcode ? MLColors.accentCyan : MLColors.border),
              color: isBarcode ? MLColors.accentCyanGlow : MLColors.surfaceGlass,
            ),
            child: Icon(
              isBarcode ? Icons.qr_code_scanner : Icons.camera_enhance_outlined,
              color: isBarcode ? MLColors.accentCyan : MLColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(isBarcode ? 'BARCODE' : 'VISION', style: MLTextStyles.dataSmall),
        ],
      ),
    );
  }
}

// ─── Icon toggle button ───────────────────────────────────────────────────────

class _IconToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _IconToggleButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? MLColors.accentCyanGlow : MLColors.surfaceGlass,
          border: Border.all(color: active ? MLColors.accentCyan : MLColors.border),
        ),
        child: Icon(icon, color: active ? MLColors.accentCyan : MLColors.textMuted, size: 18),
      ),
    );
  }
}

// ─── Status readout ────────────────────────────────────────────────────────────

class _StatusReadout extends StatelessWidget {
  final ScanState scanState;
  const _StatusReadout({required this.scanState});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (scanState) {
      ScanState.ready    => ('READY — GEMINI 2.5 FLASH', MLColors.statusVerified),
      ScanState.scanning => ('ANALYZING COMPOSITION...', MLColors.accentCyan),
      ScanState.verified => ('CASE FILE CREATED', MLColors.statusVerified),
      ScanState.failed   => ('ANALYSIS FAILED — RETRY', MLColors.statusError),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: MLSpacing.sm),
        Text(text, style: MLTextStyles.dataSmall.copyWith(color: color)),
      ],
    );
  }
}
