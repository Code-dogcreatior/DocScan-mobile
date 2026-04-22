part of 'camera_scan_page.dart';

class _DecodeTaskArgs {
  const _DecodeTaskArgs(this.bytes);
  final Uint8List bytes;
}

class _DecodeTaskResult {
  const _DecodeTaskResult(this.baked);
  final img.Image baked;
}

Future<_DecodeTaskResult?> _decodeAndBakeTask(_DecodeTaskArgs args) async {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;
  final baked = img.bakeOrientation(decoded);
  return _DecodeTaskResult(baked);
}

Future<Uint8List> _encodeJpegTask(img.Image image) async {
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

class _CropTaskArgs {
  const _CropTaskArgs(this.baked, this.points);
  final img.Image baked;
  final List<CornerPoint> points;
}

Future<Uint8List?> _cropTask(_CropTaskArgs args) async {
  final cropper = PerspectiveCropper();
  return await cropper.cropDecoded(args.baked, args.points);
}
