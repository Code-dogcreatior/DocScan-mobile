import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/app_env.dart';
import 'network_reachability.dart';

/// 远程抠图：multipart 上传 JPEG，`model_type` 与固定路径端点约定见实现。
/// 根地址来自编译期 [AppEnv.mattingApiBase]（或单测 override）。
class CreatinfMattingException implements Exception {
  CreatinfMattingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CreatinfMattingService {
  CreatinfMattingService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// 固定高精度端点：最大边 2304，`model_type=high_precision`。
  static const String _endpointPath = '/process_high_precision';
  static const String _modelType = 'high_precision';
  static const int _maxUploadSide = 2304;

  static String resolvedBaseUrl({String? override}) {
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return AppEnv.mattingApiBase.trim();
  }

  static Uri _buildEndpoint(String baseUrl) {
    final trimmed = baseUrl.trim();
    final noSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return Uri.parse('$noSlash$_endpointPath');
  }

  /// 相机 JPEG 字节 → 带透明通道的 PNG。
  Future<Uint8List> processCameraJpeg(
    Uint8List cameraJpegBytes, {
    Duration timeout = const Duration(seconds: 60),
    String? mattingApiBaseOverride,
  }) async {
    final base = resolvedBaseUrl(override: mattingApiBaseOverride);
    if (base.isEmpty) {
      throw CreatinfMattingException(
        '未配置抠图服务地址。请复制 env/app.example.env 为 env/app.env，填写 MATTING_API_BASE，'
        '并以 `flutter run --dart-define-from-file=env/app.env` 运行；'
        '或 `--dart-define=MATTING_API_BASE=...`（勿把真实地址提交到 Git）。',
      );
    }

    final online = await NetworkReachability.instance.quickCheck();
    if (!online) {
      throw CreatinfMattingException(
        '当前无网络连接（Wi‑Fi/蜂窝未连接或未授权），抠图 API 不可用。请连接网络后重试。',
      );
    }

    final decoded = img.decodeImage(cameraJpegBytes);
    if (decoded == null) {
      throw CreatinfMattingException('无法解码照片');
    }
    final baked = img.bakeOrientation(decoded);
    final origW = baked.width;
    final origH = baked.height;

    final longEdge = origW > origH ? origW : origH;
    img.Image forUpload = baked;
    if (longEdge > _maxUploadSide) {
      final scale = _maxUploadSide / longEdge;
      final tw = (origW * scale).round();
      final th = (origH * scale).round();
      forUpload = img.copyResize(
        baked,
        width: tw,
        height: th,
        interpolation: img.Interpolation.cubic,
      );
    }
    final uploadJpg = img.encodeJpg(forUpload, quality: 85);

    final request = http.MultipartRequest('POST', _buildEndpoint(base));
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        uploadJpg,
        filename: 'image.jpg',
      ),
    );
    request.fields['model_type'] = _modelType;

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw CreatinfMattingException(_parseErrorBody(response.body) ?? '请求失败 ${response.statusCode}');
    }

    final dynamic body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['mask'] == null) {
      throw CreatinfMattingException('接口返回格式异常');
    }
    final maskStr = body['mask'];
    if (maskStr is! String) {
      throw CreatinfMattingException('接口返回格式异常');
    }

    final maskBytes = base64Decode(maskStr);
    final maskImg = img.decodeImage(maskBytes);
    if (maskImg == null) {
      throw CreatinfMattingException('无法解码蒙版');
    }

    final maskResized =
        (maskImg.width == origW && maskImg.height == origH)
            ? maskImg
            : img.copyResize(
                maskImg,
                width: origW,
                height: origH,
                interpolation: img.Interpolation.cubic,
              );

    final rgba = baked.convert(numChannels: 4, alpha: 255);
    // 用迭代器一次遍历同步推进两张图的像素，避免逐像素 getPixel/setPixelRgba 的开销。
    final maskIter = maskResized.iterator;
    for (final p in rgba) {
      if (!maskIter.moveNext()) break;
      p.a = maskIter.current.r;
    }
    return Uint8List.fromList(img.encodePng(rgba));
  }

  String? _parseErrorBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) {
        return j['error'].toString();
      }
    } catch (_) {}
    return null;
  }

  void close() {
    _client.close();
  }
}
