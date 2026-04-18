part of 'camera_scan_page.dart';

// ── Professional shutter button (like iOS Camera) ──

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.isProcessing,
    this.onTap,
  });

  final bool enabled;
  final bool isProcessing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: onTap,
        radius: 42,
        highlightShape: BoxShape.circle,
        containedInkWell: false,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: enabled
                        ? AppTokens.cameraForeground
                        : AppTokens.cameraForegroundDisabled,
                    width: 4,
                  ),
                ),
              ),
              if (isProcessing)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTokens.cameraForeground,
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: enabled ? 62 : 58,
                  height: enabled ? 62 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? AppTokens.cameraForeground
                        : Colors.white24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small action button below camera ──

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Opacity(
        opacity: visible ? 1.0 : 0.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: visible ? onTap : null,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTokens.cameraForeground.withValues(
                      alpha: onTap != null ? 0.15 : 0.06,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: onTap != null
                        ? AppTokens.cameraForeground
                        : AppTokens.cameraForegroundDisabled,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null
                    ? AppTokens.cameraForegroundMuted
                    : Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


/// 用 Ticker 在「推理目标角点」与「实际绘制」之间做指数插值，减轻 ~90ms 一帧的阶跃感。
class _SmoothDocumentOverlay extends StatefulWidget {
  const _SmoothDocumentOverlay({
    required this.targetPoints,
    required this.imageSize,
    required this.quarterTurns,
    required this.isMirrored,
    required this.flipY,
    required this.flipX,
  });

  final List<CornerPoint> targetPoints;
  final Size imageSize;
  final int quarterTurns;
  final bool isMirrored;
  final bool flipY;
  final bool flipX;

  @override
  State<_SmoothDocumentOverlay> createState() => _SmoothDocumentOverlayState();
}

class _SmoothDocumentOverlayState extends State<_SmoothDocumentOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  List<CornerPoint> _display = const [];

  /// 越大越跟手、越小越「飘」。
  static const double _followLambda = 24;

  /// 单点像素位移超过此值视为换文档/丢跟踪，直接对齐目标。
  static const double _snapPx = 120;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) return;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.08) {
      dt = 1 / 60;
    }

    final target = widget.targetPoints;
    if (target.length != 4) {
      if (_display.isNotEmpty) {
        setState(() => _display = const []);
      }
      return;
    }

    if (_display.length != 4) {
      setState(() => _display = List<CornerPoint>.from(target));
      return;
    }

    var snap = false;
    for (var i = 0; i < 4; i++) {
      final dx = (target[i].x - _display[i].x).abs();
      final dy = (target[i].y - _display[i].y).abs();
      if (dx > _snapPx || dy > _snapPx) {
        snap = true;
        break;
      }
    }
    if (snap) {
      setState(() => _display = List<CornerPoint>.from(target));
      return;
    }

    final t = 1.0 - math.exp(-_followLambda * dt);
    var changed = false;
    final next = List<CornerPoint>.generate(4, (i) {
      final nx = _display[i].x + (target[i].x - _display[i].x) * t;
      final ny = _display[i].y + (target[i].y - _display[i].y) * t;
      if ((nx - _display[i].x).abs() > 0.02 ||
          (ny - _display[i].y).abs() > 0.02) {
        changed = true;
      }
      return CornerPoint(nx, ny);
    });
    if (changed) {
      setState(() => _display = next);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DocumentOverlayPainter(
        points: _display,
        imageSize: widget.imageSize,
        quarterTurns: widget.quarterTurns,
        isMirrored: widget.isMirrored,
        flipY: widget.flipY,
        flipX: widget.flipX,
      ),
    );
  }
}
