# DocScan-mobile 优化报告

> 生成时间：2026-04-16

## 已完成的优化

### 1. `pubspec.yaml` 清理
- 移除了 80+ 行模板注释，保留有意义的 `dependency_overrides` 说明
- 更新 `description` 为有意义的项目描述

### 2. `camera_scan_page.dart` 代码质量改善
- 提取 `_captureButtonLabel()` 方法，消除 build 方法中 5 层嵌套三元表达式，可读性大幅提升

---

## 仍建议优化的事项（按优先级）

### P0 — 安全 & 基础质量

| 事项 | 说明 | 工作量 |
|------|------|--------|
| **单元测试** | `test/` 下仅有空壳模板。建议至少覆盖：`PerspectiveCropper._computeHomography`、`LatexOutputSanitizer.stripModelArtifacts`、`ScanStyleProcessor._percentileFast`、`CornerPoint` 排序逻辑 | 中 |
| **API URL 外置** | 抠图与 OpenRouter 等应通过 `env/app.env`（`--dart-define-from-file`）或 `--dart-define` 注入，避免写进已跟踪源码 | 小 |

### P1 — 架构 & 可维护性

| 事项 | 说明 | 工作量 |
|------|------|--------|
| **CameraScanPage 进一步拆分** | 即使提取了标签方法，该文件仍有 ~1390 行。`_captureAndMatting` / `_captureSignatureMatting` / `_capturePlainPhoto` 有大量重复的「停流→拍照→读字节→删临时文件→检查空」模式，可抽取为 `Future<Uint8List?> _takePhoto({String hint})` 辅助方法 | 中 |
| **状态管理** | 全部基于 `setState`。随功能增长建议引入 `Riverpod` 或 `Bloc`，将相机控制、角点检测状态、各模式业务逻辑解耦 | 大 |
| **权限处理** | 未使用 `permission_handler`，首次拒绝相机权限后无引导提示。建议处理 `denied` / `permanentlyDenied` 并引导至设置页 | 小 |
| **`_previewQuarterTurns` 与 `_deviceTurns` 重复** | 两个方法实现完全相同，应合并 | 小 |

### P2 — 功能完善

| 事项 | 说明 | 工作量 |
|------|------|--------|
| **扫描历史 & 持久化** | 当前无本地存储，关闭页面即丢失。可用 `sqflite` / `isar` 保存扫描记录 | 中 |
| **批量扫描 & PDF 导出** | `docs/camera_modes_roadmap.md` 中规划但未实现 | 大 |
| **应用图标** | 仍使用 Flutter 默认图标，建议用 `flutter_launcher_icons` 生成 | 小 |
| **国际化** | UI 文字全部中文硬编码，如需多语言支持需引入 `flutter_localizations` | 中 |

### P3 — 性能

| 事项 | 说明 |
|------|------|
| **ONNX 模型懒加载** | 当前 `_setup()` 同时加载 FastViT + LCNet。LaTeX OCR 三个模型虽然是懒加载的（`ensureInitialized`），但角点检测模型可考虑在非扫描模式下延迟加载 |
| **`ScanStyleProcessor._dilateGray` 性能** | 朴素 O(w·h·k²) 膨胀，k=15+ 时较慢。可用可分离最大值滤波或 van Herk/Gil-Werman 算法优化为 O(w·h) |
| **Isolate 复用** | `compute()` 每次创建销毁 Isolate，频繁调用有开销。可用 `IsolatePool` 或 `dart:isolate` 长驻 worker |

---

## 代码亮点（做得好的地方）

1. **YUV 预处理缓存** (`_CameraPreprocessCache`) — 避免每帧重复计算坐标映射表，性能优化到位
2. **EMA 平滑 + Ticker 插值双层抗抖** — 角点叠加层流畅度很好
3. **ROI 提示机制** — 预览角点反馈给拍照后的 FastViT 推理，缩小搜索区域
4. **LaTeX OCR 模型加载容错** — 支持 assets 和本地文件系统两种路径，并给出详细的帮助信息
5. **`ScanStyleProcessor`** — 完整移植了 Python 版自适应扫描算法，包含高精度浮点处理和直方图优化
