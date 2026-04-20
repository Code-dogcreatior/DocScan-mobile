import '../config/app_env.dart';
import '../utils/latex_display_normalize.dart';
import 'llm_responses_client.dart';

/// OneRouter / OpenAI Responses 风格 API：视觉 LaTeX + 结构化解题说明。
class OpenRouterFormulaException implements Exception {
  OpenRouterFormulaException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 单步中引用的公理、定义、定理或运算法则（供界面展开查看）。
class FormulaStepAxiom {
  const FormulaStepAxiom({required this.nameZh, required this.detailZh});
  final String nameZh;
  final String detailZh;
}

class FormulaSolveStep {
  const FormulaSolveStep({
    required this.title,
    required this.latex,
    this.axioms = const [],
  });
  final String title;
  final String latex;
  final List<FormulaStepAxiom> axioms;
}

class FormulaSolveResult {
  const FormulaSolveResult({
    required this.solvable,
    required this.steps,
    required this.formulaExplanationLatex,
    required this.summaryZh,
  });

  final bool solvable;
  final List<FormulaSolveStep> steps;

  /// 仅放**可单独编译的 LaTeX**（短公式辑要）；勿写整句自然语言，避免被当成数学解析。
  final String formulaExplanationLatex;

  /// 简体中文小结/说明（可解为「小结」，不可解为全文说明）；普通文本，不用 LaTeX。
  final String summaryZh;
}

class OpenRouterFormulaClient {
  OpenRouterFormulaClient._();

  static final OpenRouterFormulaClient instance = OpenRouterFormulaClient._();

  final LlmResponsesClient _llm = LlmResponsesClient.instance;

  /// 从公式截图识别主表达式 LaTeX。
  Future<String> recognizeLatexFromJpeg(
    List<int> jpegBytes, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      throw OpenRouterFormulaException('未配置 OPENROUTER_API_KEY');
    }
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'latex': <String, dynamic>{
          'type': 'string',
          'description':
              r'One line only. MUST be \( ... \) wrapping exactly one inline expression, OR a single \[ ... \] block for display. '
              r'Forbidden: \begin{array}, align, matrix, multline, split. '
              r'Every \frac MUST be \frac{N}{D} with BOTH N and D in { }. Every \sqrt MUST be \sqrt{...}. '
              r'Balanced \left/\right and {}. No markdown, no prose.',
        },
      },
      'required': <String>['latex'],
    };

    final body = <String, dynamic>{
      'model': AppEnv.openRouterModel.trim(),
      'input': <Map<String, dynamic>>[
        _llm.userMessage(
          instructionText:
              'You are a LaTeX OCR engine. Read the math in the image; output JSON only.\n'
              r'FIXED FORMAT for field "latex": exactly one line. Prefer \( ... \) with the whole expression inside. '
              r'Do NOT use array/align/matrix. Every \frac must be \frac{A}{B} with braces around A and B (e.g. \frac{1}{2}, never \frac12). '
              r'\sqrt always \sqrt{x}. Match every \left with \right. No English words inside latex.',
          jpegBytes: jpegBytes,
        ),
      ],
      'reasoning': LlmResponsesClient.reasoningNone,
      'max_output_tokens': 4096,
      ..._llm.textFormatJsonSchema(name: 'latex_ocr', schema: schema),
    };

    final assistantText = await _llm.postResponsesAssistantText(
      body,
      timeout,
      errorFor: OpenRouterFormulaException.new,
    );
    final raw = LlmResponsesClient.decodeJsonObject(
      assistantText,
      errorFor: OpenRouterFormulaException.new,
    );
    final latex = raw['latex'];
    if (latex is! String) {
      throw OpenRouterFormulaException('响应缺少 latex 字段');
    }
    return LatexDisplayNormalize.forRecognizedOcr(latex);
  }

  /// 解题步骤或公式说明（结构化 JSON）。
  Future<FormulaSolveResult> solveOrExplain({
    List<int>? imageJpegBytes,
    required String latexHint,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (!AppEnv.hasOpenRouterKey) {
      throw OpenRouterFormulaException('未配置 OPENROUTER_API_KEY');
    }

    final axiomItem = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'name_zh': <String, dynamic>{
          'type': 'string',
          'description':
              '本步用到的公理、定义、定理或运算法则的简短中文名称（如「等价变形」「洛必达法则」）；勿写整句推导。',
        },
        'detail_zh': <String, dynamic>{
          'type': 'string',
          'description':
              '两三句以内中文：说明本步为何可用该依据、作用于式子哪一部分；禁止 LaTeX 与编号列表符号。',
        },
      },
      'required': <String>['name_zh', 'detail_zh'],
    };

    final stepItem = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'title': <String, dynamic>{
          'type': 'string',
          'description':
              '本步标题：必须使用简体中文短语（如「化为标准形」「求积分因子」），禁止使用纯英文标题。',
        },
        'latex': <String, dynamic>{
          'type': 'string',
          'description':
              r'本步仅写合法 LaTeX，单行；优先 \( ... \) 包住整段式子，或 \[ ... \]。禁止 array/align。'
              r'\frac 必须 \frac{A}{B} 且 A、B 均带花括号；\sqrt 必须带花括号。可为空。',
        },
        'axioms': <String, dynamic>{
          'type': 'array',
          'description':
              '本步明确用到的数学依据；与纯数值代入无独立名称时可为空数组，但尽量列出（如「乘法分配律」）。',
          'items': axiomItem,
        },
      },
      'required': <String>['title', 'latex', 'axioms'],
    };

    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, dynamic>{
        'solvable': <String, dynamic>{
          'type': 'boolean',
          'description':
              'True if the expression can be solved or simplified step-by-step.',
        },
        'steps': <String, dynamic>{
          'type': 'array',
          'items': stepItem,
        },
        'summary_zh': <String, dynamic>{
          'type': 'string',
          'description':
              '必须用简体中文写一段话：可解时为整题小结；不可解时说明「式子表示什么、为何不可解」。'
              '普通书面语，不要夹英文长句；不要在此字段写数学公式。',
        },
        'formula_explanation_latex': <String, dynamic>{
          'type': 'string',
          'description':
              r'可选：仅一行短 LaTeX，格式同 steps.latex（\( ... \) 或 \[ ... \]）；\frac/\sqrt 必须带花括号。不要写句子。无则空字符串。',
        },
      },
      'required': <String>[
        'solvable',
        'steps',
        'summary_zh',
        'formula_explanation_latex',
      ],
    };

    final hint = latexHint.trim().isEmpty ? '(empty)' : latexHint.trim();
    final instruction = '你是数学解题助手。用户给出的 LaTeX 可能来自 OCR，可能有瑕疵。\n'
        '$hint\n\n'
        '【语言】steps 每项的 title 必须用简体中文；summary_zh 必须用简体中文一段话。\n'
        '【依据】steps 每项必须含 axioms 数组：列出本步用到的公理/定义/定理/法则（name_zh 短语，'
        'detail_zh 两三句说明如何应用）；与纯变形无独立名称时可置空数组，但可解时尽量每步至少一条。\n'
        '【公式】steps[].latex 与 formula_explanation_latex：每字段单行；必须用 \\( ... \\) 或 \\[ ... \\]；'
        r'\frac 一律 \frac{A}{B}（禁止 \frac12 这种无花括号写法）；\sqrt{·}；禁止 array/align。不要写句子。'
        '否则渲染会错。\n'
        '【分支】能系统求解则 solvable=true 并填满 steps；否则 solvable=false、steps 置空、'
        '在 summary_zh 用中文说明公式含义，formula_explanation_latex 可留空。\n'
        '只输出符合 schema 的 JSON。';

    final body = <String, dynamic>{
      'model': AppEnv.openRouterModel.trim(),
      'input': <Map<String, dynamic>>[
        _llm.userMessage(
          instructionText: instruction,
          jpegBytes: imageJpegBytes,
        ),
      ],
      'reasoning': LlmResponsesClient.reasoningNone,
      'max_output_tokens': 8192,
      ..._llm.textFormatJsonSchema(name: 'formula_solve_or_explain', schema: schema),
    };

    final assistantText = await _llm.postResponsesAssistantText(
      body,
      timeout,
      errorFor: OpenRouterFormulaException.new,
    );
    final raw = LlmResponsesClient.decodeJsonObject(
      assistantText,
      errorFor: OpenRouterFormulaException.new,
    );
    final solvable = raw['solvable'] == true;
    final stepsRaw = raw['steps'];
    final steps = <FormulaSolveStep>[];
    if (stepsRaw is List) {
      for (final e in stepsRaw) {
        if (e is! Map) continue;
        final title = e['title']?.toString() ?? '';
        final lx = e['latex']?.toString() ?? '';
        final axioms = <FormulaStepAxiom>[];
        final axiomsRaw = e['axioms'];
        if (axiomsRaw is List) {
          for (final a in axiomsRaw) {
            if (a is! Map) continue;
            axioms.add(
              FormulaStepAxiom(
                nameZh: a['name_zh']?.toString().trim() ?? '',
                detailZh: a['detail_zh']?.toString().trim() ?? '',
              ),
            );
          }
        }
        steps.add(FormulaSolveStep(
          title: title,
          latex: LatexDisplayNormalize.forSolveSnippet(lx),
          axioms: axioms,
        ));
      }
    }
    final explain = raw['formula_explanation_latex']?.toString() ?? '';
    final summaryZh = raw['summary_zh']?.toString() ?? '';
    return FormulaSolveResult(
      solvable: solvable,
      steps: steps,
      formulaExplanationLatex: LatexDisplayNormalize.forSolveSnippet(explain),
      summaryZh: summaryZh.trim(),
    );
  }
}
