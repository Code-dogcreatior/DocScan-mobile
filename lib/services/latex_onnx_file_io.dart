import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// 从 [directoryPath] 读取 [fileName]（完整路径 = join）。
Future<Uint8List?> tryReadOnnxFile(String directoryPath, String fileName) async {
  final file = File(p.join(directoryPath, fileName));
  if (!await file.exists()) {
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.length < 1024) {
    return null;
  }
  return bytes;
}
