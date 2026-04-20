part of 'camera_scan_page.dart';

extension _CameraModeActions on _CameraScanPageState {
  String _galleryActionLabel() {
    if (_mode.isScan) return '相册裁剪';
    if (_mode == CameraCaptureMode.aiCutout) return '相册抠图';
    if (_mode == CameraCaptureMode.eSignatureScan) return '相册签名';
    if (_mode == CameraCaptureMode.formulaRecognition) return '相册识别';
    if (_mode == CameraCaptureMode.textRecognition) return '相册文字';
    if (_mode == CameraCaptureMode.translate) return '相册翻译';
    if (_mode == CameraCaptureMode.objectRecognition) return '相册识物';
    if (_mode == CameraCaptureMode.idPhoto) return '相册证件照';
    if (_mode == CameraCaptureMode.aiErase) return '相册消除';
    return '查看说明';
  }

  bool _modeImplemented(CameraCaptureMode mode) {
    return mode.isScan ||
        mode == CameraCaptureMode.aiCutout ||
        mode == CameraCaptureMode.eSignatureScan ||
        mode == CameraCaptureMode.formulaRecognition ||
        mode == CameraCaptureMode.textRecognition ||
        mode == CameraCaptureMode.translate ||
        mode == CameraCaptureMode.objectRecognition ||
        mode == CameraCaptureMode.idPhoto ||
        mode == CameraCaptureMode.aiErase;
  }
}
