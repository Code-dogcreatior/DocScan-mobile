import 'package:flutter/material.dart';

/// 文字识别 / 翻译 / 物体识别等纯文本结果展示。
class LlmVisionTaskResultPage extends StatelessWidget {
  const LlmVisionTaskResultPage({
    super.key,
    required this.title,
    required this.bodyText,
  });

  final String title;
  final String bodyText;

  @override
  Widget build(BuildContext context) {
    final display = bodyText.trim().isEmpty ? '（无内容）' : bodyText.trim();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SelectableText(
            display,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
