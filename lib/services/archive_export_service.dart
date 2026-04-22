import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// 把多张 JPEG 页打包成单个 ZIP，写入临时目录返回 [File]。
class ArchiveExportService {
  Future<File> exportPagesAsZip({
    required List<Uint8List> pages,
    required String fileNamePrefix,
  }) async {
    if (pages.isEmpty) {
      throw StateError('没有可打包的页面');
    }
    final archive = Archive();
    final pad = pages.length.toString().length;
    for (var i = 0; i < pages.length; i++) {
      final name = '${(i + 1).toString().padLeft(pad, '0')}.jpg';
      archive.addFile(ArchiveFile(name, pages[i].length, pages[i]));
    }
    final encoded = ZipEncoder().encode(archive);
    final dir = await getTemporaryDirectory();
    final safeName = fileNamePrefix.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(
      '${dir.path}/$safeName-${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }
}
