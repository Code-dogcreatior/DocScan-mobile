part of 'camera_scan_page.dart';

class CameraUiStateSnapshot {
  const CameraUiStateSnapshot({
    required this.mode,
    required this.hint,
    required this.isCapturing,
    required this.stableFrames,
  });

  final CameraCaptureMode mode;
  final String hint;
  final bool isCapturing;
  final int stableFrames;
}

extension _CameraUiStateX on _CameraScanPageState {
  CameraUiStateSnapshot get _uiStateSnapshot {
    return CameraUiStateSnapshot(
      mode: _mode,
      hint: _hint,
      isCapturing: _isCapturing,
      stableFrames: _stableFrames,
    );
  }
}
