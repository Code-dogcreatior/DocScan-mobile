import 'dart:typed_data';

class ScanDocumentPageItem {
  ScanDocumentPageItem({
    required this.id,
    required this.jpegBytes,
  });

  final String id;
  final Uint8List jpegBytes;
}

class ScanDocumentDraft {
  ScanDocumentDraft({required this.pages});

  final List<ScanDocumentPageItem> pages;
}
