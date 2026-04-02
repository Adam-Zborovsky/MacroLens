import 'package:flutter/material.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import '../../core/theme/app_theme.dart';

/// NotchedHapticSlider
/// A precision weight-adjustment slider that fires a haptic impact on every
/// 5g notch crossing. Designed to feel like a high-end physical dial.
/// Visual: custom track with notch markers + a JetBrains Mono value display.
class NotchedHapticSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double notchInterval;
  final ValueChanged<double> onChanged;

  const NotchedHapticSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.notchInterval = 5.0,
    required this.onChanged,
  });

  @override
  State<NotchedHapticSlider> createState() => _NotchedHapticSliderState();
}

class _NotchedHapticSliderState extends State<NotchedHapticSlider>
    with SingleTickerProviderStateMixin {
  late double _currentValue;
  double? _lastNotchValue;

  // Thumb scale animation on press
  late AnimationController _thumbScaleController;
  late Animation<double> _thumbScaleAnim;

  @override
  void initState() {
    super.initState();
    _currentValue   = widget.value;
    _lastNotchValue = _snapToNotch(widget.value);
    _thumbScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _thumbScaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _thumbScaleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(NotchedHapticSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  void dispose() {
    _thumbScaleController.dispose();
    super.dispose();
  }

  double _snapToNotch(double value) {
    return (value / widget.notchInterval).round() * widget.notchInterval;
  }

  void _onSliderChanged(double raw) {
    final snapped = _snapToNotch(raw);

    // Fire haptic + callback only when crossing a notch boundary
    if (_lastNotchValue == null || (snapped - _lastNotchValue!).abs() >= widget.notchInterval * 0.5) {
      FlutterHapticFeedback.impact(ImpactFeedbackStyle.light);
      _lastNotchValue = snapped;
      _currentValue   = snapped;
      widget.onChanged(snapped);
    } else {
      setState(() => _currentValue = raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snappedDisplay = _snapToNotch(_currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mass readout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                style: MLTextStyles.dataLarge,
                children: [
                  TextSpan(text: snappedDisplay.round().toString()),
                  TextSpan(
                    text: ' g',
                    style: MLTextStyles.dataMedium.copyWith(color: MLColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '${widget.min.round()}g — ${widget.max.round()}g',
              style: MLTextStyles.dataSmall,
            ),
          ],
        ),
        const SizedBox(height: MLSpacing.sm),
        // Custom-painted slider
        SizedBox(
          height: 44,
          child: GestureDetector(
            onHorizontalDragStart: (_) => _thumbScaleController.forward(),
            onHorizontalDragEnd:   (_) => _thumbScaleController.reverse(),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor:   MLColors.accentCyan,
                inactiveTrackColor: MLColors.border,
                thumbColor:         MLColors.accentCyan,
                overlayColor:       MLColors.accentCyanGlow,
                thumbShape: _NotchedThumbShape(scaleAnimation: _thumbScaleAnim),
                trackShape: _NotchedTrackShape(
                  notchInterval: widget.notchInterval,
                  min: widget.min,
                  max: widget.max,
                ),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _currentValue.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                onChanged: _onSliderChanged,
              ),
            ),
          ),
        ),
        // Notch labels (minor, every 50g)
        _NotchLabels(min: widget.min, max: widget.max, interval: 50),
      ],
    );
  }
}

// ─── Custom track with notch tick marks ──────────────────────────────────────

class _NotchedTrackShape extends RoundedRectSliderTrackShape {
  final double notchInterval;
  final double min;
  final double max;

  const _NotchedTrackShape({
    required this.notchInterval,
    required this.min,
    required this.max,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context, offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
    );

    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final notchPaint = Paint()
      ..color = MLColors.textDim
      ..strokeWidth = 1.0;
    final majorPaint = Paint()
      ..color = MLColors.textMuted
      ..strokeWidth = 1.5;

    final range = max - min;
    final step = notchInterval;
    final totalNotches = (range / step).floor();

    for (int i = 0; i <= totalNotches; i++) {
      final value    = min + i * step;
      final fraction = (value - min) / range;
      final x        = trackRect.left + fraction * trackRect.width;

      final isMajor = (value % 50 == 0);
      final tickH   = isMajor ? 8.0 : 5.0;
      final paint   = isMajor ? majorPaint : notchPaint;

      canvas.drawLine(
        Offset(x, trackRect.center.dy - tickH / 2),
        Offset(x, trackRect.center.dy + tickH / 2),
        paint,
      );
    }
  }
}

// ─── Custom thumb ─────────────────────────────────────────────────────────────

class _NotchedThumbShape extends SliderComponentShape {
  final Animation<double> scaleAnimation;
  static const double _baseRadius = 10.0;

  const _NotchedThumbShape({required this.scaleAnimation});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_baseRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final scale  = scaleAnimation.value;
    final radius = _baseRadius * scale;

    // Outer glow
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()..color = MLColors.accentCyanGlow,
    );
    // Main thumb
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = MLColors.accentCyan,
    );
    // Inner dot
    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = Colors.black,
    );
  }
}

// ─── Notch labels ─────────────────────────────────────────────────────────────

class _NotchLabels extends StatelessWidget {
  final double min;
  final double max;
  final double interval;

  const _NotchLabels({required this.min, required this.max, required this.interval});

  @override
  Widget build(BuildContext context) {
    final labels = <String>[];
    for (double v = min; v <= max; v += interval) {
      labels.add('${v.round()}g');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((l) => Text(l, style: MLTextStyles.dataSmall.copyWith(fontSize: 9)))
          .toList(),
    );
  }
}
