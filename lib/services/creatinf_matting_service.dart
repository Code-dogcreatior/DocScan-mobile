import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// 远程抠图：multipart 上传 JPEG，`model_type` 与固定路径端点约定见实现。
/// 根地址仅来自编译期 `MATTING_API_BASE`（或单测 override）。
class CreatinfMattingException implements Exception {
  CreatinfMattingException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum CreatinfMattingModel {
  /// 最大边 1024，接口仍为高精度端点。
  general,

  /// 最大边 2304（默认，推荐相机照片）。
  highPrecision,

  /// 最大边 512，透明物体专用端点。
  transparentMatting,
}

extension on CreatinfMattingModel {
  String get modelTypeParam => switch (this) {
        CreatinfMattingModel.general => 'general',
        CreatinfMattingModel.highPrecision => 'high_precision',
        CreatinfMattingModel.transparentMatting => 'transparent_matting',
      };

  Uri endpointForBase(String baseUrl) {
    final trimmed = baseUrl.trim();
    final noSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final path = this == CreatinfMattingModel.transparentMatting
        ? '/process_transparent_matting'
        : '/process_high_precision';
    return Uri.parse('$noSlash$path');
  }

  int get maxUploadSide => switch (this) {
        CreatinfMattingModel.highPrecision => 2304,
        CreatinfMattingModel.general => 1024,
        CreatinfMattingModel.transparentMatting => 512,
      };
}

class CreatinfMattingService {
  CreatinfMattingService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  static String resolvedBaseUrl({String? override}) {
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    const fromEnv = String.fromEnvironment('MATTING_API_BASE');
    return fromEnv.trim();
  }

  /// 相机 JPEG 字节 → 带透明通道的 PNG。
  Future<Uint8List> processCameraJpeg(
    Uint8List cameraJpegBytes, {
    CreatinfMattingModel model = CreatinfMattingModel.highPrecision,
    Duration timeout = const Duration(seconds: 120),
    String? mattingApiBaseOverride,
  }) async {
    final base = resolvedBaseUrl(override: mattingApiBaseOverride);
    if (base.isEmpty) {
      throw CreatinfMattingException(
        '未配置抠图服务地址。请在本机维护 matting_local.env（见 matting_local.example.env），'
        '并以 `flutter run --dart-define-from-file=matting_local.env` 运行；'
        '或直接使用 `--dart-define=MATTING_API_BASE=...`（勿把真实地址提交到 Git）。',
      );
    }

    final decoded = img.decodeImage(cameraJpegBytes);
    if (decoded == null) {
      throw CreatinfMattingException('无法解码照片');
    }
    final baked = img.bakeOrientation(decoded);
    final origW = baked.width;
    final origH = baked.height;

    final maxSide = model.maxUploadSide;
    final longEdge = origW > origH ? origW : origH;
    img.Image forUpload = baked;
    if (longEdge > maxSide) {
      final scale = maxSide / longEdge;
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

    final request = http.MultipartRequest('POST', model.endpointForBase(base));
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        uploadJpg,
        filename: 'image.jpg',
      ),
    );
    request.fields['model_type'] = model.modelTypeParam;

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
    for (var y = 0; y < origH; y++) {
      for (var x = 0; x < origW; x++) {
        final mpx = maskResized.getPixel(x, y);
        final a = mpx.r.toInt().clamp(0, 255);
        final p = rgba.getPixel(x, y);
        rgba.setPixelRgba(
          x,
          y,
          p.r.toInt(),
          p.g.toInt(),
          p.b.toInt(),
          a,
        );
      }
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
