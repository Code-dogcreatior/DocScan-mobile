import 'package:flutter/material.dart';

import '../models/camera_capture_mode.dart';
import '../theme/app_tokens.dart';

/// 底部横向滑动模式条，行为接近系统相机，带选中指示点。
class CameraModeStrip extends StatelessWidget {
  const CameraModeStrip({
    super.key,
    required this.pageController,
    required this.onPageChanged,
  });

  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  static const double _height = 54;

  @override
  Widget build(BuildContext context) {
    final modes = CameraCaptureModes.ordered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicator pill
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: AppTokens.cameraAccent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTokens.cameraAccent.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 0.4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _height,
          child: PageView.builder(
            controller: pageController,
            itemCount: modes.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final mode = modes[index];
              return AnimatedBuilder(
                animation: pageController,
                builder: (context, child) {
                  double delta = 0;
                  if (pageController.position.haveDimensions) {
                    final page =
                        pageController.page ?? pageController.initialPage.toDouble();
                    delta = (index - page).abs();
                  }
                  final t = (1.0 - (delta * 0.85).clamp(0.0, 1.0));
                  final fontSize = 13.0 + 3.0 * t;
                  final weight = t > 0.55 ? FontWeight.w700 : FontWeight.w400;
                  final opacity = 0.35 + 0.65 * t;
                  final color = t > 0.55
                      ? AppTokens.cameraAccent
                      : Colors.white;
                  return Center(
                    child: Text(
                      mode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color.withValues(alpha: opacity),
                        fontSize: fontSize,
                        fontWeight: weight,
                        letterSpacing: t > 0.55 ? 0.5 : 0,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
