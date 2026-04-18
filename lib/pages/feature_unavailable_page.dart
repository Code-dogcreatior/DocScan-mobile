import 'package:flutter/material.dart';

import '../models/camera_capture_mode.dart';

class FeatureUnavailablePage extends StatelessWidget {
  const FeatureUnavailablePage({
    super.key,
    required this.mode,
  });

  final CameraCaptureMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.construction_rounded,
                size: 52,
                color: cs.primary,
              ),
              const SizedBox(height: 14),
              Text(
                '${mode.title} 即将上线',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '该能力暂未开放，当前版本可优先体验扫描、AI 抠图、电子签名和公式识别。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('返回相机'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
