/// 编译期环境变量（通过 `--dart-define` / `--dart-define-from-file=env/app.env` 注入）。
class AppEnv {
  AppEnv._();

  static const String mattingApiBase = String.fromEnvironment('MATTING_API_BASE');

  /// OpenRouter API Key（`sk-or-...` 或兼容前缀）；为空则公式仅走端侧 ONNX。
  static const String openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  /// 须指向 **Responses API** 根路径（脚本会 POST `{base}/responses`），默认 OneRouter。
  static const String openRouterBaseUrl = String.fromEnvironment(
    'OPENROUTER_BASE_URL',
    defaultValue: 'https://llm.onerouter.pro/v1',
  );

  /// 默认与 [env/app.example.env] 一致；可在 env 中覆盖。
  static const String openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'google/gemini-3.1-flash-lite-preview',
  );

  /// 为空则运行时回退 [openRouterModel]（与公式模型解耦，便于单独升级）。
  static const String openRouterModelTextOcr =
      String.fromEnvironment('OPENROUTER_MODEL_TEXT_OCR');

  static const String openRouterModelTranslate =
      String.fromEnvironment('OPENROUTER_MODEL_TRANSLATE');

  static const String openRouterModelObject =
      String.fromEnvironment('OPENROUTER_MODEL_OBJECT');

  static bool get hasOpenRouterKey => openRouterApiKey.trim().isNotEmpty;
}
