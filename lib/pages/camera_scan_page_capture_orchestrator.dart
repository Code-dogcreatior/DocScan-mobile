part of 'camera_scan_page.dart';

typedef _ModeAction = Future<void> Function();

extension _CameraCaptureOrchestrator on _CameraScanPageState {
  Map<CameraCaptureMode, _ModeAction> _captureModeHandlers() {
    return <CameraCaptureMode, _ModeAction>{
      CameraCaptureMode.aiCutout: _captureAndMatting,
      CameraCaptureMode.eSignatureScan: _captureSignatureMatting,
      CameraCaptureMode.formulaRecognition: _captureAndRecognizeFormula,
    };
  }

  Future<void> _runModeCaptureActionOrFallback() async {
    final handler = _captureModeHandlers()[_mode];
    if (handler != null) {
      await handler();
      return;
    }
    await _captureWithPreviewFallback();
  }

  Future<void> _captureWithPreviewFallback() async {
    setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        setState(() => _isCapturing = false);
        return;
      }
      await _pauseCameraPipeline();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PlainCapturePreviewPage(
              imageBytes: rawBytes,
              modeTitle: _mode.title,
            ),
          ),
        );
      } finally {
        await _resumeCameraPipeline();
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<Uint8List?> _captureRawPhotoBytes({
    required String busyHint,
    required String failHint,
  }) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    if (c.value.isStreamingImages) {
      await c.stopImageStream();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (!mounted) return null;
    setState(() => _hint = busyHint);
    final shot = await c.takePicture();
    final rawBytes = await File(shot.path).readAsBytes();
    try {
      await File(shot.path).delete();
    } catch (_) {}
    if (rawBytes.isEmpty) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        setState(() => _hint = failHint);
      }
      return null;
    }
    return rawBytes;
  }
}
