import 'dart:typed_data';

/// Web 等无 `dart:io` 的平台：不从磁盘加载 ONNX。
Future<Uint8List?> tryReadOnnxFile(String directoryPath, String fileName) async =>
    null;
