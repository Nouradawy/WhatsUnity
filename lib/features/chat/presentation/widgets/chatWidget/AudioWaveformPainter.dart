// In your_app/lib/widgets/audio_waveform_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Paint wavePaint;

  AudioWaveformPainter({
    required this.amplitudes,
    required Color waveColor, // Require color to be passed in
  }) : wavePaint = Paint()
    ..color = waveColor
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;


    // THE OPTIMIZATION: Create a single path object.
    final Path wavePath = Path();

    // Define the dB range for normalization
    const double minDb = -60.0;
    const double maxDb = 0.0;
    const double dbRange = maxDb - minDb;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    final double barWidth = width / (amplitudes.length * 2 - 1);
    final double spacing = barWidth;
    double currentX = 0;

    for (int i = 0; i < amplitudes.length; i++) {
      final double db = amplitudes[i];
      final double normalizedValue = ((db - minDb) / dbRange).clamp(0.0, 1.0);
      final double barHeight = normalizedValue * centerY;
      final minBarHeight = 2.0;

      final Rect barRect = Rect.fromLTWH(
        currentX,
        centerY - barHeight,
        barWidth,
        max(minBarHeight, barHeight * 2), // Ensure a minimum visible height
      );

      // INSTEAD of drawing, we add the bar to our single path.
      wavePath.addRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(10)));

      currentX += barWidth + spacing;
    }

    // AFTER the loop, draw the entire path in a single, efficient operation.
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter oldDelegate) {
    // Only repaint if the amplitudes list itself is a new object.
    return amplitudes != oldDelegate.amplitudes;
  }
}