# 相机拍摄模式路线图

本文档说明 [CameraCaptureMode](../lib/models/camera_capture_mode.dart) 各模式的定位、与「扫描」的差异，以及后续接入点。当前除 **扫描** 外均为占位：仅普通拍照并进入 [PlainCapturePreviewPage](../lib/pages/plain_capture_preview_page.dart) 预览。

## 模式列表（顺序固定）

| 顺序 | 枚举 `id` | 界面标题 | 当前状态 |
|------|-----------|----------|----------|
| 1 | `scan` | 扫描 | 已实现：实时角点、拍照透视裁剪、[StylePage](../lib/pages/style_page.dart) |
| 2 | `aiCutout` | AI 抠图 | 已接入：拍照 → [CreatinfMattingService](../lib/services/creatinf_matting_service.dart) → 结果页可保存至相册 [MattingResultPreviewPage](../lib/pages/matting_result_preview_page.dart) |
| 3 | `eSignatureScan` | 扫描电子签名 | 已接入：**独立**拍照流程 [`_captureSignatureMatting`](../lib/pages/camera_scan_page.dart)（不调用抠图轨 `_captureAndMatting`）；`takePicture` 前有白纸签名确认对话框；初版仍走同一抠图服务与 [MattingResultPreviewPage](../lib/pages/matting_result_preview_page.dart) |
| 4 | `idPhoto` | 证件照 | 占位 |
| 5 | `formulaRecognition` | 公式识别 | 已接入：拍照 → 端侧 [LatexOcrService](../lib/services/latex_ocr_service.dart)（ONNX + `tokenizer.json`）→ [FormulaLatexResultPage](../lib/pages/formula_latex_result_page.dart) 可复制 LaTeX；需自备 `encoder.onnx` / `decoder.onnx` / `image_resizer.onnx` 并写入 `pubspec.yaml` assets |
| 6 | `textRecognition` | 文字识别 | 占位 |
| 7 | `translate` | 翻译 | 占位 |
| 8 | `objectRecognition` | 物体识别 | 占位 |
| 9 | `aiErase` | AI 擦除 | 占位 |

## 与扫描模式的差异

- **扫描**：`CameraScanPage` 在 `_mode.isScan` 时开启 `ImageStream` 上的 ONNX 角点检测，叠加 `DocumentOverlayPainter`；快门走 `_captureAndProcess`（解码、全图/ROI 检测、透视裁剪）。
- **其余模式**：不跑角点推理、不绘文档框；快门多走 `_capturePlainPhoto`，其中 **AI 抠图**、**扫描电子签名**、**公式识别** 已各自分支到独立方法（抠图与签名 **两套实现并列**，互不调用对方拍照逻辑）。不进入 `StylePage`。

## AI 抠图（已实现）

- **端点**：相对 `MATTING_API_BASE` 的 `POST …/process_high_precision` 与 `POST …/process_transparent_matting`（由编译期或本地 env 注入根地址）。
- **请求**：`multipart/form-data`，字段 `image`（JPEG）、`model_type`（与 Vue 一致）。
- **响应**：JSON 字段 `mask` 为 PNG 的 base64；客户端将蒙版缩放到原图尺寸后写入 alpha（与 Vue `processImage` 一致）。
- **可选扩展**：在 `_captureAndMatting` 中把 `CreatinfMattingModel` 暴露为设置项（通用 / 高精度 / 透明抠图）。

## 后续开发对接建议

1. **统一入口**：在 [camera_scan_page.dart](../lib/pages/camera_scan_page.dart) 的 `_capturePlainPhoto` 成功取得 `Uint8List rawBytes` 后，按 `_mode` 分支（AI 抠图已单独走 `_captureAndMatting`）：
   - 可抽成 `Future<void> handleCapture(CameraCaptureMode mode, Uint8List jpeg)`（例如放在 `lib/services/`），内部再 `switch (mode)`。
2. **导航**：各模式可替换 `PlainCapturePreviewPage` 为独立结果页，或先进入统一「处理中」页再跳转结果。
3. **云端依赖**（按需标注）：翻译、部分 OCR/公式/物体识别可能依赖在线 API；扫描与证件照等可优先做端侧。
4. **改序或增删模式**：仅改枚举时需同步更新本表与 `CameraCaptureModeX.title`；顺序即 `CameraCaptureMode.values`，影响底部滑动条与 `PageController` 页码。

## 占位模式预期能力（产品备忘）

- **AI 抠图**：单张人像/主体分割，输出透明底或替换背景。
- **扫描电子签名**：签名区域增强、裁剪为透明/白底小图。
- **证件照**：人脸检测、抠图、标准尺寸与背景色。
- **公式识别**：印刷/手写公式 → LaTeX 或可编辑文本。
- **文字识别**：通用 OCR，输出结构化文本。
- **翻译**：OCR + 机器翻译，或整图说明性翻译（视产品定义）。
- **物体识别**：检测/分类或场景标签。
- **AI 擦除**：涂抹区域 inpainting 或移除物体。

具体是否上云、模型选型与 UI 流程以各子需求文档为准。
