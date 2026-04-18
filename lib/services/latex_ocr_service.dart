import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'latex_onnx_file_stub.dart' if (dart.library.io) 'latex_onnx_file_io.dart'
    as onnx_file;

// ---------------------------------------------------------------------------
// 输出清理（与渲染器格式无关：非法 TeX 如 `\9`、`[EOS]` 等需剔除）
// ---------------------------------------------------------------------------

/// 清理 LaTeXOCR 类模型输出中 **非 TeX** 的残留，便于 [flutter_math_fork] 与人工阅读。
class LatexOutputSanitizer {
  LatexOutputSanitizer._();

  /// 幂等；在 [LatexOcrService] 的 post_process 之后调用。
  static String stripModelArtifacts(String s) {
    var t = s.trim();
    if (t.isEmpty) return t;

    const tags = <String>[
      '<redacted_EOS>',
      '<redacted_BOS>',
      '<redacted_PAD>',
      '<EOS>',
      '<BOS>',
      '<PAD>',
      '<SEP>',
    ];
    for (final tag in tags) {
      t = t.replaceAll(tag, '');
    }
    t = t.replaceAll(RegExp(r'\[(EOS|BOS|PAD|SEP)\]', caseSensitive: false), '');

    t = t.replaceAllMapped(
      RegExp(r'\\(\d)(?![0-9A-Za-z])'),
      (m) => m.group(1)!,
    );

    t = t.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
    return t.trim();
  }
}

// ---------------------------------------------------------------------------
// tokenizer.json（ByteLevel BPE），对齐 flutter_reference/latex/test_cpu_onnxruntime.py
// ---------------------------------------------------------------------------

class LatexBpeTokenizer {
  LatexBpeTokenizer._(this._idToToken, this._byteDecoder);

  final List<String> _idToToken;
  final Map<String, int> _byteDecoder;

  static Future<LatexBpeTokenizer> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return LatexBpeTokenizer.fromJsonString(raw);
  }

  factory LatexBpeTokenizer.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final model = map['model'] as Map<String, dynamic>?;
    if (model == null) {
      throw const FormatException('tokenizer.json: missing model');
    }
    final vocab = model['vocab'] as Map<String, dynamic>?;
    if (vocab == null) {
      throw const FormatException('tokenizer.json: missing model.vocab');
    }
    var maxId = 0;
    for (final e in vocab.entries) {
      final id = e.value;
      if (id is int && id > maxId) maxId = id;
    }
    final idToToken = List<String>.filled(maxId + 1, '', growable: false);
    for (final e in vocab.entries) {
      final id = e.value;
      if (id is int && id >= 0 && id < idToToken.length) {
        idToToken[id] = e.key.toString();
      }
    }
    final btu = _bytesToUnicode();
    final byteDecoder = <String, int>{};
    for (final e in btu.entries) {
      byteDecoder[e.value] = e.key;
    }
    return LatexBpeTokenizer._(idToToken, byteDecoder);
  }

  static Map<int, String> _bytesToUnicode() {
    final bs = <int>[
      ...List<int>.generate(0x7E - 0x21 + 1, (i) => 0x21 + i),
      ...List<int>.generate(0xAC - 0xA1 + 1, (i) => 0xA1 + i),
      ...List<int>.generate(0xFF - 0xAE + 1, (i) => 0xAE + i),
    ];
    final cs = List<int>.from(bs);
    var n = 0;
    for (var b = 0; b < 256; b++) {
      if (!bs.contains(b)) {
        bs.add(b);
        cs.add(256 + n);
        n++;
      }
    }
    return Map<int, String>.fromIterables(
      bs,
      cs.map((c) => String.fromCharCode(c)),
    );
  }

  String _byteLevelDecode(String text) {
    final out = Uint8List(text.runes.length);
    var o = 0;
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      final b = _byteDecoder[ch];
      if (b == null) {
        if (kDebugMode) {
          debugPrint('[LatexBpeTokenizer] unknown byte char: U+${r.toRadixString(16)}');
        }
        continue;
      }
      out[o++] = b;
    }
    return utf8.decode(out.sublist(0, o));
  }

  String tokenIdsToLatexString(List<int> tokenIds) {
    final sb = StringBuffer();
    for (final id in tokenIds) {
      if (id <= 0 || id >= _idToToken.length) continue;
      sb.write(_idToToken[id]);
    }
    var detok = _byteLevelDecode(sb.toString());
    detok = detok.split(' ').join();
    detok = detok
        .replaceAll('Ġ', ' ')
        .replaceAll('<redacted_EOS>', '')
        .replaceAll('<redacted_BOS>', '')
        .replaceAll('[PAD]', '');
    return detok.trim();
  }
}

// ---------------------------------------------------------------------------
// ONNX 推理服务
// ---------------------------------------------------------------------------

class LatexOcrException implements Exception {
  LatexOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 端侧 LaTeX OCR（Rapid-LaTeXOCR 兼容 ONNX），流水线对齐
/// [flutter_reference/latex/test_cpu_onnxruntime.py]。
///
/// 三个 ONNX 加载顺序：① [AssetBundle]（须在 [pubspec.yaml] 登记）② 应用私有目录
/// `latex_onnx/`（[getApplicationSupportDirectory] 或 [getApplicationDocumentsDirectory] 下），
/// 便于不把大文件打进包体时用 `adb push` 等拷贝。`tokenizer.json` 仍走 assets。
class LatexOcrService {
  LatexOcrService._();
  static final LatexOcrService instance = LatexOcrService._();

  static const String _assetTokenizer = 'assets/models/latex/tokenizer.json';
  static const String _assetEncoder = 'assets/models/latex/encoder.onnx';
  static const String _assetDecoder = 'assets/models/latex/decoder.onnx';
  static const String _assetResizer = 'assets/models/latex/image_resizer.onnx';

  static const List<int> _maxDims = [672, 192];
  static const List<int> _minDims = [32, 32];
  static const double _temperature = 0.00001;
  static const double _filterThres = 0.9;
  static const int _bosToken = 1;
  static const int _eosToken = 2;
  static const int _maxSeqLen = 512;
  static const int _decoderSteps = 256;

  LatexBpeTokenizer? _tokenizer;
  OrtSession? _encoder;
  OrtSession? _decoder;
  OrtSession? _resizer;
  OrtSessionOptions? _sessionOptions;
  bool _ortEnvReady = false;

  Future<void>? _initFuture;

  bool get isInitialized =>
      _tokenizer != null && _encoder != null && _decoder != null && _resizer != null;

  Future<void> ensureInitialized() async {
    try {
      _initFuture ??= _init();
      await _initFuture!;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _init() async {
    if (!_ortEnvReady) {
      OrtEnv.instance.init();
      _ortEnvReady = true;
    }
    _tokenizer = await LatexBpeTokenizer.loadFromAsset(_assetTokenizer);

    _sessionOptions = OrtSessionOptions()
      ..setIntraOpNumThreads(1)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    try {
      _sessionOptions!.appendNnapiProvider(NnapiFlags.cpuDisabled);
    } catch (_) {}
    try {
      _sessionOptions!.appendXnnpackProvider();
    } catch (_) {}

    try {
      final enc = await _loadOnnxBytes(_assetEncoder, 'encoder.onnx');
      final dec = await _loadOnnxBytes(_assetDecoder, 'decoder.onnx');
      final rsz = await _loadOnnxBytes(_assetResizer, 'image_resizer.onnx');
      _encoder = OrtSession.fromBuffer(enc, _sessionOptions!);
      _decoder = OrtSession.fromBuffer(dec, _sessionOptions!);
      _resizer = OrtSession.fromBuffer(rsz, _sessionOptions!);
    } catch (e, st) {
      debugPrint('[LatexOcrService] ONNX load failed: $e\n$st');
      if (e is LatexOcrException) rethrow;
      throw LatexOcrException(await _onnxMissingHelpMessage());
    }
  }

  /// 先 assets，再本地 `latex_onnx/`（支持目录与文档目录各试一次）。
  Future<Uint8List> _loadOnnxBytes(String assetKey, String fileName) async {
    try {
      final bd = await rootBundle.load(assetKey);
      final bytes = bd.buffer.asUint8List();
      if (bytes.length >= 1024) {
        return bytes;
      }
    } catch (_) {}

    if (kIsWeb) {
      throw LatexOcrException(_onnxMissingHelpWeb);
    }

    for (final base in await _latexOnnxSearchRoots()) {
      try {
        final bytes = await onnx_file.tryReadOnnxFile(base, fileName);
        if (bytes != null) {
          if (kDebugMode) {
            debugPrint('[LatexOcrService] loaded $fileName from ${p.join(base, fileName)}');
          }
          return bytes;
        }
      } catch (e) {
        debugPrint('[LatexOcrService] skip $base/$fileName: $e');
      }
    }

    throw LatexOcrException(await _onnxMissingHelpMessage());
  }

  Future<List<String>> _latexOnnxSearchRoots() async {
    final out = <String>[];
    try {
      final s = await getApplicationSupportDirectory();
      out.add(p.join(s.path, 'latex_onnx'));
    } catch (e) {
      debugPrint('[LatexOcrService] getApplicationSupportDirectory: $e');
    }
    try {
      final d = await getApplicationDocumentsDirectory();
      out.add(p.join(d.path, 'latex_onnx'));
    } catch (e) {
      debugPrint('[LatexOcrService] getApplicationDocumentsDirectory: $e');
    }
    return out;
  }

  static const String _onnxMissingHelpWeb =
      '未找到 LaTeX ONNX。Web 端请将 encoder.onnx、decoder.onnx、image_resizer.onnx '
      '放入 assets/models/latex/ 并在 pubspec.yaml 的 flutter.assets 中登记。';

  Future<String> _onnxMissingHelpMessage() async {
    if (kIsWeb) {
      return _onnxMissingHelpWeb;
    }
    final roots = await _latexOnnxSearchRoots();
    final lines = roots.map((r) => '   • $r').join('\n');
    return '未找到 LaTeX 模型（encoder.onnx / decoder.onnx / image_resizer.onnx）。\n\n'
        '任选一种方式：\n'
        '1）将三个 onnx 与 tokenizer.json 放在同一目录 assets/models/latex/，并确保 pubspec.yaml 的 '
        'flutter.assets 中含有「- assets/models/latex/」（目录末尾斜杠，表示打包整个目录）。'
        '修改后务必执行 flutter clean 再重新运行，否则仍会读到旧资源清单。\n'
        '2）将三个同名文件拷贝到设备上以下任一目录下的 latex_onnx 文件夹（无需改 pubspec，适合调试或大模型）：\n'
        '$lines\n'
        '   示例：adb push encoder.onnx /data/data/<包名>/files/latex_onnx/\n'
        '   （具体路径因系统而异，可先在设备文件管理器中查找应用私有目录。）';
  }

  void dispose() {
    _encoder?.release();
    _decoder?.release();
    _resizer?.release();
    _sessionOptions?.release();
    _encoder = null;
    _decoder = null;
    _resizer = null;
    _sessionOptions = null;
    _initFuture = null;
    _tokenizer = null;
  }

  /// 识别 JPEG 字节，返回 post_process 后的 LaTeX 字符串。
  Future<String> recognizeJpeg(Uint8List jpegBytes) async {
    await ensureInitialized();
    final tok = _tokenizer!;
    final encoder = _encoder!;
    final decoder = _decoder!;
    final resizer = _resizer!;

    final rgb = _loadRgbFromJpeg(jpegBytes);
    final encInput = _loopImageResizer(rgb, resizer);
    final ctx = _runEncoderWithShape(encoder, encInput.tensor, encInput.shape);
    final tokenIds = _runDecoderAutoregressive(decoder, ctx.data, ctx.shape);
    final raw = tok.tokenIdsToLatexString(tokenIds);
    return LatexOutputSanitizer.stripModelArtifacts(_postProcess(raw));
  }

  img.Image _loadRgbFromJpeg(Uint8List jpegBytes) {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) {
      throw LatexOcrException('无法解码 JPEG 图像');
    }
    final baked = img.bakeOrientation(decoded);
    return _ensureRgb(baked);
  }

  img.Image _ensureRgb(img.Image src) {
    if (src.numChannels >= 3) {
      return src;
    }
    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        final v = p.r.toInt();
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  ({Float32List tensor, List<int> shape}) _loopImageResizer(
    img.Image rgb,
    OrtSession resizer,
  ) {
    var inputImage = rgb;
    var r = 1.0;
    var w = inputImage.width;
    var h = inputImage.height;
    late Float32List finalTensor;
    late List<int> finalShape;
    for (var i = 0; i < 10; i++) {
      h = math.max(1, (h * r).round());
      final pair = _preProcess(inputImage, r, w, h);
      final pad = pair.padImage;
      final ph = pad.height;
      final pw = pad.width;
      final shape = [1, 1, ph, pw];
      finalTensor = pair.tensor;
      finalShape = shape;
      final argmaxIdx = _runResizerArgmax(resizer, finalTensor, shape);
      w = (argmaxIdx + 1) * 32;
      if (w == pw) {
        break;
      }
      r = w / pw;
    }
    return (tensor: finalTensor, shape: finalShape);
  }

  ({Float32List tensor, img.Image padImage}) _preProcess(
    img.Image inputImage,
    double r,
    int w,
    int h,
  ) {
    final resizeFunc = r > 1 ? img.Interpolation.linear : img.Interpolation.cubic;
    final resized = img.copyResize(
      inputImage,
      width: w,
      height: h,
      interpolation: resizeFunc,
    );
    final padGray = _padToDiv32(resized);
    final sized = _minmaxSize(padGray);
    return (tensor: _grayToTensorN1HW(sized), padImage: sized);
  }

  img.Image _padToDiv32(img.Image src) {
    const threshold = 128;
    const divable = 32;
    late List<double> dataFlat;
    final w0 = src.width;
    final h0 = src.height;

    if (src.hasAlpha) {
      final alphas = Float32List(w0 * h0);
      var i = 0;
      for (var y = 0; y < h0; y++) {
        for (var x = 0; x < w0; x++) {
          alphas[i++] = src.getPixel(x, y).a.toDouble();
        }
      }
      final meanA = alphas.reduce((a, b) => a + b) / alphas.length;
      var varA = 0.0;
      for (final a in alphas) {
        final d = a - meanA;
        varA += d * d;
      }
      varA /= alphas.length;
      if (varA == 0) {
        dataFlat = Float32List(w0 * h0);
        var k = 0;
        for (var y = 0; y < h0; y++) {
          for (var x = 0; x < w0; x++) {
            final p = src.getPixel(x, y);
            dataFlat[k++] = _luma(p.r, p.g, p.b).toDouble();
          }
        }
      } else {
        dataFlat = Float32List(w0 * h0);
        var k = 0;
        for (var y = 0; y < h0; y++) {
          for (var x = 0; x < w0; x++) {
            final a = src.getPixel(x, y).a.toInt();
            dataFlat[k++] = (255 - a).toDouble();
          }
        }
      }
    } else {
      dataFlat = Float32List(w0 * h0);
      var k = 0;
      for (var y = 0; y < h0; y++) {
        for (var x = 0; x < w0; x++) {
          final p = src.getPixel(x, y);
          dataFlat[k++] = _luma(p.r, p.g, p.b).toDouble();
        }
      }
    }

    var dMin = dataFlat[0];
    var dMax = dataFlat[0];
    for (final v in dataFlat) {
      if (v < dMin) dMin = v;
      if (v > dMax) dMax = v;
    }
    final scale = 255.0 / (dMax - dMin + 1e-8);
    for (var i = 0; i < dataFlat.length; i++) {
      dataFlat[i] = (dataFlat[i] - dMin) * scale;
    }
    final mean = dataFlat.reduce((a, b) => a + b) / dataFlat.length;
    late Uint8List grayBin;
    if (mean > threshold) {
      grayBin = Uint8List(w0 * h0);
      for (var i = 0; i < dataFlat.length; i++) {
        grayBin[i] = dataFlat[i] < threshold ? 255 : 0;
      }
    } else {
      for (var i = 0; i < dataFlat.length; i++) {
        dataFlat[i] = 255 - dataFlat[i];
      }
      grayBin = Uint8List(w0 * h0);
      for (var i = 0; i < dataFlat.length; i++) {
        grayBin[i] = dataFlat[i] > threshold ? 255 : 0;
      }
    }

    var minX = w0, minY = h0, maxX = -1, maxY = -1;
    for (var y = 0; y < h0; y++) {
      for (var x = 0; x < w0; x++) {
        if (grayBin[y * w0 + x] != 0) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      minX = 0;
      minY = 0;
      maxX = w0 - 1;
      maxY = h0 - 1;
    }
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;
    final rect = img.Image(width: cw, height: ch, numChannels: 1);
    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        final v = grayBin[(minY + y) * w0 + (minX + x)].toInt();
        rect.setPixelRgb(x, y, v, v, v);
      }
    }

    int roundUp32(int x) {
      final div = x ~/ divable;
      final mod = x % divable;
      return divable * (div + (mod > 0 ? 1 : 0));
    }

    final pw = roundUp32(cw);
    final ph = roundUp32(ch);
    final padded = img.Image(width: pw, height: ph, numChannels: 1);
    img.fill(padded, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(padded, rect, dstX: 0, dstY: 0);
    return padded;
  }

  img.Image _minmaxSize(img.Image gray) {
    var im = gray;
    final maxW = _maxDims[0];
    final maxH = _maxDims[1];
    final rw = im.width / maxW;
    final rh = im.height / maxH;
    if (rw > 1 || rh > 1) {
      final ratio = math.max(rw, rh);
      final nw = math.max(1, (im.width / ratio).floor());
      final nh = math.max(1, (im.height / ratio).floor());
      im = img.copyResize(im, width: nw, height: nh, interpolation: img.Interpolation.linear);
    }
    final minW = _minDims[0];
    final minH = _minDims[1];
    if (im.width < minW || im.height < minH) {
      final nw = math.max(im.width, minW);
      final nh = math.max(im.height, minH);
      final canvas = img.Image(width: nw, height: nh, numChannels: 1);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      final off = _grayContentTopLeft(im);
      img.compositeImage(canvas, im, dstX: off.$1, dstY: off.$2);
      im = canvas;
    }
    return im;
  }

  int _luma(num r, num g, num b) =>
      (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

  Float32List _grayToTensorN1HW(img.Image gray) {
    const mean = 0.7931 * 255.0;
    const std = 0.1738 * 255.0;
    final invStd = 1.0 / std;
    final w = gray.width;
    final h = gray.height;
    final out = Float32List(h * w);
    var i = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = gray.getPixel(x, y).r.toDouble();
        out[i++] = ((v - mean) * invStd).toDouble();
      }
    }
    return out;
  }

  (int, int) _grayContentTopLeft(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (gray.getPixel(x, y).r < 255) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      return (0, 0);
    }
    return (minX, minY);
  }

  int _shapeProduct(List<int> s) => s.fold(1, (a, b) => a * b);

  int _runResizerArgmax(
    OrtSession session,
    Float32List input,
    List<int> shape,
  ) {
    final t = OrtValueTensor.createTensorWithDataList(input, shape);
    final runOptions = OrtRunOptions();
    final outs = session.run(
      runOptions,
      {session.inputNames.first: t},
      session.outputNames,
    );
    try {
      if (outs.isEmpty || outs.first == null) {
        throw LatexOcrException('image_resizer 无输出');
      }
      final v = outs.first!.value;
      return _argmaxClassifierLogits(v);
    } finally {
      t.release();
      runOptions.release();
      for (final o in outs) {
        o?.release();
      }
    }
  }

  int _argmaxClassifierLogits(Object? v) {
    if (v is List && v.isNotEmpty) {
      final row = v.first;
      if (row is List) {
        final scores = row.map((e) => (e as num).toDouble()).toList();
        return _argmaxIndex(scores);
      }
    }
    return _argmaxIndex(_flattenNums(v));
  }

  int _argmaxIndex(List<double> logits) {
    if (logits.isEmpty) return 0;
    var best = 0;
    var bestV = logits[0];
    for (var i = 1; i < logits.length; i++) {
      if (logits[i] > bestV) {
        bestV = logits[i];
        best = i;
      }
    }
    return best;
  }

  ({Float32List data, List<int> shape}) _runEncoderWithShape(
    OrtSession session,
    Float32List input,
    List<int> shape,
  ) {
    final t = OrtValueTensor.createTensorWithDataList(input, shape);
    final runOptions = OrtRunOptions();
    final outs = session.run(
      runOptions,
      {session.inputNames.first: t},
      session.outputNames,
    );
    try {
      if (outs.isEmpty || outs.first == null) {
        throw LatexOcrException('encoder 无输出');
      }
      final v = outs.first!.value;
      final outShape = _tensorShapeFromValue(v);
      final flat = _flattenNums(v);
      if (outShape.isNotEmpty && _shapeProduct(outShape) != flat.length) {
        throw LatexOcrException(
          'encoder 形状与数据量不一致: shape=$outShape len=${flat.length}',
        );
      }
      return (data: Float32List.fromList(flat), shape: outShape);
    } finally {
      t.release();
      runOptions.release();
      for (final o in outs) {
        o?.release();
      }
    }
  }

  List<int> _tensorShapeFromValue(Object? v) {
    if (v == null || v is! List) return const [];
    final dims = <int>[];
    Object? cur = v;
    while (cur is List) {
      if (cur.isEmpty) {
        dims.add(0);
        break;
      }
      dims.add(cur.length);
      cur = cur.first;
      if (cur is! List) {
        break;
      }
    }
    return dims;
  }

  List<double> _flattenNums(Object? v) {
    final out = <double>[];
    void walk(Object? x) {
      if (x == null) return;
      if (x is num) {
        out.add(x.toDouble());
        return;
      }
      if (x is List) {
        for (final e in x) {
          walk(e);
        }
      }
    }

    walk(v);
    return out;
  }

  List<int> _runDecoderAutoregressive(
    OrtSession decoder,
    Float32List contextFlat,
    List<int> contextShape,
  ) {
    final ctx = contextFlat;
    final names = decoder.inputNames;
    if (names.length < 3) {
      throw LatexOcrException('decoder 输入数量异常: ${names.length}');
    }
    String? tokName;
    String? maskName;
    String? ctxName;
    for (final n in names) {
      final l = n.toLowerCase();
      if (l.contains('context') || l.contains('memory') || l.contains('enc')) {
        ctxName = n;
      } else if (l.contains('mask') || l.contains('attn')) {
        maskName = n;
      } else if (l.contains('token') || l.contains('input') || l.contains('ids')) {
        tokName = n;
      }
    }
    tokName ??= names[0];
    maskName ??= names[1];
    ctxName ??= names[2];

    final runOptions = OrtRunOptions();
    var outTokens = <int>[_bosToken];
    final maxLen = _maxSeqLen;

    try {
      for (var step = 0; step < _decoderSteps; step++) {
        final tLen = outTokens.length;
        final start = tLen > maxLen ? tLen - maxLen : 0;
        final window = outTokens.sublist(start);
        final winLen = window.length;

        final tokTensor = OrtValueTensor.createTensorWithDataList(
          List<int>.from(window),
          [1, winLen],
        );
        final mask = List<bool>.filled(winLen, true);
        final maskTensor = OrtValueTensor.createTensorWithDataList(
          mask,
          [1, winLen],
        );

        final ctxShape = List<int>.from(contextShape);
        if (ctxShape.isEmpty || _shapeProduct(ctxShape) != ctx.length) {
          throw LatexOcrException(
            'encoder context 形状无效: shape=$contextShape len=${ctx.length}',
          );
        }
        final ctxTensor = OrtValueTensor.createTensorWithDataList(ctx, ctxShape);

        final feeds = <String, OrtValue>{
          tokName: tokTensor,
          maskName: maskTensor,
          ctxName: ctxTensor,
        };

        final outs = decoder.run(runOptions, feeds, decoder.outputNames);
        tokTensor.release();
        maskTensor.release();
        ctxTensor.release();

        List<double> lastLogits;
        try {
          if (outs.isEmpty || outs.first == null) {
            throw LatexOcrException('decoder 无输出');
          }
          lastLogits = _decoderLastTimestepLogits(outs.first!.value);
        } finally {
          for (final o in outs) {
            o?.release();
          }
        }

        final filtered = _nppTopK(lastLogits, _filterThres);
        final nextId = _sampleOne(filtered, _temperature);
        outTokens = [...outTokens, nextId];
        if (nextId == _eosToken) {
          break;
        }
      }
    } finally {
      runOptions.release();
    }

    if (outTokens.isNotEmpty && outTokens.first == _bosToken) {
      outTokens = outTokens.sublist(1);
    }
    return outTokens;
  }

  List<double> _decoderLastTimestepLogits(Object? v) {
    if (v is! List || v.isEmpty) {
      throw LatexOcrException('decoder 输出类型异常');
    }
    final batch0 = v.first;
    if (batch0 is! List || batch0.isEmpty) {
      throw LatexOcrException('decoder 输出 batch 为空');
    }
    final lastTok = batch0.last;
    if (lastTok is! List) {
      throw LatexOcrException('decoder 输出缺少 vocab 维');
    }
    return lastTok.map((e) => (e as num).toDouble()).toList();
  }

  List<double> _nppTopK(List<double> logits, double thres) {
    if (logits.isEmpty) return logits;
    final vocab = logits.length;
    var k = ((1 - thres) * vocab).floor();
    if (k < 1) k = 1;
    if (k > vocab) k = vocab;
    final indexed = <({int i, double v})>[
      for (var i = 0; i < logits.length; i++) (i: i, v: logits[i]),
    ];
    indexed.sort((a, b) => b.v.compareTo(a.v));
    final keep = indexed.take(k).map((e) => e.i).toSet();
    return List<double>.generate(
      logits.length,
      (i) => keep.contains(i) ? logits[i] : double.negativeInfinity,
    );
  }

  double _logSumExp(List<double> x) {
    var m = x[0];
    for (var i = 1; i < x.length; i++) {
      if (x[i] > m) m = x[i];
    }
    var s = 0.0;
    for (final v in x) {
      s += math.exp(v - m);
    }
    return m + math.log(s);
  }

  List<double> _softmax(List<double> x) {
    final lse = _logSumExp(x);
    return x.map((v) => math.exp(v - lse)).toList();
  }

  int _sampleOne(List<double> filtered, double temperature) {
    if (temperature < 1e-6) {
      var best = 0;
      var bv = filtered[0];
      for (var i = 1; i < filtered.length; i++) {
        if (filtered[i] > bv) {
          bv = filtered[i];
          best = i;
        }
      }
      return best;
    }
    final scaled = filtered.map((v) => v / temperature).toList();
    final probs = _softmax(scaled);
    final r = math.Random().nextDouble();
    var c = 0.0;
    for (var i = 0; i < probs.length; i++) {
      c += probs[i];
      if (r <= c) return i;
    }
    return probs.length - 1;
  }

  static String _postProcess(String s) {
    final textReg = RegExp(
      r'\\(operatorname|mathrm|text|mathbf)\s?\*?\s*\{.*?\}',
    );
    final matches = textReg.allMatches(s).toList();
    final names = matches.map((m) => m.group(0)!.replaceAll(' ', '')).toList();
    var i = 0;
    var t = s.replaceAllMapped(textReg, (_) {
      if (i >= names.length) return '';
      return names[i++];
    });

    const noletter = r'[\W_^\d]';
    const letter = r'[a-zA-Z]';
    final re1 = RegExp('(?!\\\\ )($noletter)\\s+?($noletter)');
    final re2 = RegExp('(?!\\\\ )($noletter)\\s+?($letter)');
    final re3 = RegExp('($letter)\\s+?($noletter)');
    while (true) {
      final n1 = t.replaceAllMapped(re1, (m) => '${m[1]}${m[2]}');
      final n2 = n1.replaceAllMapped(re2, (m) => '${m[1]}${m[2]}');
      final n3 = n2.replaceAllMapped(re3, (m) => '${m[1]}${m[2]}');
      if (n3 == t) break;
      t = n3;
    }
    return t;
  }
}
