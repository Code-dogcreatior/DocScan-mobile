part of 'camera_scan_page.dart';

extension _CameraModeActions on _CameraScanPageState {
  String _galleryActionLabel() {
    if (_mode.isScan) return '相册裁剪';
    if (_mode == CameraCaptureMode.aiCutout) return '相册抠图';
    if (_mode == CameraCaptureMode.eSignatureScan) return '相册签名';
    if (_mode == CameraCaptureMode.formulaRecognition) return '相册识别';
    return '查看说明';
  }

  bool _modeImplemented(CameraCaptureMode mode) {
    return mode.isScan ||
        mode == CameraCaptureMode.aiCutout ||
        mode == CameraCaptureMode.eSignatureScan ||
        mode == CameraCaptureMode.formulaRecognition;
  }
}
