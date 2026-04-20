import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reconnaissance de texte sur la photo (Android / iOS).
/// Le texte est reconstruit **ligne par ligne** (blocs ML Kit) pour mieux
/// respecter la mise en page des CNIB (libellés / valeurs).
Future<String?> recognizeTextFromImagePath(String path) async {
  if (kIsWeb) return null;
  if (!Platform.isAndroid && !Platform.isIOS) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(path);
    final result = await recognizer.processImage(input);
    final lines = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) lines.add(t);
      }
    }
    if (lines.isEmpty) return result.text;
    return lines.join('\n');
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}
