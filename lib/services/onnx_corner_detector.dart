import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../models/camera_yuv_snapshot.dart';
import '../models/corner_point.dart';

/// ONNX corner detector with NNAPI-first execution.
///
/// 预览流用轻量 lcnet（与 [flutter_reference/point/infer.py] 一致），
/// 静态图仍用 fastvit heatmap（精度更高）。
class OnnxCornerDetector {
  OnnxCornerDetector._();

  /// 进程级单例：OrtSession 加载一次，跨页面复用，避免每次进相机重复 ~70ms 模型加载。
  static final OnnxCornerDetector instance = OnnxCornerDetector._();

  static const int _modelInputSize = 256;
  static const double _heatmapThreshold = 0.3;

  /// 仅用于 **拍照后 FastViT**（`detectFromImage`）：先把整图等比缩到「最长边 ≤ 此值」再 letterbox 进 256。
  /// 与预览里 LCNet 日志里的 `1920x1080` **无关**——那是 `CameraImage` 缓冲区尺寸；LCNet 始终从该缓冲区 **双线性采样到 256×256** 再推理。
  /// 调小可加快 FastViT、略降角点精度；调大更准但更慢。
  static const int _stillMaxLongEdge = 320;

  Future<void>? _initFuture;

  OrtSession? _ortSession;
  OrtSessionOptions? _ortSessionOptions;
  String? _inputName;
  List<String>? _outputNames;
  String? _heatmapOutputName;

  /// 预览专用；为 null 时回退为 fastvit。
  OrtSession? _lcnetSession;
  OrtSessionOptions? _lcnetSessionOptions;
  String? _lcnetInputName;
  String? _lcnetPointsOutputName;
  String? _lcnetHasObjOutputName;

  _CameraPreprocessCache? _cameraPreprocessCache;
  var _frameLogCounter = 0;

  static String _fmtUs(int us) =>
      us <= 0 ? '0.0' : (us / 1000.0).toStringAsFixed(1);

  Future<void> init() => _initFuture ??= _initOnce();

  Future<void> _initOnce() async {
    OrtEnv.instance.init();
    final providers = OrtEnv.instance.availableProviders();
    debugPrint('[OnnxCornerDetector] available providers: $providers');
    final options = OrtSessionOptions()
      // XNNPACK + ORT intra-op pool both spinning causes contention; ORT warns to use 1.
      ..setIntraOpNumThreads(1)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    // NNAPI first; fallback providers are appended automatically by ORT as needed.
    var nnapiEnabled = false;
    try {
      nnapiEnabled = options.appendNnapiProvider(NnapiFlags.cpuDisabled);
    } catch (_) {}
    var xnnpackEnabled = false;
    try {
      xnnpackEnabled = options.appendXnnpackProvider();
    } catch (_) {}
    final modelData = await rootBundle.load(
      'assets/models/fastvit_sa24_h_e_bifpn_256_fp32.onnx',
    );
    _ortSessionOptions = options;
    _ortSession = OrtSession.fromBuffer(
      modelData.buffer.asUint8List(),
      options,
    );
    _inputName = _ortSession!.inputNames.first;
    _outputNames = _ortSession!.outputNames;
    _heatmapOutputName = _outputNames!.firstWhere(
      (name) => name.toLowerCase().contains('heatmap'),
      orElse: () => _outputNames!.first,
    );
    debugPrint(
      '[OnnxCornerDetector] fastvit loaded. input=$_inputName outputs=$_outputNames inputSize=$_modelInputSize',
    );
    debugPrint(
      '[OnnxCornerDetector] nnapiEnabled=$nnapiEnabled xnnpackEnabled=$xnnpackEnabled',
    );

    await _tryLoadLcnetPreviewModel();
  }

  Future<void> _tryLoadLcnetPreviewModel() async {
    try {
      final lcOptions = OrtSessionOptions()
        ..setIntraOpNumThreads(1)
        ..setInterOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      try {
        lcOptions.appendNnapiProvider(NnapiFlags.cpuDisabled);
      } catch (_) {}
      try {
        lcOptions.appendXnnpackProvider();
      } catch (_) {}
      final buf = await rootBundle.load(
        'assets/models/lcnet050_p_multi_decoder_l3_d64_256_fp32.onnx',
      );
      _lcnetSessionOptions = lcOptions;
      _lcnetSession = OrtSession.fromBuffer(
        buf.buffer.asUint8List(),
        lcOptions,
      );
      final ins = _lcnetSession!.inputNames;
      final outs = _lcnetSession!.outputNames;
      if (ins.isEmpty || outs.length < 2) {
        throw StateError('lcnet unexpected io: in=$ins out=$outs');
      }
      _lcnetInputName = ins.firstWhere(
        (n) => n.toLowerCase().contains('img'),
        orElse: () => ins.first,
      );
      _lcnetPointsOutputName = outs.firstWhere(
        (n) => n.toLowerCase().contains('point'),
        orElse: () => outs.first,
      );
      _lcnetHasObjOutputName = outs.firstWhere(
        (n) =>
            n != _lcnetPointsOutputName &&
            (n.toLowerCase().contains('obj') ||
                n.toLowerCase().contains('has')),
        orElse: () => outs.firstWhere(
          (n) => n != _lcnetPointsOutputName,
          orElse: () => outs.last,
        ),
      );
      debugPrint(
        '[OnnxCornerDetector] lcnet preview loaded. in=$_lcnetInputName '
        'pointsOut=$_lcnetPointsOutputName hasObjOut=$_lcnetHasObjOutputName',
      );
    } catch (e, st) {
      _lcnetSession?.release();
      _lcnetSession = null;
      _lcnetSessionOptions?.release();
      _lcnetSessionOptions = null;
      _lcnetInputName = null;
      _lcnetPointsOutputName = null;
      _lcnetHasObjOutputName = null;
      debugPrint('[OnnxCornerDetector] lcnet preview load failed, use fastvit for stream: $e\n$st');
    }
  }

  /// 预览流：须先 [CameraYuvSnapshot.from] 再异步推理，避免阻塞 ImageReader 归还缓冲。
  Future<CornerDetectionResult> detectFromYuvSnapshot(
    CameraYuvSnapshot snap, {
    List<CornerPoint>? roiHint,
  }) async {
    final started = DateTime.now();
    try {
      if (_lcnetSession != null &&
          _lcnetInputName != null &&
          _lcnetPointsOutputName != null &&
          _lcnetHasObjOutputName != null) {
        try {
          return await _detectLcnetFromSnapshot(snap, started: started);
        } catch (e, st) {
          debugPrint(
            '[OnnxCornerDetector] lcnet inference failed, fallback fastvit: $e\n$st',
          );
        }
      }

      final w = snap.width;
      final h = snap.height;
      final tPre = DateTime.now();
      final preprocessed = _preprocessSnapshotToNchw(snap, roiHint: roiHint);
      final preMs = DateTime.now().difference(tPre).inMilliseconds;
      final tRun = DateTime.now();
      final runOut = await _runModelAndPostprocess(
        preprocessed.input,
        w,
        h,
        preprocessed.transform,
      );
      final inferPostMs = DateTime.now().difference(tRun).inMilliseconds;
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final result = runOut.result;
      final m = runOut.metrics;
      _frameLogCounter++;
      if (kDebugMode) {
        debugPrint(
          '[OnnxCornerDetector] cam#$_frameLogCounter ${w}x$h roi=${preprocessed.roiLabel} '
          'pre=${preMs}ms tensor=${_fmtUs(m.tensorUs)}ms ort=${_fmtUs(m.ortUs)}ms '
          'toDart=${_fmtUs(m.toDartHeatmapUs)}ms post=${_fmtUs(m.cornersUs)}ms '
          'hm=${m.hmW ?? 0}x${m.hmH ?? 0} inferBlock=${inferPostMs}ms wall=${elapsed}ms '
          'corners=${result.points.length}',
        );
      }
      if (!result.hasFourCorners) {
        return CornerDetectionResult(
          points: result.points,
          message: result.message,
          inferenceMs: elapsed,
          imageWidth: w.toDouble(),
          imageHeight: h.toDouble(),
        );
      }
      return CornerDetectionResult(
        points: _orderPointsClockwise(result.points),
        inferenceMs: elapsed,
        imageWidth: w.toDouble(),
        imageHeight: h.toDouble(),
      );
    } catch (_) {
      return CornerDetectionResult(
        points: const <CornerPoint>[],
        message: 'Failed to get 4 corners from current frame',
        imageWidth: snap.width.toDouble(),
        imageHeight: snap.height.toDouble(),
      );
    }
  }

  /// 兼容入口：内部同步拷贝为 [CameraYuvSnapshot] 后再推理（仍建议在回调内尽快 [CameraYuvSnapshot.from] 并 `unawaited`）。
  Future<CornerDetectionResult> detectFromCameraImage(
    CameraImage frame, {
    List<CornerPoint>? roiHint,
  }) {
    return detectFromYuvSnapshot(
      CameraYuvSnapshot.from(frame),
      roiHint: roiHint,
    );
  }

  Future<CornerDetectionResult> detectFromBytes(Uint8List bytes) async {
    final tDec = DateTime.now();
    final decoded = img.decodeImage(bytes);
    final decMs = DateTime.now().difference(tDec).inMilliseconds;
    if (decoded == null) {
      return const CornerDetectionResult(
        points: <CornerPoint>[],
        message: 'Failed to decode image for corners',
      );
    }
    final upright = img.bakeOrientation(decoded);
    final out = await detectFromImage(upright);
    if (kDebugMode) {
      debugPrint(
        '[OnnxCornerDetector] still decode+bake=${decMs}ms full=${upright.width}x${upright.height}',
      );
    }
    return out;
  }

  /// 在已解码、已 [img.bakeOrientation] 的图上检测角点。
  ///
  /// 先将整图等比缩到最长边为 [min(原最长边, _stillMaxLongEdge)] 再送 fastvit（再 letterbox 到 256），
  /// 角点线性映射回原图。
  Future<CornerDetectionResult> detectFromImage(
    img.Image fullImage, {
    List<CornerPoint>? roiHint,
  }) async {
    final t0 = DateTime.now();
    final fullW = fullImage.width;
    final fullH = fullImage.height;
    final ml = math.max(fullW, fullH);
    late final img.Image work;
    late final double scaleToFullX;
    late final double scaleToFullY;
    if (ml <= _stillMaxLongEdge) {
      work = fullImage;
      scaleToFullX = 1.0;
      scaleToFullY = 1.0;
    } else {
      final s = _stillMaxLongEdge / ml;
      final nw = math.max(1, (fullW * s).round());
      final nh = math.max(1, (fullH * s).round());
      work = img.copyResize(
        fullImage,
        width: nw,
        height: nh,
        interpolation: img.Interpolation.average,
      );
      scaleToFullX = fullW / nw;
      scaleToFullY = fullH / nh;
    }
    
    List<CornerPoint>? workRoiHint;
    if (roiHint != null && roiHint.length == 4) {
      workRoiHint = roiHint
          .map((p) => CornerPoint(p.x / scaleToFullX, p.y / scaleToFullY))
          .toList();
    }

    final tPre = DateTime.now();
    final preprocessed = _preprocessImageToNchw(work, roiHint: workRoiHint);
    final preMs = DateTime.now().difference(tPre).inMilliseconds;
    final tRun = DateTime.now();
    final runOut = await _runModelAndPostprocess(
      preprocessed.input,
      work.width,
      work.height,
      preprocessed.transform,
    );
    final result = runOut.result;
    final m = runOut.metrics;
    final inferPostMs = DateTime.now().difference(tRun).inMilliseconds;
    final totalMs = DateTime.now().difference(t0).inMilliseconds;
    if (kDebugMode) {
      debugPrint(
        '[OnnxCornerDetector] still full=${fullW}x$fullH work=${work.width}x${work.height} roi=${preprocessed.roiLabel} '
        'pre=${preMs}ms tensor=${_fmtUs(m.tensorUs)}ms ort=${_fmtUs(m.ortUs)}ms '
        'toDart=${_fmtUs(m.toDartHeatmapUs)}ms post=${_fmtUs(m.cornersUs)}ms '
        'hm=${m.hmW ?? 0}x${m.hmH ?? 0} inferBlock=${inferPostMs}ms total=${totalMs}ms '
        'corners=${result.points.length}',
      );
    }
    if (!result.hasFourCorners) {
      return CornerDetectionResult(
        points: result.points,
        message: result.message,
        inferenceMs: totalMs,
        imageWidth: fullW.toDouble(),
        imageHeight: fullH.toDouble(),
      );
    }
    final scaled = result.points
        .map(
          (p) => CornerPoint(p.x * scaleToFullX, p.y * scaleToFullY),
        )
        .toList();
    return CornerDetectionResult(
      points: _orderPointsClockwise(scaled),
      inferenceMs: totalMs,
      imageWidth: fullW.toDouble(),
      imageHeight: fullH.toDouble(),
    );
  }

  /// 与 [flutter_reference/point/infer.py] 一致：整帧拉伸到 256×256，输出归一化四角 + has_obj。
  Future<CornerDetectionResult> _detectLcnetFromSnapshot(
    CameraYuvSnapshot snap, {
    required DateTime started,
  }) async {
    final w = snap.width;
    final h = snap.height;
    final tPre = DateTime.now();
    // 使用双线性插值进行缩放
    final input = _preprocessSnapshotLcnetBilinear(snap);
    final preMs = DateTime.now().difference(tPre).inMilliseconds;

    final inputTensor = OrtValueTensor.createTensorWithDataList(input, <int>[
      1,
      3,
      _modelInputSize,
      _modelInputSize,
    ]);
    final sw = Stopwatch()..start();
    final runOptions = OrtRunOptions();
    final requestedOutputs = <String>[
      _lcnetPointsOutputName!,
      _lcnetHasObjOutputName!,
    ];
    final List<OrtValue?> outputs;
    final int ortUs;
    try {
      outputs =
          await (_lcnetSession!.runAsync(
                runOptions,
                <String, OrtValue>{_lcnetInputName!: inputTensor},
                requestedOutputs,
              ) ??
              Future<List<OrtValue?>>.value(
                _lcnetSession!.run(
                  runOptions,
                  <String, OrtValue>{_lcnetInputName!: inputTensor},
                  requestedOutputs,
                ),
              ));
      ortUs = sw.elapsedMicroseconds;
    } finally {
      inputTensor.release();
      runOptions.release();
    }

    double? hasObjScore;
    List<double>? pointsFlat;
    for (final ov in outputs) {
      if (ov == null) continue;
      try {
        final flat = _flattenNestedNums(ov.value);
        if (flat.length >= 8) {
          pointsFlat = flat;
        } else if (flat.isNotEmpty) {
          hasObjScore = flat.first;
        }
      } finally {
        ov.release();
      }
    }

    final elapsed = DateTime.now().difference(started).inMilliseconds;
    _frameLogCounter++;
    if (kDebugMode) {
      debugPrint(
        '[OnnxCornerDetector] lcnet#$_frameLogCounter ${w}x$h pre=${preMs}ms '
        'ort=${_fmtUs(ortUs)}ms wall=${elapsed}ms has=${hasObjScore ?? -1} '
        'ptsLen=${pointsFlat?.length ?? 0}',
      );
    }

    if (hasObjScore == null || hasObjScore <= 0.5) {
      return CornerDetectionResult(
        points: const <CornerPoint>[],
        message: 'lcnet: no document (has_obj)',
        inferenceMs: elapsed,
        imageWidth: w.toDouble(),
        imageHeight: h.toDouble(),
      );
    }
    if (pointsFlat == null || pointsFlat.length < 8) {
      return CornerDetectionResult(
        points: const <CornerPoint>[],
        message: 'lcnet: bad points output',
        inferenceMs: elapsed,
        imageWidth: w.toDouble(),
        imageHeight: h.toDouble(),
      );
    }

    final corners = <CornerPoint>[
      for (var i = 0; i < 4; i++)
        CornerPoint(
          pointsFlat[i * 2] * w,
          pointsFlat[i * 2 + 1] * h,
        ),
    ];
    return CornerDetectionResult(
      points: _orderPointsClockwise(corners),
      inferenceMs: elapsed,
      imageWidth: w.toDouble(),
      imageHeight: h.toDouble(),
    );
  }

  /// 全图双线性插值缩放：按目标像素映射回 YUV，比最近邻更平滑，有助于提升 LCNet 精度。
  Float32List _preprocessSnapshotLcnetBilinear(CameraYuvSnapshot image) {
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final uvPixelStride = image.planes[1].bytesPerPixel;
    final yStride = image.planes[0].bytesPerRow;
    final uvStride = image.planes[1].bytesPerRow;
    final W = image.width;
    final H = image.height;
    final d = _modelInputSize;
    final hw = d * d;
    final out = Float32List(3 * hw);
    
    final scaleX = (W - 1) / (d - 1);
    final scaleY = (H - 1) / (d - 1);

    for (var yi = 0; yi < d; yi++) {
      final sy = yi * scaleY;
      final y0 = sy.floor();
      final y1 = math.min(y0 + 1, H - 1);
      final dy = sy - y0;
      
      final yRow0 = y0 * yStride;
      final yRow1 = y1 * yStride;
      
      final uvRow0 = (y0 >> 1) * uvStride;
      final uvRow1 = (y1 >> 1) * uvStride;

      for (var xi = 0; xi < d; xi++) {
        final sx = xi * scaleX;
        final x0 = sx.floor();
        final x1 = math.min(x0 + 1, W - 1);
        final dx = sx - x0;

        // Y channel bilinear
        final y00 = yPlane[yRow0 + x0];
        final y10 = yPlane[yRow0 + x1];
        final y01 = yPlane[yRow1 + x0];
        final y11 = yPlane[yRow1 + x1];
        
        final yInterp = (y00 * (1 - dx) + y10 * dx) * (1 - dy) + 
                        (y01 * (1 - dx) + y11 * dx) * dy;

        // UV channel bilinear (subsampled)
        final uvX0 = (x0 >> 1) * uvPixelStride;
        final uvX1 = (x1 >> 1) * uvPixelStride;
        
        final u00 = uPlane[uvRow0 + uvX0];
        final u10 = uPlane[uvRow0 + uvX1];
        final u01 = uPlane[uvRow1 + uvX0];
        final u11 = uPlane[uvRow1 + uvX1];
        
        final uInterp = (u00 * (1 - dx) + u10 * dx) * (1 - dy) + 
                        (u01 * (1 - dx) + u11 * dx) * dy;

        final v00 = vPlane[uvRow0 + uvX0];
        final v10 = vPlane[uvRow0 + uvX1];
        final v01 = vPlane[uvRow1 + uvX0];
        final v11 = vPlane[uvRow1 + uvX1];
        
        final vInterp = (v00 * (1 - dx) + v10 * dx) * (1 - dy) + 
                        (v01 * (1 - dx) + v11 * dx) * dy;

        final r = (yInterp + 1.370705 * (vInterp - 128)).clamp(0, 255);
        final g = (yInterp - 0.337633 * (uInterp - 128) - 0.698001 * (vInterp - 128)).clamp(0, 255);
        final b = (yInterp + 1.732446 * (uInterp - 128)).clamp(0, 255);

        final i = yi * d + xi;
        out[i] = b / 255.0;
        out[hw + i] = g / 255.0;
        out[2 * hw + i] = r / 255.0;
      }
    }
    return out;
  }

  List<double> _flattenNestedNums(Object? value) {
    final out = <double>[];
    void walk(Object? v) {
      if (v == null) return;
      if (v is num) {
        out.add(v.toDouble());
        return;
      }
      if (v is Float32List) {
        for (var i = 0; i < v.length; i++) {
          out.add(v[i].toDouble());
        }
        return;
      }
      if (v is Float64List) {
        for (var i = 0; i < v.length; i++) {
          out.add(v[i]);
        }
        return;
      }
      if (v is List) {
        for (final e in v) {
          walk(e);
        }
      }
    }

    walk(value);
    return out;
  }

  Future<({CornerDetectionResult result, _InferMetrics metrics})>
  _runModelAndPostprocess(
    Float32List input,
    int originalW,
    int originalH,
    _LetterboxTransform transform,
  ) async {
    if (_ortSession == null || _inputName == null || _outputNames == null) {
      return (
        result: const CornerDetectionResult(
          points: <CornerPoint>[],
          message: 'ONNX session not initialized',
        ),
        metrics: _InferMetrics.empty,
      );
    }
    final sw = Stopwatch()..start();
    final inputTensor = OrtValueTensor.createTensorWithDataList(input, <int>[
      1,
      3,
      _modelInputSize,
      _modelInputSize,
    ]);
    final tensorUs = sw.elapsedMicroseconds;
    sw
      ..reset()
      ..start();
    final runOptions = OrtRunOptions();
    final requestedOutputs = <String>[
      _heatmapOutputName ?? _outputNames!.first,
    ];
    final List<OrtValue?> outputs;
    final int ortUs;
    try {
      outputs =
          await (_ortSession!.runAsync(runOptions, <String, OrtValue>{
                _inputName!: inputTensor,
              }, requestedOutputs) ??
              Future<List<OrtValue?>>.value(
                _ortSession!.run(runOptions, <String, OrtValue>{
                  _inputName!: inputTensor,
                }, requestedOutputs),
              ));
      ortUs = sw.elapsedMicroseconds;
    } finally {
      inputTensor.release();
      runOptions.release();
    }
    sw
      ..reset()
      ..start();
    if (outputs.isEmpty) {
      return (
        result: const CornerDetectionResult(
          points: <CornerPoint>[],
          message: 'Model produced no outputs',
        ),
        metrics: _InferMetrics(
          tensorUs: tensorUs,
          ortUs: ortUs,
          toDartHeatmapUs: sw.elapsedMicroseconds,
          cornersUs: 0,
        ),
      );
    }
    final value = outputs.first?.value;
    final heatmap = _extractHeatmap(value);
    final toDartUs = sw.elapsedMicroseconds;
    int? hmW;
    int? hmH;
    if (heatmap != null) {
      for (final ch in heatmap) {
        if (ch.isNotEmpty && ch.first.isNotEmpty) {
          hmH = ch.length;
          hmW = ch.first.length;
          break;
        }
      }
    }
    for (final o in outputs) {
      o?.release();
    }
    sw
      ..reset()
      ..start();
    if (heatmap == null || heatmap.length < 4) {
      return (
        result: const CornerDetectionResult(
          points: <CornerPoint>[],
          message: 'Invalid heatmap output',
        ),
        metrics: _InferMetrics(
          tensorUs: tensorUs,
          ortUs: ortUs,
          toDartHeatmapUs: toDartUs,
          cornersUs: sw.elapsedMicroseconds,
          hmW: hmW,
          hmH: hmH,
        ),
      );
    }
    final points = _cornersFromHeatmap(
      heatmap,
      originalW: originalW,
      originalH: originalH,
      transform: transform,
    );
    final cornersUs = sw.elapsedMicroseconds;
    final metrics = _InferMetrics(
      tensorUs: tensorUs,
      ortUs: ortUs,
      toDartHeatmapUs: toDartUs,
      cornersUs: cornersUs,
      hmW: hmW,
      hmH: hmH,
    );
    if (points.length != 4) {
      return (
        result: const CornerDetectionResult(
          points: <CornerPoint>[],
          message: 'Failed to get 4 corners from current frame',
        ),
        metrics: metrics,
      );
    }
    return (result: CornerDetectionResult(points: points), metrics: metrics);
  }

  _PreprocessedInput _preprocessImageToNchw(
    img.Image image, {
    List<CornerPoint>? roiHint,
  }) {
    Rect? roiRegion;
    if (roiHint != null && roiHint.length == 4) {
      roiRegion = _cameraRegionFromHint(
        roiHint,
        image.width.toDouble(),
        image.height.toDouble(),
      );
    }
    final roiLabel = roiRegion == null
        ? 'full'
        : '${roiRegion.width.toInt()}x${roiRegion.height.toInt()}@${roiRegion.left.toInt()},${roiRegion.top.toInt()}';

    final _LetterboxTransform transform;
    if (roiRegion == null) {
      transform = _LetterboxTransform.fromOriginal(
        originalWidth: image.width.toDouble(),
        originalHeight: image.height.toDouble(),
        inputSize: _modelInputSize.toDouble(),
      );
    } else {
      final region = roiRegion;
      transform = _LetterboxTransform.fromRegion(
        left: region.left,
        top: region.top,
        regionWidth: region.width,
        regionHeight: region.height,
        originalWidth: image.width.toDouble(),
        originalHeight: image.height.toDouble(),
        inputSize: _modelInputSize.toDouble(),
      );
    }
    final hw = _modelInputSize * _modelInputSize;
    final out = Float32List(3 * hw);
    for (var y = 0; y < _modelInputSize; y++) {
      final srcY = transform.tryInputToOriginalY(y + 0.5);
      if (srcY == null) continue;
      final sy = srcY.floor().clamp(0, image.height - 1);
      for (var x = 0; x < _modelInputSize; x++) {
        final srcX = transform.tryInputToOriginalX(x + 0.5);
        if (srcX == null) continue;
        final sx = srcX.floor().clamp(0, image.width - 1);
        final p = image.getPixel(sx, sy);
        final i = y * _modelInputSize + x;
        // Model was trained from OpenCV BGR.
        out[i] = p.b.toDouble() / 255.0;
        out[hw + i] = p.g.toDouble() / 255.0;
        out[2 * hw + i] = p.r.toDouble() / 255.0;
      }
    }
    return _PreprocessedInput(out, transform, roiLabel: roiLabel);
  }

  _PreprocessedInput _preprocessSnapshotToNchw(
    CameraYuvSnapshot image, {
    List<CornerPoint>? roiHint,
  }) {
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final uvPixelStride = image.planes[1].bytesPerPixel;
    final hw = _modelInputSize * _modelInputSize;
    final out = Float32List(3 * hw);
    final region = _cameraRegionFromHint(
      roiHint,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final roiLabel = (roiHint == null || roiHint.length != 4)
        ? 'full'
        : '${region.width.toInt()}x${region.height.toInt()}@${region.left.toInt()},${region.top.toInt()}';
    final cache = _getSnapshotPreprocessCache(image, region);
    final transform = cache.transform;

    for (var y = 0; y < _modelInputSize; y++) {
      final sy = cache.sourceYs[y];
      if (sy < 0) continue;
      final yRow = cache.yRows[y];
      final uvRow = cache.uvRows[y];
      for (var x = 0; x < _modelInputSize; x++) {
        final sx = cache.sourceXs[x];
        if (sx < 0) continue;
        final yValue = yPlane[yRow + sx];
        final uvIndex = uvRow + (sx >> 1) * uvPixelStride;
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        final r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255);
        final g =
            (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
                .clamp(0, 255);
        final b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255);

        final i = y * _modelInputSize + x;
        out[i] = b / 255.0;
        out[hw + i] = g / 255.0;
        out[2 * hw + i] = r / 255.0;
      }
    }
    return _PreprocessedInput(out, transform, roiLabel: roiLabel);
  }

  Rect _cameraRegionFromHint(
    List<CornerPoint>? roiHint,
    double width,
    double height,
  ) {
    if (roiHint == null || roiHint.length != 4) {
      return Rect.fromLTWH(0, 0, width, height);
    }

    var minX = roiHint.first.x;
    var minY = roiHint.first.y;
    var maxX = roiHint.first.x;
    var maxY = roiHint.first.y;
    for (final point in roiHint.skip(1)) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }

    final padX = math.max(48.0, (maxX - minX) * 0.35);
    final padY = math.max(48.0, (maxY - minY) * 0.35);
    final left = (minX - padX).clamp(0.0, width - 2.0);
    final top = (minY - padY).clamp(0.0, height - 2.0);
    final right = (maxX + padX).clamp(left + 2.0, width);
    final bottom = (maxY + padY).clamp(top + 2.0, height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  _CameraPreprocessCache _getSnapshotPreprocessCache(
    CameraYuvSnapshot image,
    Rect region,
  ) {
    final cache = _cameraPreprocessCache;
    if (cache != null &&
        cache.width == image.width &&
        cache.height == image.height &&
        cache.yStride == image.planes[0].bytesPerRow &&
        cache.uvStride == image.planes[1].bytesPerRow &&
        cache.region == region) {
      return cache;
    }

    if (kDebugMode) {
      debugPrint(
        '[OnnxCornerDetector] preprocess cache rebuild ${image.width}x${image.height} '
        'region=${region.width.toInt()}x${region.height.toInt()}@${region.left.toInt()},${region.top.toInt()}',
      );
    }

    final transform = _LetterboxTransform.fromRegion(
      left: region.left,
      top: region.top,
      regionWidth: region.width,
      regionHeight: region.height,
      originalWidth: image.width.toDouble(),
      originalHeight: image.height.toDouble(),
      inputSize: _modelInputSize.toDouble(),
    );
    final sourceXs = List<int>.filled(_modelInputSize, -1);
    for (var x = 0; x < _modelInputSize; x++) {
      final srcX = transform.tryInputToOriginalX(x + 0.5);
      if (srcX != null) {
        sourceXs[x] = srcX.floor().clamp(0, image.width - 1);
      }
    }

    final sourceYs = List<int>.filled(_modelInputSize, -1);
    final yRows = List<int>.filled(_modelInputSize, 0);
    final uvRows = List<int>.filled(_modelInputSize, 0);
    for (var y = 0; y < _modelInputSize; y++) {
      final srcY = transform.tryInputToOriginalY(y + 0.5);
      if (srcY == null) continue;
      final sy = srcY.floor().clamp(0, image.height - 1);
      sourceYs[y] = sy;
      yRows[y] = sy * image.planes[0].bytesPerRow;
      uvRows[y] = (sy >> 1) * image.planes[1].bytesPerRow;
    }

    final nextCache = _CameraPreprocessCache(
      width: image.width,
      height: image.height,
      yStride: image.planes[0].bytesPerRow,
      uvStride: image.planes[1].bytesPerRow,
      sourceXs: sourceXs,
      sourceYs: sourceYs,
      yRows: yRows,
      uvRows: uvRows,
      transform: transform,
      region: region,
    );
    _cameraPreprocessCache = nextCache;
    return nextCache;
  }

  List<List<List<double>>>? _extractHeatmap(Object? value) {
    if (value is! List || value.isEmpty) return null;
    dynamic root = value;
    // [1, C, H, W] -> [C, H, W]
    if (root is List && root.length == 1 && root[0] is List) {
      root = root[0];
    }
    if (root is! List || root.isEmpty) return null;
    final channels = <List<List<double>>>[];
    for (final ch in root) {
      if (ch is! List) continue;
      final rows = <List<double>>[];
      for (final row in ch) {
        if (row is! List) continue;
        rows.add(row.map((e) => (e as num).toDouble()).toList(growable: false));
      }
      if (rows.isNotEmpty) {
        channels.add(rows);
      }
    }
    return channels.isEmpty ? null : channels;
  }

  List<CornerPoint> _cornersFromHeatmap(
    List<List<List<double>>> heatmap, {
    required int originalW,
    required int originalH,
    required _LetterboxTransform transform,
  }) {
    final points = <CornerPoint>[];
    final maxChannels = math.min(4, heatmap.length);
    for (var ch = 0; ch < maxChannels; ch++) {
      final hm = heatmap[ch];
      if (hm.isEmpty || hm.first.isEmpty) continue;
      final comp = _largestComponentCentroid(hm, _heatmapThreshold);
      if (comp == null) continue;
      final hmH = hm.length;
      final hmW = hm.first.length;
      final center = comp.$1;
      final inputX = (center.dx + 0.5) * _modelInputSize / hmW;
      final inputY = (center.dy + 0.5) * _modelInputSize / hmH;
      final originalX = transform.tryInputToOriginalX(inputX);
      final originalY = transform.tryInputToOriginalY(inputY);
      if (originalX == null || originalY == null) continue;
      points.add(
        CornerPoint(
          originalX.clamp(0.0, originalW.toDouble()),
          originalY.clamp(0.0, originalH.toDouble()),
        ),
      );
    }
    return points;
  }

  (_Point2, int)? _largestComponentCentroid(
    List<List<double>> hm,
    double threshold,
  ) {
    final h = hm.length;
    final w = hm.first.length;
    final visited = List<List<bool>>.generate(
      h,
      (_) => List<bool>.filled(w, false),
    );
    _Point2? bestCenter;
    var bestArea = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (visited[y][x] || hm[y][x] < threshold) continue;
        final qx = <int>[x];
        final qy = <int>[y];
        visited[y][x] = true;
        var head = 0;
        var area = 0;
        var sumX = 0.0;
        var sumY = 0.0;
        while (head < qx.length) {
          final cx = qx[head];
          final cy = qy[head];
          head++;
          area++;
          sumX += cx;
          sumY += cy;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = cx + dx;
              final ny = cy + dy;
              if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
              if (visited[ny][nx] || hm[ny][nx] < threshold) continue;
              visited[ny][nx] = true;
              qx.add(nx);
              qy.add(ny);
            }
          }
        }
        if (area > bestArea) {
          bestArea = area;
          bestCenter = _Point2(sumX / area, sumY / area);
        }
      }
    }
    if (bestCenter == null) return null;
    return (bestCenter, bestArea);
  }

  List<CornerPoint> _orderPointsClockwise(List<CornerPoint> pts) {
    if (pts.length != 4) return pts;
    final cx = pts.fold<double>(0, (p, e) => p + e.x) / 4.0;
    final cy = pts.fold<double>(0, (p, e) => p + e.y) / 4.0;
    final sorted = [...pts]
      ..sort((a, b) {
        final aa = math.atan2(a.y - cy, a.x - cx);
        final bb = math.atan2(b.y - cy, b.x - cx);
        return aa.compareTo(bb);
      });
    var start = 0;
    var min = sorted[0].x + sorted[0].y;
    for (var i = 1; i < sorted.length; i++) {
      final s = sorted[i].x + sorted[i].y;
      if (s < min) {
        min = s;
        start = i;
      }
    }
    return [...sorted.sublist(start), ...sorted.sublist(0, start)];
  }

  /// 释放进程级 OrtSession。仅在应用确需归还原生内存（如 low-memory 回调）时调用。
  /// 正常页面生命周期无需调，singleton 常驻复用。
  Future<void> releaseAll() async {
    try {
      _lcnetSession?.release();
      _lcnetSession = null;
      _lcnetSessionOptions?.release();
      _lcnetSessionOptions = null;
      _ortSession?.release();
      _ortSession = null;
      _ortSessionOptions?.release();
      _ortSessionOptions = null;
      _cameraPreprocessCache = null;
      _initFuture = null;
    } catch (_) {}
  }
}

class _Point2 {
  const _Point2(this.dx, this.dy);

  final double dx;
  final double dy;
}

class _InferMetrics {
  const _InferMetrics({
    this.tensorUs = 0,
    this.ortUs = 0,
    this.toDartHeatmapUs = 0,
    this.cornersUs = 0,
    this.hmW,
    this.hmH,
  });

  static const _InferMetrics empty = _InferMetrics();

  final int tensorUs;
  final int ortUs;
  final int toDartHeatmapUs;
  final int cornersUs;
  final int? hmW;
  final int? hmH;
}

class _PreprocessedInput {
  const _PreprocessedInput(
    this.input,
    this.transform, {
    this.roiLabel = 'full',
  });

  final Float32List input;
  final _LetterboxTransform transform;
  final String roiLabel;
}

class _CameraPreprocessCache {
  const _CameraPreprocessCache({
    required this.width,
    required this.height,
    required this.yStride,
    required this.uvStride,
    required this.sourceXs,
    required this.sourceYs,
    required this.yRows,
    required this.uvRows,
    required this.transform,
    required this.region,
  });

  final int width;
  final int height;
  final int yStride;
  final int uvStride;
  final List<int> sourceXs;
  final List<int> sourceYs;
  final List<int> yRows;
  final List<int> uvRows;
  final _LetterboxTransform transform;
  final Rect region;
}

class _LetterboxTransform {
  const _LetterboxTransform({
    required this.left,
    required this.top,
    required this.regionWidth,
    required this.regionHeight,
    required this.originalWidth,
    required this.originalHeight,
    required this.inputSize,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.scaledWidth,
    required this.scaledHeight,
  });

  factory _LetterboxTransform.fromOriginal({
    required double originalWidth,
    required double originalHeight,
    required double inputSize,
  }) {
    return _LetterboxTransform.fromRegion(
      left: 0,
      top: 0,
      regionWidth: originalWidth,
      regionHeight: originalHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      inputSize: inputSize,
    );
  }

  factory _LetterboxTransform.fromRegion({
    required double left,
    required double top,
    required double regionWidth,
    required double regionHeight,
    required double originalWidth,
    required double originalHeight,
    required double inputSize,
  }) {
    final scale = math.min(inputSize / regionWidth, inputSize / regionHeight);
    final scaledWidth = regionWidth * scale;
    final scaledHeight = regionHeight * scale;
    final padX = (inputSize - scaledWidth) / 2.0;
    final padY = (inputSize - scaledHeight) / 2.0;
    return _LetterboxTransform(
      left: left,
      top: top,
      regionWidth: regionWidth,
      regionHeight: regionHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      inputSize: inputSize,
      scale: scale,
      padX: padX,
      padY: padY,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
    );
  }

  final double left;
  final double top;
  final double regionWidth;
  final double regionHeight;
  final double originalWidth;
  final double originalHeight;
  final double inputSize;
  final double scale;
  final double padX;
  final double padY;
  final double scaledWidth;
  final double scaledHeight;

  double? tryInputToOriginalX(double inputX) {
    if (inputX < padX || inputX >= padX + scaledWidth) {
      return null;
    }
    return (left + (inputX - padX) / scale).clamp(0.0, originalWidth - 1.0);
  }

  double? tryInputToOriginalY(double inputY) {
    if (inputY < padY || inputY >= padY + scaledHeight) {
      return null;
    }
    return (top + (inputY - padY) / scale).clamp(0.0, originalHeight - 1.0);
  }
}
