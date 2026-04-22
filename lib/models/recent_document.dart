import 'dart:convert';

class RecentDocument {
  const RecentDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.thumbnailPath,
    required this.pageCount,
    required this.sizeBytes,
    this.pagesDir = '',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String thumbnailPath;
  final int pageCount;
  final int sizeBytes;

  /// 存放完整页 JPEG 的目录（`0.jpg ... N-1.jpg`）。
  /// 空串表示老版本条目，仅有缩略图，不能重新打开多页。
  final String pagesDir;

  bool get hasFullPages => pagesDir.isNotEmpty;

  RecentDocument copyWith({String? title}) => RecentDocument(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        thumbnailPath: thumbnailPath,
        pageCount: pageCount,
        sizeBytes: sizeBytes,
        pagesDir: pagesDir,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'thumbnailPath': thumbnailPath,
        'pageCount': pageCount,
        'sizeBytes': sizeBytes,
        'pagesDir': pagesDir,
      };

  factory RecentDocument.fromJson(Map<String, dynamic> json) => RecentDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        thumbnailPath: json['thumbnailPath'] as String,
        pageCount: json['pageCount'] as int,
        sizeBytes: json['sizeBytes'] as int,
        pagesDir: (json['pagesDir'] as String?) ?? '',
      );

  static RecentDocument? tryFromJson(Map<String, dynamic> json) {
    try {
      return RecentDocument.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static String encodeList(List<RecentDocument> docs) =>
      jsonEncode(docs.map((d) => d.toJson()).toList());

  static List<RecentDocument> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RecentDocument.tryFromJson)
          .whereType<RecentDocument>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
