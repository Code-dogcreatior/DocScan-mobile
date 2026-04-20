import '../config/app_env.dart';
import 'llm_responses_client.dart';

/// 文字识别 / 翻译 / 物体识别等视觉任务（独立模型环境变量，与公式 [AppEnv.openRouterModel] 解耦）。
class OpenRouterVisionTasksException implements Exception {
  OpenRouterVisionTasksException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OpenRouterVisionTasksClient {
  OpenRouterVisionTasksClient._();

  static final OpenRouterVisionTasksClient instance =
      OpenRouterVisionTasksClient._();

  final LlmResponsesClient _llm = LlmResponsesClient.instance;

  static String _resolvedModel(String specific) {
    final t = specific.trim();
    return t.isEmpty ? AppEnv.openRouterModel.trim() : t;
  }

  /// 仅画面主体可读文字，按阅读顺序；无说明、无 markdown。
  Future<String> ocrSubjectTextFromJpeg(
    List<int> jpegBytes, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      throw OpenRouterVisionTasksException('未配置 OPENROUTER_API_KEY');
    }
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'text': <String, dynamic>{
          'type': 'string',
          'description':
              '仅输出画面中主要文字（标题、正文、标签等），按阅读顺序拼接成纯文本；'
              '无文字则为空字符串。禁止解释、前缀、markdown、除本字段外的任何内容。',
        },
      },
      'required': <String>['text'],
    };

    final body = <String, dynamic>{
      'model': _resolvedModel(AppEnv.openRouterModelTextOcr),
      'input': <Map<String, dynamic>>[
        _llm.userMessage(
          instructionText:
              '你是 OCR。只根据图像输出符合 JSON schema 的一条记录；字段 text 为图中主体可见文字，'
              '按人类阅读顺序合并为一段纯文本。不要输出 JSON 以外的字符。',
          jpegBytes: jpegBytes,
        ),
      ],
      'reasoning': LlmResponsesClient.reasoningNone,
      'max_output_tokens': 4096,
      ..._llm.textFormatJsonSchema(name: 'vision_text_ocr', schema: schema),
    };

    final assistantText = await _llm.postResponsesAssistantText(
      body,
      timeout,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final raw = LlmResponsesClient.decodeJsonObject(
      assistantText,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final text = raw['text'];
    if (text is! String) {
      throw OpenRouterVisionTasksException('响应缺少 text 字段');
    }
    return text.trim();
  }

  /// 图中可见文字译为流畅简体中文，仅译文。
  Future<String> translateVisibleTextToZhFromJpeg(
    List<int> jpegBytes, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      throw OpenRouterVisionTasksException('未配置 OPENROUTER_API_KEY');
    }
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'translation_zh': <String, dynamic>{
          'type': 'string',
          'description':
              '将图中全部可见文字译为流畅简体中文的一段译文；原文已是中文可略作润色复述；'
              '禁止注释、标题、引号包裹整段、markdown。',
        },
      },
      'required': <String>['translation_zh'],
    };

    final body = <String, dynamic>{
      'model': _resolvedModel(AppEnv.openRouterModelTranslate),
      'input': <Map<String, dynamic>>[
        _llm.userMessage(
          instructionText:
              '你是翻译。读取图中文字，输出符合 schema 的 JSON；translation_zh 为简体中文译文一段。'
              '不要输出 JSON 以外的字符。',
          jpegBytes: jpegBytes,
        ),
      ],
      'reasoning': LlmResponsesClient.reasoningNone,
      'max_output_tokens': 4096,
      ..._llm.textFormatJsonSchema(name: 'vision_translate_zh', schema: schema),
    };

    final assistantText = await _llm.postResponsesAssistantText(
      body,
      timeout,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final raw = LlmResponsesClient.decodeJsonObject(
      assistantText,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final t = raw['translation_zh'];
    if (t is! String) {
      throw OpenRouterVisionTasksException('响应缺少 translation_zh 字段');
    }
    return t.trim();
  }

  /// 画面主体中文名称 + 一句补充说明。
  Future<String> describeMainSubjectZhFromJpeg(
    List<int> jpegBytes, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      throw OpenRouterVisionTasksException('未配置 OPENROUTER_API_KEY');
    }
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'name_zh': <String, dynamic>{
          'type': 'string',
          'description': '画面主体物体或场景的中文名称，短语即可。',
        },
        'brief_zh': <String, dynamic>{
          'type': 'string',
          'description': '一句中文补充说明；无则空字符串。',
        },
      },
      'required': <String>['name_zh', 'brief_zh'],
    };

    final body = <String, dynamic>{
      'model': _resolvedModel(AppEnv.openRouterModelObject),
      'input': <Map<String, dynamic>>[
        _llm.userMessage(
          instructionText:
              '你是物体/场景识别。输出符合 schema 的 JSON：name_zh 为画面最突出的主体中文名；'
              'brief_zh 为一句中文简述。不要输出 JSON 以外的字符。',
          jpegBytes: jpegBytes,
        ),
      ],
      'reasoning': LlmResponsesClient.reasoningNone,
      'max_output_tokens': 2048,
      ..._llm.textFormatJsonSchema(name: 'vision_object_zh', schema: schema),
    };

    final assistantText = await _llm.postResponsesAssistantText(
      body,
      timeout,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final raw = LlmResponsesClient.decodeJsonObject(
      assistantText,
      errorFor: OpenRouterVisionTasksException.new,
    );
    final name = raw['name_zh'];
    final brief = raw['brief_zh'];
    if (name is! String) {
      throw OpenRouterVisionTasksException('响应缺少 name_zh 字段');
    }
    final b = brief is String ? brief.trim() : '';
    final n = name.trim();
    if (b.isEmpty) return n;
    return '$n\n$b';
  }
}
