// Create this new file, e.g., in chatWidget/UploadProgressMessage.dart
import 'dart:io';
import 'package:flutter/material.dart';

class UploadProgressMessage extends StatelessWidget {
  final String filePath;
  final double progress;

  const UploadProgressMessage({
    super.key,
    required this.filePath,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Local image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(filePath),
                fit: BoxFit.cover,
              ),
            ),
            // Translucent overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}