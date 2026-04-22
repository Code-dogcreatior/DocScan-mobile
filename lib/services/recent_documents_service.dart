import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_document.dart';

/// 最近文档持久化：索引写 SharedPreferences，缩略图 + 完整页 JPEG 落磁盘。
class RecentDocumentsService {
  static const _prefKey = 'recent_documents_v1';
  static const _maxEntries = 50;

  static Future<Directory> _thumbsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/doc_thumbs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> _pagesDirForId(String id) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/docs/$id');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 保存一批扫描页：第一页作为缩略图，全部页写入 `{appDocs}/docs/{id}/{i}.jpg`。
  /// 返回新建的 [RecentDocument]，失败时静默返回 null。
  static Future<RecentDocument?> save({
    required List<Uint8List> pages,
    String? title,
  }) async {
    if (pages.isEmpty) return null;
    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final thumbsDir = await _thumbsDir();
      final thumbFile = File('${thumbsDir.path}/$id.jpg');
      await thumbFile.writeAsBytes(pages.first);

      final pagesDir = await _pagesDirForId(id);
      for (var i = 0; i < pages.length; i++) {
        await File('${pagesDir.path}/$i.jpg').writeAsBytes(pages[i]);
      }

      final totalBytes = pages.fold<int>(0, (s, p) => s + p.length);
      final now = DateTime.now();
      final doc = RecentDocument(
        id: id,
        title: title ??
            '扫描件 ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        createdAt: now,
        thumbnailPath: thumbFile.path,
        pageCount: pages.length,
        sizeBytes: totalBytes,
        pagesDir: pagesDir.path,
      );

      final prefs = await SharedPreferences.getInstance();
      final existing = _load(prefs);
      final updated = [doc, ...existing].take(_maxEntries).toList();
      await prefs.setString(_prefKey, RecentDocument.encodeList(updated));
      return doc;
    } catch (_) {
      return null;
    }
  }

  /// 追加页到已有文档（不改 id / createdAt），更新 pageCount/sizeBytes。
  /// 用于 DocumentDetailPage「继续拍摄」场景。
  static Future<RecentDocument?> appendPages({
    required String id,
    required List<Uint8List> pages,
  }) async {
    if (pages.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _load(prefs);
      final idx = list.indexWhere((d) => d.id == id);
      if (idx < 0) return null;
      final doc = list[idx];
      if (!doc.hasFullPages) return null;
      final dir = Directory(doc.pagesDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final startIdx = doc.pageCount;
      for (var i = 0; i < pages.length; i++) {
        await File('${dir.path}/${startIdx + i}.jpg').writeAsBytes(pages[i]);
      }
      final addedBytes = pages.fold<int>(0, (s, p) => s + p.length);
      final updatedDoc = RecentDocument(
        id: doc.id,
        title: doc.title,
        createdAt: doc.createdAt,
        thumbnailPath: doc.thumbnailPath,
        pageCount: doc.pageCount + pages.length,
        sizeBytes: doc.sizeBytes + addedBytes,
        pagesDir: doc.pagesDir,
      );
      final next = List<RecentDocument>.from(list)..[idx] = updatedDoc;
      await prefs.setString(_prefKey, RecentDocument.encodeList(next));
      return updatedDoc;
    } catch (_) {
      return null;
    }
  }

  /// 读取最近文档列表，按 [createdAt] 倒序；缺失缩略图的条目自动过滤。
  static Future<List<RecentDocument>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _load(prefs)
          .where((d) => File(d.thumbnailPath).existsSync())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 加载某个文档的全部页 JPEG；`hasFullPages=false` 返回空列表。
  static Future<List<Uint8List>> loadPages(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doc = _load(prefs).firstWhere(
        (d) => d.id == id,
        orElse: () => RecentDocument(
          id: '',
          title: '',
          createdAt: _epoch,
          thumbnailPath: '',
          pageCount: 0,
          sizeBytes: 0,
        ),
      );
      if (!doc.hasFullPages) return const [];
      final out = <Uint8List>[];
      for (var i = 0; i < doc.pageCount; i++) {
        final f = File('${doc.pagesDir}/$i.jpg');
        if (!f.existsSync()) break;
        out.add(await f.readAsBytes());
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 重命名文档（仅改 title）。
  static Future<void> rename(String id, String newTitle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _load(prefs);
      final idx = list.indexWhere((d) => d.id == id);
      if (idx < 0) return;
      final next = List<RecentDocument>.from(list)
        ..[idx] = list[idx].copyWith(title: newTitle.trim());
      await prefs.setString(_prefKey, RecentDocument.encodeList(next));
    } catch (_) {}
  }

  /// 删除指定条目：缩略图 + 完整页目录 + 索引记录一并清理。
  static Future<void> delete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _load(prefs);
      final doc = list.firstWhere(
        (d) => d.id == id,
        orElse: () => RecentDocument(
          id: '',
          title: '',
          createdAt: _epoch,
          thumbnailPath: '',
          pageCount: 0,
          sizeBytes: 0,
        ),
      );
      final updated = list.where((d) => d.id != id).toList();
      await prefs.setString(_prefKey, RecentDocument.encodeList(updated));
      // 缩略图
      final thumbsDir = await _thumbsDir();
      final tf = File('${thumbsDir.path}/$id.jpg');
      if (tf.existsSync()) tf.deleteSync();
      // 完整页目录
      if (doc.hasFullPages) {
        final pd = Directory(doc.pagesDir);
        if (pd.existsSync()) pd.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  /// 清空全部文档。
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _load(prefs);
      await prefs.remove(_prefKey);
      final thumbsDir = await _thumbsDir();
      for (final doc in list) {
        final tf = File(doc.thumbnailPath);
        if (tf.existsSync()) tf.deleteSync();
        if (doc.hasFullPages) {
          final pd = Directory(doc.pagesDir);
          if (pd.existsSync()) pd.deleteSync(recursive: true);
        }
      }
      final _ = thumbsDir; // 保留目录本身
    } catch (_) {}
  }

  static List<RecentDocument> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    return RecentDocument.decodeList(raw);
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}
