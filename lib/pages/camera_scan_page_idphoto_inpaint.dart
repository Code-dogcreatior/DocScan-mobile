part of 'camera_scan_page.dart';

extension _CameraIdPhotoAndInpaint on _CameraScanPageState {
  Future<void> _captureIdPhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }
    _setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) _setState(() => _isCapturing = false);
        return;
      }
      await _pauseCameraPipeline();
      try {
        _setState(() => _hint = '正在生成证件照...');
        final png = await _mattingService.processCameraJpeg(
          rawBytes,
          model: CreatinfMattingModel.highPrecision,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => IdPhotoResultPage(foregroundPngBytes: png),
          ),
        );
      } on CreatinfMattingException catch (e) {
        if (mounted) _setState(() => _hint = '证件照抠图失败: $e');
      } catch (e) {
        if (mounted) _setState(() => _hint = '证件照处理失败: $e');
      } finally {
        await _resumeCameraPipeline();
        if (mounted) _setState(() => _isCapturing = false);
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        _setState(() {
          _hint = '证件照处理失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _captureAiErase() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }
    _setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) _setState(() => _isCapturing = false);
        return;
      }
      await _pauseCameraPipeline();
      try {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => InpaintEditorPage(imageJpegBytes: rawBytes),
          ),
        );
      } finally {
        await _resumeCameraPipeline();
        if (mounted) _setState(() => _isCapturing = false);
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        _setState(() {
          _hint = 'AI 擦除失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _processIdPhotoFromGallery(Uint8List jpegBytes) async {
    _setState(() => _hint = '正在生成证件照...');
    final png = await _mattingService.processCameraJpeg(
      jpegBytes,
      model: CreatinfMattingModel.highPrecision,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IdPhotoResultPage(foregroundPngBytes: png),
      ),
    );
  }

  Future<void> _processAiEraseFromGallery(Uint8List jpegBytes) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InpaintEditorPage(imageJpegBytes: jpegBytes),
      ),
    );
  }
}
