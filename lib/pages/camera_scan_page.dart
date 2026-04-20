import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
import '../models/camera_capture_mode.dart';
import '../models/corner_point.dart';
import '../models/camera_yuv_snapshot.dart';
import '../services/creatinf_matting_service.dart';
import '../services/network_reachability.dart';
import '../services/open_router_vision_tasks_client.dart';
import '../services/latex_ocr_service.dart';
import '../services/onnx_corner_detector.dart';
import '../services/perspective_cropper.dart';
import '../theme/app_tokens.dart';
import '../widgets/camera_mode_strip.dart';
import '../widgets/document_overlay_painter.dart';
import 'formula_latex_result_page.dart';
import 'formula_manual_crop_page.dart';
import 'feature_unavailable_page.dart';
import 'id_photo_result_page.dart';
import 'inpaint_editor_page.dart';
import 'llm_vision_task_result_page.dart';
import 'matting_result_preview_page.dart';
import 'plain_capture_preview_page.dart';
import 'style_page.dart';

part 'camera_scan_page_overlay.dart';
part 'camera_scan_page_image_tasks.dart';
part 'camera_scan_page_capture_orchestrator.dart';
part 'camera_scan_page_mode_actions.dart';
part 'camera_scan_page_gallery_handlers.dart';
part 'camera_scan_page_vision_llm.dart';
part 'camera_scan_page_idphoto_inpaint.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({
    super.key,
    this.initialMode = CameraCaptureMode.scan,
    this.returnScanResult = false,
  });

  /// 从主页等功能入口进入时指定；默认 [CameraCaptureMode.scan]。
  final CameraCaptureMode initialMode;

  /// 为 `true` 时，扫描模式拍摄成功后直接 `pop(croppedBytes)` 返回，不进入 `StylePage`。
  final bool returnScanResult;

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>
    with WidgetsBindingObserver {
  final OnnxCornerDetector _detector = OnnxCornerDetector();
  final CreatinfMattingService _mattingService = CreatinfMattingService();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _controller;
  CameraDescription? _cameraDescription;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  List<CornerPoint> _points = const <CornerPoint>[];
  List<CornerPoint> _prevSmoothed = const <CornerPoint>[];
  String _hint = '正在初始化相机...';
  Size _imageSize = Size.zero;
  int _stableFrames = 0;

  /// 预览双指缩放（光学/数码变焦），与 [CameraController.setZoomLevel] 对应。
  double _zoomMin = 1.0;
  double _zoomMax = 1.0;
  double _zoom = 1.0;
  double _pinchBaseZoom = 1.0;

  late CameraCaptureMode _mode;
  late final PageController _modePageController;

  /// 离开「扫描」时自增，用于丢弃仍在进行中的预览推理结果，避免其它模式下仍跑 ONNX。
  int _scanStreamEpoch = 0;

  /// 略小则更跟手慢、边缘抖动更小；与叠加层 Ticker 插值叠加后观感更顺。
  static const double _smoothAlpha = 0.28;

  /// 全程使用高分辨率，避免拍照时重建控制器导致对焦丢失
  static const ResolutionPreset _kCameraPreset = ResolutionPreset.veryHigh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    _modePageController = PageController(
      initialPage: widget.initialMode.index,
      viewportFraction: 0.26,
    );
    if (!_mode.isScan) {
      _scanStreamEpoch++;
    }
    _setup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进入系统相册/切后台时，Camera 纹理与流在部分机型会失效，恢复时重绑控制器更稳定。
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_teardownCameraController());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_rebindCameraIfNeeded());
    }
  }

  bool get _zoomUsable => (_zoomMax - _zoomMin) > 0.02;

  /// Part 文件里的 `extension on _CameraScanPageState` 无法调用受保护的 [State.setState]。
  void _setState(VoidCallback fn) {
    setState(fn);
  }

  String _idleHint() {
    final pinch = _zoomUsable ? ' · 双指缩放取景' : '';
    if (_mode.isScan) return '请将文档完整放入取景框$pinch';
    if (_mode == CameraCaptureMode.aiCutout) {
      return '拍照后进行 AI 抠图（需网络）$pinch';
    }
    if (_mode == CameraCaptureMode.eSignatureScan) {
      return '请将签名写在白纸上，置于取景框内（拍照前会再次确认）$pinch';
    }
    if (_mode == CameraCaptureMode.formulaRecognition) {
      return '拍摄清晰公式，识别后可复制 LaTeX；尽量让公式占满画面、减少杂物$pinch';
    }
    if (_mode == CameraCaptureMode.textRecognition) {
      return '拍摄含文字的主体，尽量让文字清晰、占满画面$pinch';
    }
    if (_mode == CameraCaptureMode.translate) {
      return '拍摄需翻译的画面，保持文字清晰$pinch';
    }
    if (_mode == CameraCaptureMode.objectRecognition) {
      return '将待识别物体置于画面中央，光线充足$pinch';
    }
    if (_mode == CameraCaptureMode.idPhoto) {
      return '拍摄正面免冠人像，自动生成证件照$pinch';
    }
    if (_mode == CameraCaptureMode.aiErase) {
      return '拍照后涂抹要消除区域，自动重绘修复$pinch';
    }
    return '普通拍照：${_mode.title}$pinch';
  }

  void _onModePageChanged(int index) {
    final next = CameraCaptureMode.values[index];
    if (!next.isScan) {
      _scanStreamEpoch++;
    }
    setState(() {
      _mode = next;
      if (_mode.isScan) {
        _hint = _idleHint();
      } else {
        _points = [];
        _prevSmoothed = [];
        _stableFrames = 0;
        _hint = _idleHint();
      }
    });
    // 非扫描模式必须停 ImageStream，否则仍会刷帧导致 ImageReader 缓冲耗尽。
    unawaited(_syncImageStreamToMode());
  }

  /// 仅「扫描」需要分析流；其它模式只保留相机纹理预览，不推 YUV 帧。
  Future<void> _syncImageStreamToMode() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _isCapturing) {
      return;
    }
    try {
      if (_mode.isScan) {
        if (!c.value.isStreamingImages) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          if (!mounted || _controller != c || !_mode.isScan || _isCapturing) {
            return;
          }
          await c.startImageStream(_onImage);
        }
      } else {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hint = '预览流切换失败: $e');
      }
    }
  }

  Future<void> _setup() async {
    try {
      await _detector.init();
      final cameras = await availableCameras();
      _cameraDescription = _selectPreferredCamera(cameras);
      await _bindCamera(resetCornerTracking: false);
      if (!mounted) return;
      await _syncImageStreamToMode();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hint = '初始化失败: $e';
      });
    }
  }

  CameraDescription _selectPreferredCamera(List<CameraDescription> cameras) {
    if (cameras.isEmpty) {
      throw StateError('No camera available');
    }
    final back = cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();
    if (back.isEmpty) {
      return cameras.first;
    }

    int score(CameraDescription c) {
      final text = '${c.name} ${c.toString()}'.toLowerCase();
      var s = 0;
      final idText = c.name.trim();
      final idNum = int.tryParse(idText);
      // 惩罚超广角/微距镜头，优先常用主摄。
      if (text.contains('ultra') ||
          text.contains('uw') ||
          text.contains('wide') ||
          text.contains('0.5') ||
          text.contains('0,5') ||
          text.contains('0.6') ||
          text.contains('0,6') ||
          text.contains('macro')) {
        s -= 20;
      }
      if (text.contains('main') ||
          text.contains('default') ||
          text.contains('back') ||
          text.contains('1x') ||
          text.contains('1.0')) {
        s += 10;
      }
      // Android 上通常后置主摄是较小编号（经常是 0），提高其优先级。
      if (idNum != null) {
        s += (10 - idNum).clamp(0, 10);
      }
      return s;
    }

    back.sort((a, b) => score(b).compareTo(score(a)));
    return back.first;
  }

  Future<void> _teardownCameraController() async {
    final c = _controller;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) {
        await c.stopImageStream();
      }
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (_controller == c) {
        _controller = null;
      }
      _isProcessingFrame = false;
    });
  }

  Future<void> _rebindCameraIfNeeded() async {
    if (!mounted) return;
    if (_controller != null && _controller!.value.isInitialized) return;
    await _bindCamera(resetCornerTracking: false);
    await _syncImageStreamToMode();
  }

  Future<Uint8List?> _normalizeToJpegBytes(Uint8List sourceBytes) async {
    final baked = await compute(_decodeAndBakeTask, _DecodeTaskArgs(sourceBytes));
    if (baked == null) return null;
    final jpg = await compute(_encodeJpegTask, baked.baked);
    return jpg.isEmpty ? null : jpg;
  }

  Future<void> _bindCamera({
    required bool resetCornerTracking,
  }) async {
    final desc = _cameraDescription;
    if (desc == null) return;
    final controller = CameraController(
      desc,
      _kCameraPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

    var zoomMin = 1.0;
    var zoomMax = 1.0;
    var zoomCur = 1.0;
    try {
      zoomMin = await controller.getMinZoomLevel();
      zoomMax = await controller.getMaxZoomLevel();
      if (zoomMax < zoomMin) {
        final t = zoomMin;
        zoomMin = zoomMax;
        zoomMax = t;
      }
      // Android 11+ 常见「逻辑后置相机」：minZoom < 1.0 对应超广角，插件默认取 min 会一直是广角视野。
      // 系统相机里的「1×」通常对应 zoom ratio ≈ 1.0，见 Android 多摄与 zoom ratio 说明及社区讨论。
      zoomCur = zoomMin < 0.999 ? 1.0.clamp(zoomMin, zoomMax) : zoomMin;
      if (zoomMax - zoomMin > 0.02) {
        await controller.setZoomLevel(zoomCur);
      }
    } catch (e) {
      debugPrint('[CameraScan] zoom init: $e');
      zoomMin = 1.0;
      zoomMax = 1.0;
      zoomCur = 1.0;
    }

    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}

    final ps = controller.value.previewSize;
    if (ps != null) {
      _imageSize = Size(ps.width, ps.height);
    }
    await controller.startImageStream(_onImage);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _zoomMin = zoomMin;
      _zoomMax = zoomMax;
      _zoom = zoomCur;
      _pinchBaseZoom = zoomCur;
      _hint = _idleHint();
      if (resetCornerTracking) {
        _points = [];
        _prevSmoothed = [];
        _stableFrames = 0;
      }
    });
  }

  Future<void> _resumePreviewAfterCapture() async {
    try {
      if (_controller != null && !_controller!.value.isStreamingImages) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // 勿用 _isCapturing 拦截：若干拍照流程在 finally 里先 resume 再置 false，否则会跳过恢复与 setState，预览卡死。
        if (!mounted || _controller == null) {
          return;
        }
        if (_mode.isScan) {
          await _controller!.startImageStream(_onImage);
        }
        if (mounted) {
          setState(() {
            _points = [];
            _prevSmoothed = [];
            _stableFrames = 0;
            _hint = _idleHint();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hint = '预览恢复失败: $e');
      }
    }
  }

  /// 停止分析流并暂停预览，避免主线程长时间推理或结果页盖住相机时 Android ImageReader 缓冲耗尽。
  Future<void> _pauseCameraPipeline() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (c.value.isStreamingImages) {
        await c.stopImageStream();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (c.value.isPreviewPaused) return;
      await c.pausePreview();
    } catch (e) {
      debugPrint('[CameraScan] pauseCameraPipeline: $e');
    }
  }

  /// 恢复预览并按模式决定是否重启角点分析流。
  Future<void> _resumeCameraPipeline() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (e) {
      debugPrint('[CameraScan] resumeCameraPipeline: $e');
    }
    await _resumePreviewAfterCapture();
  }

  List<CornerPoint> _smoothFour(
    List<CornerPoint> prev,
    List<CornerPoint> next,
  ) {
    if (prev.length != 4 || next.length != 4) return next;
    return List<CornerPoint>.generate(
      4,
      (i) => CornerPoint(
        prev[i].x * (1 - _smoothAlpha) + next[i].x * _smoothAlpha,
        prev[i].y * (1 - _smoothAlpha) + next[i].y * _smoothAlpha,
      ),
    );
  }

  /// 先同步拷贝 YUV 再 `unawaited` 推理，使预览回调尽快返回，避免 ImageReader 缓冲耗尽。
  Future<void> _onImage(CameraImage frame) async {
    if (!_mode.isScan) return;
    if (_isProcessingFrame || _isCapturing) return;

    final snap = CameraYuvSnapshot.from(frame);
    final roiHint = _prevSmoothed.length == 4
        ? List<CornerPoint>.from(_prevSmoothed)
        : null;
    final epoch = _scanStreamEpoch;
    _isProcessingFrame = true;
    unawaited(_processStreamSnapshot(snap, roiHint, epoch));
  }

  Future<void> _processStreamSnapshot(
    CameraYuvSnapshot snap,
    List<CornerPoint>? roiHint,
    int epoch,
  ) async {
    try {
      if (!_mode.isScan || epoch != _scanStreamEpoch) {
        return;
      }
      final wall = Stopwatch()..start();
      final result = await _detector.detectFromYuvSnapshot(
        snap,
        roiHint: roiHint,
      );
      wall.stop();
      if (kDebugMode) {
        debugPrint(
          '[CameraScan] imageStream wall=${wall.elapsedMilliseconds}ms '
          'detectorTotal=${result.inferenceMs ?? '?'}ms',
        );
      }
      if (!mounted || !_mode.isScan || epoch != _scanStreamEpoch) {
        return;
      }
      setState(() {
        final iw = result.imageWidth ?? snap.width.toDouble();
        final ih = result.imageHeight ?? snap.height.toDouble();
        _imageSize = Size(iw, ih);

        if (result.hasFourCorners) {
          final next = result.points;
          _points = _smoothFour(_prevSmoothed, next);
          _prevSmoothed = List<CornerPoint>.from(_points);
          _stableFrames++;
          _hint = '已识别文档边缘 (${result.inferenceMs ?? 0}ms)';
        } else {
          _points = [];
          _prevSmoothed = [];
          _stableFrames = 0;
          _hint =
              result.message ?? 'Failed to get 4 corners from current frame';
        }
      });
    } catch (e, st) {
      debugPrint('[CameraScan] detectFromYuvSnapshot failed: $e\n$st');
      if (mounted && _mode.isScan && epoch == _scanStreamEpoch) {
        setState(() => _hint = '识别异常: $e');
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  DeviceOrientation _applicableOrientation(CameraValue value) {
    return value.isRecordingVideo
        ? value.recordingOrientation!
        : (value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation);
  }

  bool _isLandscape(CameraValue value) {
    final orientation = _applicableOrientation(value);
    return orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
  }

  int _deviceTurns(CameraValue value) {
    return switch (_applicableOrientation(value)) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeRight => 1,
      DeviceOrientation.portraitDown => 2,
      DeviceOrientation.landscapeLeft => 3,
    };
  }

  int _bufferToDisplayQuarterTurns(CameraValue value) {
    final sensorTurns = (value.description.sensorOrientation ~/ 90) % 4;
    final deviceTurns = _deviceTurns(value);
    if (value.description.lensDirection == CameraLensDirection.front) {
      return (sensorTurns + deviceTurns) % 4;
    }
    return (sensorTurns - deviceTurns + 4) % 4;
  }

  double _previewAspectRatio(CameraValue value) {
    return _isLandscape(value) ? value.aspectRatio : (1 / value.aspectRatio);
  }

  Future<void> _applyZoomLevel(CameraController c, double z) async {
    try {
      await c.setZoomLevel(z.clamp(_zoomMin, _zoomMax));
    } catch (e) {
      debugPrint('[CameraScan] setZoomLevel: $e');
    }
  }

  Widget _wrapPreviewWithPinchZoom(CameraController c, Widget child) {
    if (!_zoomUsable) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) {
        _pinchBaseZoom = _zoom;
      },
      onScaleUpdate: (details) {
        if (!c.value.isInitialized || _isCapturing) return;
        final next =
            (_pinchBaseZoom * details.scale).clamp(_zoomMin, _zoomMax);
        if ((next - _zoom).abs() < 0.002) return;
        _zoom = next;
        unawaited(_applyZoomLevel(c, next));
      },
      child: child,
    );
  }

  Widget _buildPreviewSurface(
    CameraController controller, {
    required double viewportMaxWidth,
    required double viewportMaxHeight,
  }) {
    final value = controller.value;
    final ar = _previewAspectRatio(value);

    // 与 package:camera 的 [CameraPreview] 一致：内部已含正确 AspectRatio + 平台旋转，勿再外包一层 AspectRatio，否则会变形。
    final Widget previewCore;
    if (!_mode.isScan) {
      previewCore = CameraPreview(controller);
    } else {
      previewCore = CameraPreview(
        controller,
        child: Positioned.fill(
          child: RepaintBoundary(
            child: _SmoothDocumentOverlay(
              targetPoints: _points,
              imageSize: _imageSize,
              quarterTurns: _bufferToDisplayQuarterTurns(value),
              isMirrored:
                  value.description.lensDirection ==
                  CameraLensDirection.front,
              flipY: Platform.isAndroid &&
                  value.description.lensDirection ==
                      CameraLensDirection.back,
              flipX: Platform.isAndroid &&
                  value.description.lensDirection ==
                      CameraLensDirection.back,
            ),
          ),
        ),
      );
    }

    // 横向铺满：按传感器/预览原生宽高比定尺寸，超出视口部分上下居中裁剪。
    final w = viewportMaxWidth.clamp(0.0, double.infinity);
    final h = ar > 0 ? w / ar : viewportMaxHeight;

    return _wrapPreviewWithPinchZoom(
      controller,
      SizedBox(
        width: viewportMaxWidth,
        height: viewportMaxHeight,
        child: ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: w,
              height: h,
              child: previewCore,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    final t0 = DateTime.now();
    try {
      // 停止预览流以释放 ImageReader 缓冲，防止 takePicture 时 OOM
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (!mounted) return;
      setState(() => _hint = '正在处理高清图像...');

      final shot = await _controller!.takePicture();
      final rawBytes = await File(shot.path).readAsBytes();
      
      final afterShot = DateTime.now();
      if (kDebugMode) {
        debugPrint(
          '[capture] takePicture ${afterShot.difference(t0).inMilliseconds}ms, '
          'bytes=${rawBytes.length}',
        );
      }
      if (!mounted) return;

      if (rawBytes.isEmpty) {
        await _resumePreviewAfterCapture();
        if (mounted) {
          setState(() {
            _hint = '拍照失败';
            _isCapturing = false;
          });
        }
        return;
      }

      // 步骤 A: 后台 Isolate 解码和旋转
      final decodeT = DateTime.now();
      final decodeResult = await compute(_decodeAndBakeTask, _DecodeTaskArgs(rawBytes));
      if (decodeResult == null) {
        await _resumePreviewAfterCapture();
        if (mounted) {
          setState(() {
            _hint = '无法解码照片';
            _isCapturing = false;
          });
        }
        return;
      }
      final baked = decodeResult.baked;

      // 步骤 B: 主线程 FastViT 推理，复用预览角点作为 ROI 提示
      final detectT0 = DateTime.now();
      
      List<CornerPoint>? mappedRoi;
      if (_prevSmoothed.length == 4) {
        // _prevSmoothed 是在预览帧坐标系（_imageSize）下的
        // baked 是旋转正向后的图像坐标系
        final sensorW = _imageSize.width;
        final sensorH = _imageSize.height;
        final bakedW = baked.width.toDouble();
        final bakedH = baked.height.toDouble();
        
        bool rotated90 = (sensorW > sensorH) != (bakedW > bakedH);
        if (rotated90) {
          // 发生了 90 度或 270 度旋转，为了安全起见，我们取归一化后的宽高的最大包围盒
          double minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
          for (var p in _prevSmoothed) {
            final nx = p.x / sensorW;
            final ny = p.y / sensorH;
            if (nx < minX) minX = nx;
            if (nx > maxX) maxX = nx;
            if (ny < minY) minY = ny;
            if (ny > maxY) maxY = ny;
          }
          // 因为不确定是顺时针还是逆时针旋转，我们分别计算两种情况的包围盒，并取并集
          // 顺时针90度: x' = 1 - y, y' = x
          final cwMinX = 1.0 - maxY; final cwMaxX = 1.0 - minY;
          final cwMinY = minX;       final cwMaxY = maxX;
          // 逆时针90度: x' = y, y' = 1 - x
          final ccwMinX = minY;      final ccwMaxX = maxY;
          final ccwMinY = 1.0 - maxX; final ccwMaxY = 1.0 - minX;
          
          final finalMinX = math.min(cwMinX, ccwMinX);
          final finalMaxX = math.max(cwMaxX, ccwMaxX);
          final finalMinY = math.min(cwMinY, ccwMinY);
          final finalMaxY = math.max(cwMaxY, ccwMaxY);

          mappedRoi = [
            CornerPoint(finalMinX * bakedW, finalMinY * bakedH),
            CornerPoint(finalMaxX * bakedW, finalMinY * bakedH),
            CornerPoint(finalMaxX * bakedW, finalMaxY * bakedH),
            CornerPoint(finalMinX * bakedW, finalMaxY * bakedH),
          ];
        } else {
          mappedRoi = _prevSmoothed.map((p) => 
            CornerPoint(p.x / sensorW * bakedW, p.y / sensorH * bakedH)
          ).toList();
        }
      }

      final detect = await _detector.detectFromImage(
        baked,
        roiHint: mappedRoi,
      );
      final detectT = DateTime.now();
      debugPrint(
        '[capture] decode+bake ${detectT0.difference(decodeT).inMilliseconds}ms, '
        'detect ${detectT.difference(detectT0).inMilliseconds}ms '
        '(${baked.width}x${baked.height})',
      );

      if (!detect.hasFourCorners) {
        await _resumePreviewAfterCapture();
        if (mounted) {
          setState(() {
            _hint = '拍照后未检测到四边形，请重试';
            _isCapturing = false;
          });
        }
        return;
      }

      // 步骤 C: 后台 Isolate 透视裁剪
      final cropT = DateTime.now();
      final cropped = await compute(_cropTask, _CropTaskArgs(baked, detect.points));
      debugPrint(
        '[capture] crop ${DateTime.now().difference(cropT).inMilliseconds}ms',
      );
      
      if (cropped == null) {
        await _resumePreviewAfterCapture();
        if (mounted) {
          setState(() {
            _hint = '裁剪失败，请重试';
            _isCapturing = false;
          });
        }
        return;
      }

      if (widget.returnScanResult && _mode.isScan) {
        if (mounted) {
          Navigator.of(context).pop<Uint8List>(cropped);
        }
        return;
      }

      if (!mounted) return;
      await _pauseCameraPipeline();
      if (!mounted) return;
      try {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StylePage(croppedBytes: cropped),
          ),
        );
      } finally {
        await _resumeCameraPipeline();
      }
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        setState(() {
          _hint = '拍照处理失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _capturePlainPhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    if (!_modeImplemented(_mode)) {
      await _openUnavailableModeHint();
      return;
    }
    await _runModeCaptureActionOrFallback();
  }

  /// AI 抠图：调用 [CreatinfMattingService]。
  Future<void> _captureAndMatting() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      if (!mounted) return;
      await _pauseCameraPipeline();
      try {
        if (!mounted) return;
        setState(() => _hint = '正在抠图，请稍候...');
        final png = await _mattingService.processCameraJpeg(
          rawBytes,
          model: CreatinfMattingModel.highPrecision,
        );

        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MattingResultPreviewPage(pngBytes: png),
          ),
        );
      } on CreatinfMattingException catch (e) {
        if (mounted) {
          setState(() {
            _hint = '抠图失败: $e';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hint = '抠图失败: $e';
          });
        }
      } finally {
        await _resumeCameraPipeline();
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        setState(() {
          _hint = '抠图失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  /// 扫描电子签名：独立流程，拍照前提示白纸签名；不调用 [_captureAndMatting]。
  Future<void> _captureSignatureMatting() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (!mounted) return;

      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('拍摄电子签名'),
          content: const Text(
            '请将签名写在白纸上，并置于取景框内。\n\n'
            '准备好后点击「继续拍照」；取消将返回预览。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续拍照'),
            ),
          ],
        ),
      );

      if (go != true) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _hint = _idleHint();
          });
        }
        await _resumePreviewAfterCapture();
        return;
      }

      if (!mounted) return;
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      if (!mounted) return;
      await _pauseCameraPipeline();
      try {
        if (!mounted) return;
        setState(() => _hint = '正在抠图，请稍候...');
        final png = await _mattingService.processCameraJpeg(
          rawBytes,
          model: CreatinfMattingModel.highPrecision,
        );

        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MattingResultPreviewPage(pngBytes: png),
          ),
        );
      } on CreatinfMattingException catch (e) {
        if (mounted) {
          setState(() {
            _hint = '抠图失败: $e';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hint = '签名拍摄失败: $e';
          });
        }
      } finally {
        await _resumeCameraPipeline();
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        setState(() {
          _hint = '签名拍摄失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _captureAndRecognizeFormula() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      if (!mounted) return;
      await _pauseCameraPipeline();
      try {
        if (!mounted) return;
        final croppedBin = await Navigator.of(context).push<Uint8List?>(
          MaterialPageRoute<Uint8List?>(
            builder: (_) => FormulaManualCropPage(
              imageBytes: Uint8List.fromList(rawBytes),
            ),
          ),
        );
        if (!mounted) return;
        if (croppedBin == null) {
          setState(() {
            _hint = _idleHint();
          });
          return;
        }
        setState(() => _hint = '正在识别公式...');
        final latex = await LatexOcrService.instance.recognizeJpeg(croppedBin);
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FormulaLatexResultPage(
              latex: latex,
              recognitionImageBytes: croppedBin,
            ),
          ),
        );
      } on LatexOcrException catch (e) {
        if (mounted) {
          setState(() {
            _hint = e.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hint = '公式识别失败: $e';
          });
        }
      } finally {
        await _resumeCameraPipeline();
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        setState(() {
          _hint = '公式识别失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _openUnavailableModeHint() async {
    await _pauseCameraPipeline();
    try {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FeatureUnavailablePage(mode: _mode),
        ),
      );
    } finally {
      await _resumeCameraPipeline();
    }
  }

  Future<void> _pickAndProcessFromGallery() async {
    if (_isCapturing) return;
    if (!_modeImplemented(_mode)) {
      await _openUnavailableModeHint();
      return;
    }
    setState(() {
      _isCapturing = true;
      _hint = '正在打开相册...';
    });

    await _pauseCameraPipeline();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (!mounted) return;
      if (picked == null) {
        setState(() {
          _isCapturing = false;
          _hint = _idleHint();
        });
        return;
      }

      final rawBytes = await picked.readAsBytes();
      if (!mounted) return;
      if (rawBytes.isEmpty) {
        setState(() {
          _isCapturing = false;
          _hint = '读取相册图片失败';
        });
        return;
      }

      // 将任意相册格式（如 HEIC/PNG/JPEG）统一为纠正方向后的 JPEG，
      // 保证后续依赖 JPEG 的服务端接口和识别流程稳定。
      final jpegBytes = await _normalizeToJpegBytes(rawBytes);
      if (!mounted) return;
      if (jpegBytes == null) {
        setState(() {
          _isCapturing = false;
          _hint = '无法解码相册图片，请选择其它图片';
        });
        return;
      }

      await _runGalleryModeFlow(jpegBytes);
    } on CreatinfMattingException catch (e) {
      if (mounted) {
        setState(() => _hint = '抠图失败: $e');
      }
    } on LatexOcrException catch (e) {
      if (mounted) {
        setState(() => _hint = e.message);
      }
    } on OpenRouterVisionTasksException catch (e) {
      if (mounted) {
        setState(() => _hint = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hint = '相册处理失败: $e');
      }
    } finally {
      await _resumeCameraPipeline();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          if (_hint == '正在打开相册...') {
            _hint = _idleHint();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _modePageController.dispose();
    _mattingService.close();
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  bool get _shutterEnabled {
    if (_isCapturing) return false;
    if (_mode.isScan) return _stableFrames >= 2;
    return true;
  }

  VoidCallback? get _shutterAction {
    if (!_shutterEnabled) return null;
    return _mode.isScan ? _captureAndProcess : _capturePlainPhoto;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.cameraForeground,
        elevation: 0,
        title: const Text('DocScan'),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: AppTokens.cameraForeground,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      body: controller == null || !controller.value.isInitialized
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '正在准备相机…',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SafeArea(
              top: true,
              child: LayoutBuilder(
                builder: (context, _) {
                  return Column(
                    children: [
                      // ── Camera preview（无顶部文案条，预览区更高）──
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LayoutBuilder(
                            builder: (context, inner) {
                              return Align(
                                alignment: Alignment.center,
                                child: _buildPreviewSurface(
                                  controller,
                                  viewportMaxWidth: inner.maxWidth,
                                  viewportMaxHeight: inner.maxHeight,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ── Mode strip ──
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: CameraModeStrip(
                          pageController: _modePageController,
                          onPageChanged: _onModePageChanged,
                        ),
                      ),

                      // ── Bottom controls ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Gallery button
                            _BottomActionButton(
                              icon: Icons.photo_library_rounded,
                              label: _galleryActionLabel(),
                              onTap: _isCapturing
                                  ? null
                                  : _pickAndProcessFromGallery,
                            ),
                            // Shutter button
                            _ShutterButton(
                              enabled: _shutterEnabled,
                              isProcessing: _isCapturing,
                              onTap: _shutterAction,
                            ),
                            const SizedBox(width: 72),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

