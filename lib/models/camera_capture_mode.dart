/// 相机底部拍摄模式（声明顺序即 [ordered] 顺序，与产品/文档一致）。
enum CameraCaptureMode {
  scan,
  aiCutout,
  eSignatureScan,
  idPhoto,
  formulaRecognition,
  textRecognition,
  translate,
  objectRecognition,
  aiErase,
}

extension CameraCaptureModeX on CameraCaptureMode {
  /// 界面展示用短标题。
  String get title => switch (this) {
        CameraCaptureMode.scan => '扫描',
        CameraCaptureMode.aiCutout => 'AI 抠图',
        CameraCaptureMode.eSignatureScan => '扫描电子签名',
        CameraCaptureMode.idPhoto => '证件照',
        CameraCaptureMode.formulaRecognition => '公式识别',
        CameraCaptureMode.textRecognition => '文字识别',
        CameraCaptureMode.translate => '翻译',
        CameraCaptureMode.objectRecognition => '物体识别',
        CameraCaptureMode.aiErase => 'AI 擦除',
      };

  /// 日志、路由参数等用稳定 id。
  String get id => name;

  bool get isScan => this == CameraCaptureMode.scan;
}

/// 有序列表（与 [CameraCaptureMode] 枚举顺序一致）。
abstract final class CameraCaptureModes {
  CameraCaptureModes._();

  static const List<CameraCaptureMode> ordered = CameraCaptureMode.values;
}
