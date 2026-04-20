part of 'camera_scan_page.dart';

typedef _GalleryModeHandler = Future<void> Function(Uint8List jpegBytes);

extension _CameraGalleryHandlers on _CameraScanPageState {
  Map<CameraCaptureMode, _GalleryModeHandler> _galleryModeHandlers() {
    return <CameraCaptureMode, _GalleryModeHandler>{
      CameraCaptureMode.scan: _processScanFromGallery,
      CameraCaptureMode.aiCutout: _processMattingFromGallery,
      CameraCaptureMode.eSignatureScan: _processMattingFromGallery,
      CameraCaptureMode.formulaRecognition: _processFormulaFromGallery,
      CameraCaptureMode.textRecognition: _processVisionTextFromGallery,
      CameraCaptureMode.translate: _processVisionTranslateFromGallery,
      CameraCaptureMode.objectRecognition: _processVisionObjectFromGallery,
    };
  }

  Future<void> _runGalleryModeFlow(Uint8List jpegBytes) async {
    final handler = _galleryModeHandlers()[_mode];
    if (handler != null) {
      await handler(jpegBytes);
      return;
    }
    await _openGalleryPreviewFallback(jpegBytes);
  }

  Future<void> _processScanFromGallery(Uint8List jpegBytes) async {
    _setState(() => _hint = '正在处理相册图片...');
    final decodeResult = await compute(
      _decodeAndBakeTask,
      _DecodeTaskArgs(jpegBytes),
    );
    if (decodeResult == null) {
      if (mounted) {
        _setState(() {
          _isCapturing = false;
          _hint = '无法解码相册图片';
        });
      }
      return;
    }
    final baked = decodeResult.baked;
    final detect = await _detector.detectFromImage(baked);
    if (!detect.hasFourCorners) {
      if (mounted) {
        _setState(() {
          _isCapturing = false;
          _hint = '相册图片未检测到四边形，请更换图片';
        });
      }
      return;
    }
    final cropped = await compute(
      _cropTask,
      _CropTaskArgs(baked, detect.points),
    );
    if (cropped == null) {
      if (mounted) {
        _setState(() {
          _isCapturing = false;
          _hint = '相册图片裁剪失败，请重试';
        });
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StylePage(croppedBytes: cropped),
      ),
    );
  }

  Future<void> _processMattingFromGallery(Uint8List jpegBytes) async {
    _setState(() => _hint = '正在抠图，请稍候...');
    final png = await _mattingService.processCameraJpeg(
      jpegBytes,
      model: CreatinfMattingModel.highPrecision,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MattingResultPreviewPage(pngBytes: png),
      ),
    );
  }

  Future<void> _processFormulaFromGallery(Uint8List jpegBytes) async {
    if (!mounted) return;
    final croppedBin = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => FormulaManualCropPage(
          imageBytes: Uint8List.fromList(jpegBytes),
        ),
      ),
    );
    if (!mounted) return;
    if (croppedBin == null) {
      _setState(() => _hint = _idleHint());
      return;
    }
    _setState(() => _hint = '正在识别公式...');
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
  }

  Future<void> _openGalleryPreviewFallback(Uint8List jpegBytes) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlainCapturePreviewPage(
          imageBytes: jpegBytes,
          modeTitle: _mode.title,
        ),
      ),
    );
  }
}
