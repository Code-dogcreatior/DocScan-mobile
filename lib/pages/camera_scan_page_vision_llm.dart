part of 'camera_scan_page.dart';

extension _CameraVisionLlm on _CameraScanPageState {
  Future<bool> _ensureOpenRouterVisionReady(String failPrefix) async {
    if (!AppEnv.hasOpenRouterKey) {
      if (mounted) {
        _setState(() => _hint = '$failPrefix：未配置云端密钥');
      }
      return false;
    }
    if (!await NetworkReachability.instance.quickCheck()) {
      if (mounted) {
        _setState(() => _hint = '$failPrefix：请检查网络连接');
      }
      return false;
    }
    return true;
  }

  Future<void> _captureVisionTextRecognition() async {
    await _captureVisionLlmCommon(
      failTitle: '文字识别',
      busyAfterShot: '正在识别文字...',
      resultPageTitle: '文字识别',
      task: OpenRouterVisionTasksClient.instance.ocrSubjectTextFromJpeg,
    );
  }

  Future<void> _captureVisionTranslate() async {
    await _captureVisionLlmCommon(
      failTitle: '翻译',
      busyAfterShot: '正在翻译...',
      resultPageTitle: '翻译',
      task: OpenRouterVisionTasksClient.instance.translateVisibleTextToZhFromJpeg,
    );
  }

  Future<void> _captureVisionObjectRecognition() async {
    await _captureVisionLlmCommon(
      failTitle: '物体识别',
      busyAfterShot: '正在识别物体...',
      resultPageTitle: '物体识别',
      task: OpenRouterVisionTasksClient.instance.describeMainSubjectZhFromJpeg,
    );
  }

  Future<void> _captureVisionLlmCommon({
    required String failTitle,
    required String busyAfterShot,
    required String resultPageTitle,
    required Future<String> Function(List<int> jpeg) task,
  }) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }
    if (!await _ensureOpenRouterVisionReady(failTitle)) {
      return;
    }

    _setState(() => _isCapturing = true);
    try {
      final rawBytes = await _captureRawPhotoBytes(
        busyHint: '正在拍照...',
        failHint: '拍照失败',
      );
      if (rawBytes == null || !mounted) {
        if (mounted) {
          _setState(() => _isCapturing = false);
        }
        return;
      }

      if (!mounted) return;
      await _pauseCameraPipeline();
      try {
        if (!mounted) return;
        _setState(() => _hint = busyAfterShot);
        final text = await task(rawBytes);
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LlmVisionTaskResultPage(
              title: resultPageTitle,
              bodyText: text,
            ),
          ),
        );
      } on OpenRouterVisionTasksException catch (e) {
        if (mounted) {
          _setState(() => _hint = e.message);
        }
      } catch (e) {
        if (mounted) {
          _setState(() => _hint = '$failTitle失败: $e');
        }
      } finally {
        await _resumeCameraPipeline();
        if (mounted) {
          _setState(() => _isCapturing = false);
        }
      }
    } catch (e) {
      await _resumePreviewAfterCapture();
      if (mounted) {
        _setState(() {
          _hint = '$failTitle失败: $e';
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _visionGalleryPipeline({
    required Uint8List jpegBytes,
    required String failTitle,
    required String busyHint,
    required String resultPageTitle,
    required Future<String> Function(List<int> jpeg) task,
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      _setState(() => _hint = '$failTitle：未配置云端密钥');
      return;
    }
    if (!await NetworkReachability.instance.quickCheck()) {
      _setState(() => _hint = '$failTitle：请检查网络连接');
      return;
    }
    _setState(() => _hint = busyHint);
    try {
      final text = await task(jpegBytes);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LlmVisionTaskResultPage(
            title: resultPageTitle,
            bodyText: text,
          ),
        ),
      );
    } on OpenRouterVisionTasksException catch (e) {
      if (mounted) {
        _setState(() => _hint = e.message);
      }
    } catch (e) {
      if (mounted) {
        _setState(() => _hint = '$failTitle失败: $e');
      }
    }
  }

  Future<void> _processVisionTextFromGallery(Uint8List jpegBytes) async {
    await _visionGalleryPipeline(
      jpegBytes: jpegBytes,
      failTitle: '文字识别',
      busyHint: '正在识别文字...',
      resultPageTitle: '文字识别',
      task: OpenRouterVisionTasksClient.instance.ocrSubjectTextFromJpeg,
    );
  }

  Future<void> _processVisionTranslateFromGallery(Uint8List jpegBytes) async {
    await _visionGalleryPipeline(
      jpegBytes: jpegBytes,
      failTitle: '翻译',
      busyHint: '正在翻译...',
      resultPageTitle: '翻译',
      task: OpenRouterVisionTasksClient.instance.translateVisibleTextToZhFromJpeg,
    );
  }

  Future<void> _processVisionObjectFromGallery(Uint8List jpegBytes) async {
    await _visionGalleryPipeline(
      jpegBytes: jpegBytes,
      failTitle: '物体识别',
      busyHint: '正在识别物体...',
      resultPageTitle: '物体识别',
      task: OpenRouterVisionTasksClient.instance.describeMainSubjectZhFromJpeg,
    );
  }
}
