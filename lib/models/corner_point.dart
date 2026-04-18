class CornerPoint {
  const CornerPoint(this.x, this.y);

  final double x;
  final double y;
}

class CornerDetectionResult {
  const CornerDetectionResult({
    required this.points,
    this.message,
    this.inferenceMs,
    this.imageWidth,
    this.imageHeight,
  });

  final List<CornerPoint> points;
  final String? message;
  final int? inferenceMs;

  /// Coordinate space of [points] (camera buffer or decoded image pixels).
  final double? imageWidth;
  final double? imageHeight;

  bool get hasFourCorners => points.length == 4;
}
