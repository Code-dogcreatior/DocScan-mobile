# Camera Mode Integration Template

本模板用于新增拍摄模式，目标是避免继续加重 `camera_scan_page.dart` 耦合。

## 1. 模式声明
- 在 `lib/models/camera_capture_mode.dart` 添加新枚举值与 `title`。
- 若暂未实现，不进入“已实现模式集合”。

## 2. 处理器接入
- 在 `lib/pages/camera_scan_page_capture_orchestrator.dart` 的 `_captureModeHandlers()` 中注册：
  - `mode -> handler` 的映射
- 相册分支复用现有流程骨架：
  - 输入标准化 -> 处理 -> 结果页 -> 统一反馈

## 3. 可用性策略
- 未实现模式统一进入 `FeatureUnavailablePage`：
  - 文件：`lib/pages/feature_unavailable_page.dart`
- 避免在多个页面散落“功能开发中”文案。

## 4. UI 与反馈规范
- 颜色优先使用 `lib/theme/app_tokens.dart` 与 `ThemeData.colorScheme`。
- 成功/失败/提示统一使用 `showAppSnackBar()`：
  - 文件：`lib/widgets/app_feedback.dart`

## 5. 回归检查
- 进入模式后拍照/相册路径都可达。
- 切后台恢复后相机可继续使用。
- 无新增硬编码主题色（必要时补 token）。
