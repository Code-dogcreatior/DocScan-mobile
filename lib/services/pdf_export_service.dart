import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  Future<File> exportJpegPages({
    required List<Uint8List> pages,
    String fileNamePrefix = 'DocScan',
  }) async {
    if (pages.isEmpty) {
      throw StateError('没有可导出的页面');
    }
    final doc = pw.Document();
    for (final p in pages) {
      final image = pw.MemoryImage(p);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/$fileNamePrefix-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
