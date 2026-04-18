# DocScan Mobile

<p align="center">
  <strong>移动端智能文档扫描</strong><br/>
  端侧 ONNX 推理 · 透视矫正 · 可选远程抠图 · 本地公式识别
</p>

DocScan Mobile 是一款面向 **iOS / Android** 的 Flutter 应用，聚焦「相机即扫」体验：实时文档框、透视拉正、扫描风格增强，并集成 **AI 抠图**（可对接自建 HTTP 服务）与 **端侧 LaTeX 公式识别**。项目以 **可审计的开源实现** 与 **可替换的后端** 为设计目标，适合作为商业产品原型、二次开发底座或学习相机 + ONNX 流水线的参考实现。

> 愿景：在合规与隐私可控的前提下，持续对齐主流扫描类 App 的核心能力（清晰度、边缘稳定、导出与分享），**不**复制任何第三方品牌或闭源实现。

---

## 目录

- [为什么选择 DocScan](#为什么选择-docscan)
- [功能一览](#功能一览)
- [技术栈](#技术栈)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [抠图服务配置](#抠图服务配置)
- [模型与资源文件](#模型与资源文件)
- [工程结构](#工程结构)
- [文档与路线图](#文档与路线图)
- [贡献与安全](#贡献与安全)
- [许可证](#许可证)

---

## 为什么选择 DocScan

| 维度 | 说明 |
|------|------|
| **隐私友好** | 文档角点、透视裁剪、公式识别等关键路径可在 **设备端** 完成；抠图仅在使用该功能时访问你配置的 `MATTING_API_BASE`。 |
| **可配置后端** | 抠图根地址通过编译期变量注入，**已跟踪源码中不包含默认第三方域名**，便于公开仓库托管与私有化部署。 |
| **可演进架构** | 拍摄模式以枚举驱动，扫描 / 抠图 / 签名 / 公式等分支清晰，便于按产品节奏扩展「多页」「PDF」「云同步」等能力。 |
| **工程化文档** | `docs/` 下提供模式路线图、性能与稳定性规划、优化报告等，降低接手与协作成本。 |

---

## 功能一览

### 已实现

- **文档扫描**：相机预览、`ImageStream` 上的 ONNX 角点检测、叠加文档框、快门后透视裁剪与 **风格页**（`StylePage`）。
- **AI 抠图**：拍照或相册 JPEG → 远程蒙版接口 → 端上合成 **带 Alpha 的 PNG**，结果页支持保存到相册（`gal`）。
- **扫描电子签名**：独立拍照引导（白纸签名），抠图链路复用，输出透明背景签名图。
- **公式识别**：端侧 **ONNX** 推理 + BPE `tokenizer.json`，输出 LaTeX 并可借助 `flutter_math_fork` 预览（需自备模型权重，见下文）。

### 规划中 / 占位

底部模式条中的 **证件照、文字识别、翻译、物体识别、AI 擦除** 等当前为占位或「功能暂未开放」页，可在 [`CameraCaptureMode`](lib/models/camera_capture_mode.dart) 与 [`docs/camera_modes_roadmap.md`](docs/camera_modes_roadmap.md) 中查看对接建议。

---

## 技术栈

- **框架**：Flutter（Material 3）、Dart `^3.8.1`
- **相机**：`camera`
- **图像**：`image`（编解码、缩放、alpha 合成）
- **推理**：`onnxruntime`（角点检测、公式 Encoder/Decoder 等）
- **网络**：`http`（抠图 multipart）
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

**抠图 / 签名抠图** 需要配置 `MATTING_API_BASE`（见下一节）。**公式识别** 依赖 `assets/models/latex/` 下 ONNX 与 `tokenizer.json`（本仓库已跟踪；若你 fork 后希望减小体积可自行改用 Git LFS 或按需下载，并保证与 `pubspec.yaml` 声明一致）。

```bash
# 已创建 matting_local.env 时（推荐）
flutter run --dart-define-from-file=matting_local.env

# 或单次传入
flutter run --dart-define=MATTING_API_BASE=https://你的服务根地址
```

Release 构建示例：

```bash
flutter build apk --dart-define-from-file=matting_local.env
flutter build ios --dart-define-from-file=matting_local.env
```

---

## 抠图服务配置

原则：**勿将仅用于你方生产/内网的域名、IP、Token 提交到 Git。**

### 推荐：本地环境文件

1. 复制示例文件（仓库内仅跟踪示例，**真实配置不跟踪**）：

   ```bash
   copy matting_local.example.env matting_local.env
   ```

   macOS / Linux：`cp matting_local.example.env matting_local.env`

2. 编辑 `matting_local.env`（该文件名已列入 `.gitignore`）：

   ```env
   MATTING_API_BASE=https://你的服务根地址
   ```

   根地址 **不要** 尾随斜杠。

3. 运行或打包时使用：

   ```bash
   flutter run --dart-define-from-file=matting_local.env
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

### 公式识别（LaTeX ONNX）

默认路径 **`assets/models/latex/`**，需包含：

- `encoder.onnx`、`decoder.onnx`、`image_resizer.onnx`
- `tokenizer.json`

本仓库已包含上述文件以便开箱运行；替换为自训模型时，请保持文件名与 `pubspec.yaml` 中 `assets` 声明一致，并阅读 [`lib/services/latex_ocr_service.dart`](lib/services/latex_ocr_service.dart) 中的加载与形状约定。

---

## 工程结构

```
lib/
├── main.dart                 # 应用入口、主题
├── models/                   # 拍摄模式、角点、相机帧等模型
├── pages/                    # 首页、相机页、风格页、公式与抠图结果页等
├── services/                 # ONNX 角点、透视裁剪、抠图 HTTP、LaTeX OCR、风格处理
├── theme/                    # 设计 Token
└── widgets/                  # 模式条、文档叠加层、反馈组件等
docs/                         # 路线图、性能规划、优化报告等
flutter_reference/            # 可选参考资源（按需使用，注意其中可能含独立前端工程）
```

---

## 文档与路线图

| 文档 | 内容 |
|------|------|
| [`docs/camera_modes_roadmap.md`](docs/camera_modes_roadmap.md) | 各拍摄模式状态与对接建议 |
| [`docs/performance_stability_plan.md`](docs/performance_stability_plan.md) | 性能与稳定性规划 |
| [`docs/optimization_report.md`](docs/optimization_report.md) | 优化项与优先级 |
| [`docs/mode_integration_template.md`](docs/mode_integration_template.md) | 新模式接入模板思路 |

欢迎通过 **Issue** 讨论优先级，通过 **PR** 提交改进（建议先开小范围变更便于评审）。

---

## 贡献与安全

- **贡献**：欢迎修复 Bug、补充测试、改进文档与可访问性；较大功能建议先开 Issue 对齐需求与接口。
- **安全**：若发现敏感信息泄露或安全漏洞，请通过仓库 Security 策略或私信维护者 responsible disclosure（若已启用）。
- **隐私**：抠图会上传用户选择的图像至你配置的 `MATTING_API_BASE`，请在产品说明与隐私政策中向终端用户明示。

---

## 许可证

仓库根目录若尚未包含 `LICENSE` 文件，请在公开分发前 **自行补充** 许可证（例如 MIT、Apache-2.0 等）并更新本段说明。

---

<p align="center">
  若本项目对你有帮助，欢迎 Star 与分享。
</p>
