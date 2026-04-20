# DocScan Mobile

<p align="center">
  <strong>移动端智能文档扫描</strong><br/>
  端侧 ONNX 推理 · 透视矫正 · 可选远程抠图 · 公式识别（联网优先云端 / 离线 ONNX）
</p>

DocScan Mobile 是一款面向 **iOS / Android** 的 Flutter 应用，聚焦「相机即扫」体验：实时文档框、透视拉正、扫描风格增强，并集成 **AI 抠图**（可对接自建 HTTP 服务）与 **LaTeX 公式识别**（可选 [OpenRouter](https://openrouter.ai/) 视觉模型，离线回退 ONNX）。项目以 **可审计的开源实现** 与 **可替换的后端** 为设计目标，适合作为商业产品原型、二次开发底座或学习相机 + ONNX 流水线的参考实现。

> 愿景：在合规与隐私可控的前提下，持续对齐主流扫描类 App 的核心能力（清晰度、边缘稳定、导出与分享），**不**复制任何第三方品牌或闭源实现。

---

## 目录

- [为什么选择 DocScan](#为什么选择-docscan)
- [功能一览](#功能一览)
- [技术栈](#技术栈)
- [系统要求](#系统要求)
- [快速开始](#快速开始)（含 [Windows 脚本](#windows-脚本-pack_and_startcmd)）
- [抠图与公式环境配置](#抠图与公式环境配置)
- [模型与资源文件](#模型与资源文件)
- [工程结构](#工程结构)
- [产品规划](#产品规划)
- [文档与路线图](#文档与路线图)
- [贡献与安全](#贡献与安全)
- [许可证](#许可证)

---

## 为什么选择 DocScan

| 维度 | 说明 |
|------|------|
| **隐私友好** | 文档角点、透视裁剪可在 **设备端** 完成；若配置 `OPENROUTER_API_KEY` 且本机已连接网络，公式识别与「解题/说明」会请求 OpenRouter（图像与 LaTeX 会出境）；抠图仅在使用该功能时访问你配置的 `MATTING_API_BASE`。 |
| **可配置后端** | 抠图根地址通过编译期变量注入，**已跟踪源码中不包含默认第三方域名**，便于公开仓库托管与私有化部署。 |
| **可演进架构** | 拍摄模式以枚举驱动，扫描 / 抠图 / 签名 / 公式等分支清晰，便于按产品节奏扩展「多页」「PDF」「云同步」等能力。 |
| **工程化文档** | `docs/` 下提供模式路线图、性能与稳定性规划、优化报告等，降低接手与协作成本。 |

---

## 功能一览

以下为底部拍摄模式与核心能力（顺序与 [`CameraCaptureMode`](lib/models/camera_capture_mode.dart) 一致）。**对勾**表示当前版本已落地，**空方框**表示占位或暂未开放。

- [x] **扫描**：相机预览、`ImageStream` 上 ONNX 角点检测、文档框叠加、透视裁剪与 **风格页**（`StylePage`）。
- [x] **AI 抠图**：拍照或相册 JPEG → 远程蒙版接口 → 端上合成带 Alpha 的 PNG，可保存相册（`gal`）。
- [x] **扫描电子签名**：独立引导与快门流程，抠图链路复用，透明背景签名图。
- [ ] **证件照**：占位。
- [x] **公式识别**：联网且已配置 OpenRouter 时优先 **视觉 LaTeX**；否则端侧 ONNX + `tokenizer.json`；结果页支持 **智能解题 / 公式说明**（`json_schema` 结构化输出 + `flutter_math_fork` 渲染）。详见下文「统一环境变量」。
- [ ] **文字识别**：占位。
- [ ] **翻译**：占位。
- [ ] **物体识别**：占位。
- [ ] **AI 擦除**：占位。

对接细节见 [`docs/camera_modes_roadmap.md`](docs/camera_modes_roadmap.md)。

---

## 产品规划

面向「可商用的开源扫描体验」的后续方向（随版本迭代更新勾选状态）。

- [x] 端侧文档角点 + 透视扫描主流程
- [x] 可配置抠图与 OpenRouter（`env/app.env`：`MATTING_API_BASE`、`OPENROUTER_API_KEY` 等）
- [x] LaTeX 公式识别（云端优先 + ONNX 回退）与结果页解题/说明
- [ ] 多页扫描与列表管理
- [ ] 导出 PDF / 多格式分享
- [ ] 图像增强（去阴影、对比度曲线等）深化
- [ ] 云端同步（可选、需自备合规后端）
- [ ] 单元测试覆盖核心几何与 OCR 后处理

---

## 技术栈

- **框架**：Flutter（Material 3）、Dart `^3.8.1`
- **相机**：`camera`
- **图像**：`image`（编解码、缩放、alpha 合成）
- **推理**：`onnxruntime`（角点检测、公式 Encoder/Decoder 等）
- **网络**：`http`（抠图 multipart、兼容 OpenAI **Responses** `…/v1/responses` 的 LLM 网关）、`connectivity_plus`（本机网络链路）
- **相册**：`gal`、`image_picker`

---

## 系统要求

- 已安装 [Flutter](https://docs.flutter.dev/get-started/install)（建议稳定版，与 `pubspec.yaml` 中 SDK 约束一致）。
- **Android**：Android Studio、SDK 与 NDK 按 Flutter 默认工程配置即可（本仓库 `ndkVersion` 已在 Gradle 中声明）。
- **iOS**：Xcode、CocoaPods 环境按 Flutter 官方文档准备。

Windows 本机可使用 `D:\flutter\bin\flutter.bat` 调用 Flutter CLI。

---

## 快速开始

```bash
git clone <你的仓库地址>.git
cd <仓库根目录>
flutter pub get
```

**推荐**：复制 [`env/app.example.env`](env/app.example.env) 为 **`env/app.env`**（已在 `.gitignore`），填写抠图根地址与（可选）OpenRouter Key，然后：

```bash
flutter run --dart-define-from-file=env/app.env
```

**公式识别**：未配置 `OPENROUTER_API_KEY` 或设备未联网时，使用 `assets/models/latex/` 下 ONNX + `tokenizer.json`（本仓库已跟踪）。配置 Key 且本机已连接网络时，识别优先走 LLM 网关（默认模型 `google/gemini-3.1-flash-lite-preview`，可在 `env/app.env` 中改 `OPENROUTER_MODEL`）。

**单次传入**（不写文件时）：

```bash
flutter run --dart-define=MATTING_API_BASE=https://你的抠图根地址 --dart-define=OPENROUTER_API_KEY=你的密钥
```

Release 构建示例：

```bash
flutter build apk --dart-define-from-file=env/app.env
flutter build ios --dart-define-from-file=env/app.env
```

### Windows 脚本 pack_and_start.cmd

仓库根目录提供 [`pack_and_start.cmd`](pack_and_start.cmd)，在已存在 **`env/app.env`** 的前提下，自动带上 `--dart-define-from-file=env\app.env`（路径相对仓库根目录），并默认使用脚本内的 `D:\flutter\bin\flutter.bat`（可按需编辑脚本中的 `FLUTTER_BIN`）。

| 用法 | 说明 |
|------|------|
| `pack_and_start.cmd` | `flutter pub get` → 检测已连接 Android 设备 → `flutter run --no-pub -d <设备号> --dart-define-from-file=env\app.env`，额外参数会原样传给 `flutter run`（如脚本内已支持 `FLUTTER_VERBOSE=1` 等）。 |
| `pack_and_start.cmd build …` | `flutter build apk --no-pub --dart-define-from-file=env\app.env …`，首参 `build` 会被去掉，其余参数交给 `build apk`（例如 `pack_and_start.cmd build --release`）。 |
| `pack_and_start.cmd apk …` | 与 `build` 相同，仅别名。 |

若缺少 `env\app.env`，脚本会报错退出；请先从 [`env/app.example.env`](env/app.example.env) 复制并填写后再执行。

---

## 抠图与公式环境配置

原则：**勿将仅用于你方生产/内网的域名、IP、API Key 提交到 Git。** `env/app.env` 仅留在本机；若密钥曾出现在聊天、截图或 CI 日志中，请在 [OpenRouter](https://openrouter.ai/) 与抠图服务侧 **轮换凭据**。

### 推荐：统一环境文件 `env/app.env`

1. 复制示例（仓库跟踪 [`env/app.example.env`](env/app.example.env)，**不跟踪** `env/app.env`）：

   ```bash
   copy env\app.example.env env\app.env
   ```

   macOS / Linux：`cp env/app.example.env env/app.env`

2. 编辑 `env/app.env`：

   ```env
   MATTING_API_BASE=https://你的抠图服务根地址
   OPENROUTER_API_KEY=sk-or-v1-...
   OPENROUTER_BASE_URL=https://llm.onerouter.pro/v1
   OPENROUTER_MODEL=google/gemini-3.1-flash-lite-preview
   ```

   - `MATTING_API_BASE`：根地址 **不要** 尾随斜杠。抠图请求前会用 **`connectivity_plus` 判断设备是否已连接网络**（Wi‑Fi/蜂窝等），未连接则直接提示，不会对境外 URL 做 HTTP 探测。
   - `OPENROUTER_*`：可选。有 Key 且设备已联网时，公式与解题请求发往 **`OPENROUTER_BASE_URL` + `/responses`**（与 [OneRouter](https://llm.onerouter.pro/) 的 OpenAI Responses 风格一致：`input` 含 `input_text` / `input_image`，`reasoning.effort` 固定为 `none`，结构化输出通过 `text.format.type=json_schema`）；默认基址为 `https://llm.onerouter.pro/v1`。

3. 运行或打包：

   ```bash
   flutter run --dart-define-from-file=env/app.env
   ```

### HTTP 契约摘要

客户端会按 `MATTING_API_BASE` 拼接路径并 `POST` **multipart/form-data**：

| 场景 | 路径 | 表单字段 |
|------|------|----------|
| `general` / `high_precision` | `/process_high_precision` | `image`（JPEG）、`model_type` |
| `transparent_matting` | `/process_transparent_matting` | 同上 |

成功时响应 JSON 含 **`mask`**：PNG 的 Base64（无 `data:` 前缀）；灰度蒙版的 **R 通道** 用作前景 alpha。单测可对 `CreatinfMattingService.processCameraJpeg` 传入 `mattingApiBaseOverride` 指向本地 Mock。

若历史上曾误提交敏感 URL，除修改当前文件外，请评估 **轮换凭据** 或使用 `git filter-repo` 等工具清理历史（操作前务必备份）。

---

## 模型与资源文件

### 已随仓库声明的 ONNX（见 `pubspec.yaml`）

- `assets/models/fastvit_sa24_h_e_bifpn_256_fp32.onnx` — 角点相关流水线
- `assets/models/lcnet050_p_multi_decoder_l3_d64_256_fp32.onnx`

### 公式识别（云端优先 + LaTeX ONNX 回退）

- **联网 + 已配置 `OPENROUTER_API_KEY`**：[`LatexOcrService.recognizeJpeg`](lib/services/latex_ocr_service.dart) 先调用 [`OpenRouterFormulaClient`](lib/services/open_router_formula_client.dart) 视觉识别；失败或未联网时回退 ONNX。
- **离线 / 无 Key**：依赖 **`assets/models/latex/`** 下 `encoder.onnx`、`decoder.onnx`、`image_resizer.onnx` 与 `tokenizer.json`（本仓库已跟踪）。替换自训模型时请保持文件名与 `pubspec.yaml` 中 `assets` 声明一致。

结果页 **[`FormulaLatexResultPage`](lib/pages/formula_latex_result_page.dart)** 提供「智能解题 / 公式说明」：模型需返回 **`summary_zh`（简体中文小结/说明）** 与分步 **`steps[].title`（中文标题）+ `latex`（仅公式）**；可选 **`formula_explanation_latex`** 仅作短公式辑要，避免把英文句子当数学渲染。

---

## 工程结构

```
lib/
├── main.dart                 # 应用入口、主题
├── config/                   # 编译期环境变量封装（AppEnv）
├── models/                   # 拍摄模式、角点、相机帧等模型
├── pages/                    # 首页、相机页、风格页、公式与抠图结果页等
├── services/                 # ONNX 角点、透视裁剪、抠图 HTTP、LaTeX OCR、OpenRouter、风格处理
├── theme/                    # 设计 Token
└── widgets/                  # 模式条、文档叠加层、反馈组件等
env/                          # app.example.env（示例）；app.env 本地私密配置（gitignore）
docs/                         # 路线图、性能规划、优化报告等
flutter_reference/            # 可选：Python 脚本、重复模型等参考资源（无前端单页依赖）
```

---

## 文档与路线图

仓库内设计文档（阅读进度可自行在 fork 中勾选）。

- [x] [`docs/camera_modes_roadmap.md`](docs/camera_modes_roadmap.md) — 各拍摄模式状态与对接建议
- [x] [`docs/performance_stability_plan.md`](docs/performance_stability_plan.md) — 性能与稳定性规划
- [x] [`docs/optimization_report.md`](docs/optimization_report.md) — 优化项与优先级
- [x] [`docs/mode_integration_template.md`](docs/mode_integration_template.md) — 新模式接入模板思路

欢迎通过 **Issue** 讨论优先级，通过 **PR** 提交改进（建议先开小范围变更便于评审）。

---

## 贡献与安全

- **贡献**：欢迎修复 Bug、补充测试、改进文档与可访问性；较大功能建议先开 Issue 对齐需求与接口。
- **安全**：若发现敏感信息泄露或安全漏洞，请通过仓库 Security 策略或私信维护者 responsible disclosure（若已启用）。
- **隐私**：抠图会上传图像至你配置的 `MATTING_API_BASE`；启用 OpenRouter 时，公式识别与解题/说明会上传 **裁剪图与 LaTeX 文本** 至 OpenRouter 及其上游模型提供商。请在产品说明与隐私政策中向终端用户明示。

---

## 许可证

仓库根目录若尚未包含 `LICENSE` 文件，请在公开分发前 **自行补充** 许可证（例如 MIT、Apache-2.0 等）并更新本段说明。

---

<p align="center">
  若本项目对你有帮助，欢迎 Star 与分享。
</p>
