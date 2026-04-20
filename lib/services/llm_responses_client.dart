import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

typedef LlmErrorFactory = Exception Function(String message);

/// 共享的 OneRouter / OpenAI Responses（`POST …/responses`）客户端。
class LlmResponsesException implements Exception {
  LlmResponsesException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LlmResponsesClient {
  LlmResponsesClient._({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  static final LlmResponsesClient instance = LlmResponsesClient._();

  final http.Client _client;

  static const Map<String, String> reasoningNone = <String, String>{
    'effort': 'none',
  };

  /// 默认 `https://llm.onerouter.pro/v1` → POST …/responses
  Uri get responsesUri {
    final base = AppEnv.openRouterBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/responses')) {
      return Uri.parse(base);
    }
    return Uri.parse('$base/responses');
  }

  Map<String, String> get headers => <String, String>{
        'Authorization': 'Bearer ${AppEnv.openRouterApiKey.trim()}',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> textFormatJsonSchema({
    required String name,
    required Map<String, dynamic> schema,
  }) {
    return <String, dynamic>{
      'text': <String, dynamic>{
        'format': <String, dynamic>{
          'type': 'json_schema',
          'name': name,
          'strict': true,
          'schema': schema,
        },
      },
    };
  }

  List<Map<String, dynamic>> userContentParts({
    required String instructionText,
    List<int>? jpegBytes,
  }) {
    final parts = <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'input_text',
        'text': instructionText,
      },
    ];
    if (jpegBytes != null && jpegBytes.isNotEmpty) {
      final b64 = base64Encode(jpegBytes);
      parts.add(<String, dynamic>{
        'type': 'input_image',
        'image_url': 'data:image/jpeg;base64,$b64',
        'detail': 'high',
      });
    }
    return parts;
  }

  Map<String, dynamic> userMessage({
    required String instructionText,
    List<int>? jpegBytes,
  }) {
    return <String, dynamic>{
      'type': 'message',
      'role': 'user',
      'content': userContentParts(
        instructionText: instructionText,
        jpegBytes: jpegBytes,
      ),
    };
  }

  Future<String> postResponsesAssistantText(
    Map<String, dynamic> body,
    Duration timeout, {
    LlmErrorFactory errorFor = LlmResponsesException.new,
  }) async {
    final res = await _client
        .post(
          responsesUri,
          headers: headers,
          body: jsonEncodeBody(body, errorFor: errorFor),
        )
        .timeout(timeout);

    if (res.statusCode != 200) {
      throw errorFor(
        'LLM HTTP ${res.statusCode}: ${_truncate(res.body, 500)}',
      );
    }

    dynamic decodedRoot;
    try {
      decodedRoot = jsonDecode(res.body);
    } catch (e) {
      throw errorFor('响应 JSON 解析失败: $e');
    }
    if (decodedRoot is! Map<String, dynamic>) {
      throw errorFor('响应根节点不是 JSON 对象');
    }
    final decoded = decodedRoot;

    throwIfApiError(decoded, errorFor: errorFor);
    final text = extractAssistantOutputText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw errorFor('响应无 assistant 文本: ${_truncate(res.body, 600)}');
    }
    return text.trim();
  }

  static void throwIfApiError(
    Map<String, dynamic> root, {
    LlmErrorFactory errorFor = LlmResponsesException.new,
  }) {
    final err = root['error'];
    if (err is Map) {
      final msg = err['message']?.toString() ?? jsonEncode(err);
      throw errorFor(msg);
    }
  }

  /// Responses：`output[]` 中 `type: message`, `role: assistant` 的 `output_text`；
  /// 兼容 Chat Completions：`choices[0].message.content`。
  static String? extractAssistantOutputText(Map<String, dynamic> root) {
    final output = root['output'];
    if (output is List) {
      final buf = StringBuffer();
      for (final item in output) {
        if (item is! Map) continue;
        if (item['type'] != 'message') continue;
        if (item['role'] != 'assistant') continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final c in content) {
          if (c is! Map) continue;
          if (c['type'] == 'output_text') {
            buf.write(c['text']?.toString() ?? '');
          }
        }
      }
      final s = buf.toString().trim();
      if (s.isNotEmpty) return s;
    }

    final choices = root['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> decodeJsonObject(
    String assistantText, {
    LlmErrorFactory errorFor = LlmResponsesException.new,
  }) {
    var raw = assistantText.trim();
    if (raw.startsWith('```')) {
      raw = raw
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```\s*$'), '');
    }
    final inner = jsonDecode(raw);
    if (inner is! Map<String, dynamic>) {
      throw errorFor('模型输出不是 JSON 对象');
    }
    return inner;
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }

  static String jsonEncodeBody(
    Map<String, dynamic> body, {
    LlmErrorFactory errorFor = LlmResponsesException.new,
  }) {
    try {
      return jsonEncode(
        body,
        toEncodable: (Object? o) {
          if (o is StringBuffer) {
            return o.toString();
          }
          throw UnsupportedError(
            'JSON 无法编码类型 ${o.runtimeType}，请检查请求体是否仅含 Map/List/String/num/bool/null',
          );
        },
      );
    } catch (e) {
      throw errorFor('请求 JSON 序列化失败: $e');
    }
  }
}
