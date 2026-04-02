import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class NotchedHapticSlider extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  const NotchedHapticSlider({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.min = 0,
    this.max = 1000,
    this.step = 5,
  });

  @override
  State<NotchedHapticSlider> createState() => _NotchedHapticSliderState();
}

class _NotchedHapticSliderState extends State<NotchedHapticSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  void _handleChanged(double value) {
    // Snap to steps
    final snappedValue = (value / widget.step).round() * widget.step;
    if (snappedValue != _currentValue) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentValue = snappedValue;
      });
      widget.onChanged(snappedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Odometer-style readout
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _currentValue.toStringAsFixed(0),
              style: GoogleFonts.firaCode(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "G",
              style: GoogleFonts.firaCode(
                fontSize: 18,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // The Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.surfaceContainerHighest,
            thumbColor: Colors.white,
            trackHeight: 2.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
            overlayColor: AppTheme.primary.withOpacity(0.1),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
            activeTickMarkColor: AppTheme.primary,
            inactiveTickMarkColor: AppTheme.surfaceBright,
          ),
          child: Slider(
            value: _currentValue,
            min: widget.min,
            max: widget.max,
            divisions: (widget.max - widget.min) ~/ widget.step,
            onChanged: _handleChanged,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("MIN", style: AppTheme.darkTheme.textTheme.bodySmall),
              Text("PRECISION_STEP: 5G", style: AppTheme.darkTheme.textTheme.bodySmall),
              Text("MAX", style: AppTheme.darkTheme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
