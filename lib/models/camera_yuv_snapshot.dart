import 'dart:typed_data';

import 'package:camera/camera.dart';

/// 单 plane 的深拷贝（与 [Plane] 字段一致）。
class CameraYuvPlaneSnapshot {
  const CameraYuvPlaneSnapshot({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// 同步拷贝 [CameraImage] 全部 plane，避免在异步推理期间占用 ImageReader 缓冲。
///
/// 须在预览回调内、任何 `await` 之前调用。
class CameraYuvSnapshot {
  const CameraYuvSnapshot({
    required this.width,
    required this.height,
    required this.planes,
  });

  final int width;
  final int height;
  final List<CameraYuvPlaneSnapshot> planes;

  factory CameraYuvSnapshot.from(CameraImage image) {
    return CameraYuvSnapshot(
      width: image.width,
      height: image.height,
      planes: [
        for (final p in image.planes)
          CameraYuvPlaneSnapshot(
            bytes: Uint8List.fromList(p.bytes),
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel ?? 1,
          ),
      ],
    );
  }
}
