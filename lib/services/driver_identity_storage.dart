import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copie la photo CNIB vers le stockage applicatif persistant.
Future<String?> persistCnibPhoto(String sourcePath) async {
  final src = File(sourcePath);
  if (!await src.exists()) return null;
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(dir.path, 'driver_cnib'));
  await folder.create(recursive: true);
  final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
  final destPath = p.join(
    folder.path,
    'cnib_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  await src.copy(destPath);
  return destPath;
}
