import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../config/app_env.dart';
import 'network_reachability.dart';

class InpaintException implements Exception {
  InpaintException(this.message, {this.debugInfo});
  final String message;
  final InpaintDebugInfo? debugInfo;

  @override
  String toString() => message;
}

class InpaintDebugInfo {
  const InpaintDebugInfo({
    required this.endpoint,
    required this.requestImageBytes,
    required this.requestImageWidth,
    required this.requestImageHeight,
    required this.requestMaskBytes,
    required this.requestMaskWidth,
    required this.requestMaskHeight,
    required this.uploadMaskBytes,
    required this.uploadMaskWidth,
    required this.uploadMaskHeight,
    required this.maskActivePixels,
    required this.maskBounds,
    required this.binaryMaskPreviewBytes,
    required this.uploadImageBytes,
    required this.uploadImageWidth,
    required this.uploadImageHeight,
    this.responseStatusCode,
    this.responseContentType,
    this.responseBytes,
    this.responseImageWidth,
    this.responseImageHeight,
    this.responseSameAsUpload,
    this.responseSameAsOriginalInput,
    this.responsePreview,
  });

  final Uri endpoint;
  final int requestImageBytes;
  final int? requestImageWidth;
  final int? requestImageHeight;
  final int requestMaskBytes;
  final int? requestMaskWidth;
  final int? requestMaskHeight;
  final int uploadMaskBytes;
  final int uploadMaskWidth;
  final int uploadMaskHeight;
  final int maskActivePixels;
  final String maskBounds;
  final Uint8List binaryMaskPreviewBytes;
  final int uploadImageBytes;
  final int uploadImageWidth;
  final int uploadImageHeight;
  final int? responseStatusCode;
  final String? responseContentType;
  final int? responseBytes;
  final int? responseImageWidth;
  final int? responseImageHeight;
  final bool? responseSameAsUpload;
  final bool? responseSameAsOriginalInput;
  final String? responsePreview;

  String toMultilineString() {
    final lines = <String>[
      'endpoint: $endpoint',
      'request.image: ${_fmtBytes(requestImageBytes)} ${_fmtSize(requestImageWidth, requestImageHeight)}',
      'request.mask: ${_fmtBytes(requestMaskBytes)} ${_fmtSize(requestMaskWidth, requestMaskHeight)}',
      'upload.mask(png): ${_fmtBytes(uploadMaskBytes)} ${_fmtSize(uploadMaskWidth, uploadMaskHeight)}',
      'mask.activePixels: $maskActivePixels',
      'mask.bounds: $maskBounds',
      'upload.image(png): ${_fmtBytes(uploadImageBytes)} ${_fmtSize(uploadImageWidth, uploadImageHeight)}',
      'response.status: ${responseStatusCode ?? '-'}',
      'response.contentType: ${responseContentType ?? '-'}',
      'response.bytes: ${responseBytes == null ? '-' : _fmtBytes(responseBytes!)}',
      'response.image: ${_fmtSize(responseImageWidth, responseImageHeight)}',
      'response.sameAsUpload: ${responseSameAsUpload ?? '-'}',
      'response.sameAsRequestInput: ${responseSameAsOriginalInput ?? '-'}',
    ];
    if (responsePreview != null && responsePreview!.isNotEmpty) {
      lines.add('response.preview: $responsePreview');
    }
    return lines.join('\n');
  }

  static String _fmtBytes(int bytes) => '$bytes B';

  static String _fmtSize(int? width, int? height) {
    if (width == null || height == null) return '-';
    return '${width}x$height';
  }
}

class InpaintService {
  InpaintService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;
  InpaintDebugInfo? lastDebugInfo;

  static String resolvedBaseUrl({String? override}) {
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return AppEnv.inpaintApiBase.trim();
  }

  Uri _endpointForBase(String base) {
    final trimmed = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/inpaint')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('$trimmed/inpaint');
  }

  Future<Uint8List> process({
    required Uint8List imageBytes,
    required Uint8List maskBytes,
    Duration timeout = const Duration(seconds: 60),
    String? inpaintApiBaseOverride,
  }) async {
    final base = resolvedBaseUrl(override: inpaintApiBaseOverride);
    if (base.isEmpty) {
      throw InpaintException(
        '未配置 AI 擦除服务地址（INPAINT_API_BASE）。',
      );
    }

    final online = await NetworkReachability.instance.quickCheck();
    if (!online) {
      throw InpaintException('当前无网络连接，请连接网络后重试。');
    }

    final decoded = img.decodeImage(imageBytes);
    final maskDecoded = img.decodeImage(maskBytes);
    if (decoded == null) {
      throw InpaintException('无法解码待擦除图片');
    }
    if (maskDecoded == null) {
      throw InpaintException('无法解码擦除蒙版');
    }
    final baked = img.bakeOrientation(decoded);
    final uploadPng = Uint8List.fromList(img.encodePng(baked));
    final normalizedMask = _normalizeMask(maskDecoded);
    final uploadMaskPng = Uint8List.fromList(img.encodePng(normalizedMask));
    final binaryMaskPreview = _buildBinaryMaskPreview(normalizedMask);
    final binaryMaskPreviewBytes = Uint8List.fromList(img.encodePng(binaryMaskPreview));
    final maskStats = _analyzeMask(normalizedMask);
    final endpoint = _endpointForBase(base);
    final baseDebugInfo = InpaintDebugInfo(
      endpoint: endpoint,
      requestImageBytes: imageBytes.length,
      requestImageWidth: decoded.width,
      requestImageHeight: decoded.height,
      requestMaskBytes: maskBytes.length,
      requestMaskWidth: maskDecoded.width,
      requestMaskHeight: maskDecoded.height,
      uploadMaskBytes: uploadMaskPng.length,
      uploadMaskWidth: normalizedMask.width,
      uploadMaskHeight: normalizedMask.height,
      maskActivePixels: maskStats.$1,
      maskBounds: maskStats.$2,
      binaryMaskPreviewBytes: binaryMaskPreviewBytes,
      uploadImageBytes: uploadPng.length,
      uploadImageWidth: baked.width,
      uploadImageHeight: baked.height,
    );
    lastDebugInfo = baseDebugInfo;

    final req = http.MultipartRequest('POST', endpoint);
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        uploadPng,
        filename: 'image.png',
        contentType: MediaType('image', 'png'),
      ),
    );
    req.files.add(
      http.MultipartFile.fromBytes(
        'mask',
        uploadMaskPng,
        filename: 'mask.png',
        contentType: MediaType('image', 'png'),
      ),
    );

    final streamed = await _client.send(req).timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    final responseDecoded = img.decodeImage(res.bodyBytes);
    final debugInfo = InpaintDebugInfo(
      endpoint: endpoint,
      requestImageBytes: imageBytes.length,
      requestImageWidth: decoded.width,
      requestImageHeight: decoded.height,
      requestMaskBytes: maskBytes.length,
      requestMaskWidth: maskDecoded.width,
      requestMaskHeight: maskDecoded.height,
      uploadMaskBytes: uploadMaskPng.length,
      uploadMaskWidth: normalizedMask.width,
      uploadMaskHeight: normalizedMask.height,
      maskActivePixels: maskStats.$1,
      maskBounds: maskStats.$2,
      binaryMaskPreviewBytes: binaryMaskPreviewBytes,
      uploadImageBytes: uploadPng.length,
      uploadImageWidth: baked.width,
      uploadImageHeight: baked.height,
      responseStatusCode: res.statusCode,
      responseContentType: res.headers['content-type'],
      responseBytes: res.bodyBytes.length,
      responseImageWidth: responseDecoded?.width,
      responseImageHeight: responseDecoded?.height,
      responseSameAsUpload: _bytesEqual(res.bodyBytes, uploadPng),
      responseSameAsOriginalInput: _bytesEqual(res.bodyBytes, imageBytes),
      responsePreview: _safePreview(res.body),
    );
    lastDebugInfo = debugInfo;
    if (res.statusCode != 200) {
      throw InpaintException(
        'AI 擦除失败（${res.statusCode}）：${_parseErrorBody(res.body) ?? _truncate(res.body, 200)}',
        debugInfo: debugInfo,
      );
    }
    if (res.bodyBytes.isEmpty) {
      throw InpaintException('AI 擦除失败：响应内容为空', debugInfo: debugInfo);
    }
    return res.bodyBytes;
  }

  String? _parseErrorBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) {
        return j['error'].toString();
      }
      if (j is Map && j['message'] != null) {
        return j['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  String? _safePreview(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return _truncate(trimmed.replaceAll(RegExp(r'\s+'), ' '), 240);
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  img.Image _normalizeMask(img.Image input) {
    final out = img.Image(width: input.width, height: input.height, numChannels: 4);
    final srcIter = input.iterator;
    for (final dst in out) {
      if (!srcIter.moveNext()) break;
      final p = srcIter.current;
      // 保留抗锯齿灰度边缘，但忽略 alpha：
      // 黑底背景本身 alpha=255，若把 alpha 计入会把整张图都误判为有效区域。
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final v = r > g ? (r > b ? r : b) : (g > b ? g : b);
      dst.setRgba(v, v, v, 255);
    }
    return out;
  }

  img.Image _buildBinaryMaskPreview(img.Image input) {
    final out = img.Image(width: input.width, height: input.height, numChannels: 4);
    final srcIter = input.iterator;
    for (final dst in out) {
      if (!srcIter.moveNext()) break;
      final v = srcIter.current.r > 0 ? 255 : 0;
      dst.setRgba(v, v, v, 255);
    }
    return out;
  }

  (int, String) _analyzeMask(img.Image mask) {
    var activePixels = 0;
    var minX = mask.width;
    var minY = mask.height;
    var maxX = -1;
    var maxY = -1;
    for (final p in mask) {
      if (p.r > 0) {
        final x = p.x;
        final y = p.y;
        activePixels++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (activePixels == 0) return (0, 'empty');
    return (activePixels, '($minX,$minY)-($maxX,$maxY)');
  }

  void close() {
    _client.close();
  }
}
