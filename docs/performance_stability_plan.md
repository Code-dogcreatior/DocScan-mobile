# DocScan-mobile 性能分析、优化与稳定性方案（Plan）

> 适用范围：Flutter（Android/iOS/桌面/Web 视具体能力），以移动端为主。
> 
> 目标：在「相机预览 + 角点检测 + 扫描风格处理 + 抠图 + LaTeX OCR」等重链路下，**可量化地提升性能**并**显著降低崩溃/卡死/掉帧/异常率**，形成可持续的性能治理闭环。

---

## 0. 结论先行：优先级路线图

### P0（1~3 天即可起量化收益）
1. **建立基线与回归机制**：统一采样脚本/样本集/机型、关键链路埋点与导出（否则无法证明优化有效）。
2. **相机预览链路的流控与取消**：确保非扫描模式不跑推理；扫描模式中严格“只允许一个帧在推理中”；切后台/切相册/切模式稳定回收与恢复。
3. **热点算法替换**：`ScanStyleProcessor._dilateGray()` 从 O(w·h·k²) 优化为 O(w·h)（van Herk/Gil-Werman 或分离最大滤波）——这通常是“肉眼可见”的耗时下降点。

### P1（1~2 周，持续抬升体验上限）
1. **Isolate 复用**：将频繁 `compute()` 的任务改为常驻 worker（任务队列 + 复用内存），降低抖动与 GC 压力。
2. **ONNX 推理策略优化**：模型懒加载/分模式加载、推理输入策略（ROI/分辨率/跳帧）、异常 fallback（LCNet→FastViT 或反向）。
3. **拍照到结果的端到端优化**：解码/旋转/裁剪/风格化/编码减少中间拷贝与重复 decode/encode。

### P2（长期治理）
1. **稳定性治理体系**：崩溃监控、卡死/ANR 监控、弱网/离线降级、低内存兜底。
2. **性能预算与门禁**：每次 PR 自动跑基线对比，出现回退自动报警。

---

## 1. 范围与关键链路（基于当前代码现状）

### 1.1 核心链路图（建议作为治理入口）
1. **预览扫描**
   - `CameraController.startImageStream` → `_onImage` → `CameraYuvSnapshot.from` → `OnnxCornerDetector.detectFromYuvSnapshot`（LCNet/fastvit）
   - 输出：角点 `List<CornerPoint>` + overlay 绘制（`_SmoothDocumentOverlay` / `DocumentOverlayPainter`）
2. **拍照扫描**
   - `takePicture` → bytes → `compute(_decodeAndBakeTask)` → `OnnxCornerDetector.detectFromImage` → `compute(_cropTask)` → style（`ScanStyleProcessor.applySmartStyle` 等）→ encode/export
3. **网络抠图**
   - `CreatinfMattingService.processCameraJpeg`：resize/encode jpg → multipart upload → decode mask → resize mask → 合成 PNG
4. **LaTeX OCR（端侧 ONNX）**
   - `LatexOcrService.ensureInitialized` → load 3 ONNX + tokenizer → preprocess → encoder/decoder autoregressive

### 1.2 已观察到的“高风险性能点”
1. **像素级双层循环**（极易成为 CPU/耗时瓶颈）：`ScanStyleProcessor._dilateGray/_gaussianBlur/_buildProtectMask` 等。
2. **频繁创建 Isolate**：多处 `compute()`（相册、拍照、裁剪、二值化等）会造成抖动和额外开销。
3. **预览流推理的背压**：若推理耗时 > 帧间隔，必须丢帧，否则容易造成 ImageReader 缓冲耗尽、预览卡死。
4. **推理/图像处理与 UI 线程争用**：Dart 侧 heavy loop + UI raster/build 易互相影响。
5. **网络请求波动**：抠图接口受网络、服务端影响，需要超时、重试策略与降级。

---

## 2. 目标与指标体系（必须可验收）

> 原则：指标要“能采集、能对比、能回归”。

### 2.1 体验指标（用户可感知）
| 场景 | 指标 | 目标建议（中端机） | 目标建议（低端机） |
|---|---:|---:|---:|
| 扫描预览 | 预览 UI FPS（Raster/Build） | ≥ 55 | ≥ 45 |
| 扫描预览 | 角点更新频率（有效推理 FPS） | ≥ 10 | ≥ 6 |
| 拍照扫描 | Shutter → 结果页可交互（P50/P95） | P50 ≤ 1.2s / P95 ≤ 2.0s | P50 ≤ 2.0s / P95 ≤ 3.5s |
| 风格处理 | Smart HD 耗时（P50/P95） | P50 ≤ 250ms / P95 ≤ 450ms | P50 ≤ 500ms / P95 ≤ 900ms |
| 抠图（网络） | 点击 → 出结果（不含用户等待网络的主观差） | P50 ≤ 4s / P95 ≤ 10s | 同左 |
| LaTeX OCR | 单张识别耗时（P50/P95） | P50 ≤ 1.5s / P95 ≤ 3.0s | P50 ≤ 3.0s / P95 ≤ 6.0s |

### 2.2 资源指标（系统可感知）
| 指标 | 目标 |
|---|---|
| 内存峰值（扫描链路） | 中端机峰值 < 450MB；低端机 < 300MB（视模型大小调整） |
| 持续预览 10 分钟温升/降频 | 不出现持续掉帧、推理 FPS 不持续下滑 |
| 电量（可选） | 30 分钟扫描预览耗电可接受，持续 CPU > 70% 需强制降级策略 |

### 2.3 稳定性指标（必须长期追踪）
| 指标 | 定义 | 目标 |
|---|---|---|
| Crash-free sessions | 无崩溃会话占比 | ≥ 99.7% |
| 卡死/ANR（Android） | 主线程阻塞/无响应 | 持续下降，版本门禁 |
| OOM 率 | 低内存/大图处理导致 | 0 或极低 |
| 网络失败率 | 抠图接口非 200、超时 | 有重试与降级，用户可恢复 |

---

## 3. 性能诊断与基线（Benchmark）方案

### 3.1 运行模式要求
1. **Profile 构建**：性能评估一律在 `flutter run --profile` / release-like 环境。
2. **Debug 仅用于功能联调**：Debug 的 JIT/断言/日志会显著扭曲数据。

### 3.2 数据采集分层
**A. Flutter / Dart 侧（最先落地）**
- 关键链路分段 Stopwatch：
  - 预览：snapshot copy、preprocess、tensor 构建、ORT、postprocess、overlay 计算。
  - 拍照：拍照、解码+旋转、推理、透视裁剪、风格化、编码、落盘/分享。
- 帧时间：`SchedulerBinding.instance.addTimingsCallback` 采集 build/raster 时间分布。
- 内存：定期读取 `ProcessInfo`（平台受限）或用 DevTools/系统工具取样。

**B. 平台侧（用于定位系统级问题）**
- Android：Perfetto / systrace 观测相机、线程、调度、频率、GPU。
- iOS：Instruments（Time Profiler / Allocations / Energy Log）。

### 3.3 基线测试用例（建议固定样本集）
1. **扫描预览 2 分钟**：不断移动纸张、不同光照、旋转，观察推理 FPS 与 UI FPS。
2. **连续拍照 20 次**：拍照→返回→拍照，统计端到端耗时 P50/P95，观察内存是否爬升。
3. **Smart HD 风格处理 20 次**：同一图片重复处理，检查耗时与输出稳定性。
4. **弱网/断网抠图**：2G/丢包/超时，验证超时提示、重试与降级。
5. **LaTeX OCR**：不同复杂度图片（短式/长式/噪声），统计耗时与失败率。
6. **压力场景**：10 分钟持续预览 + 偶尔拍照 + 切后台恢复。

### 3.4 回归与门禁（建议）
- 每次版本迭代输出：
  - 指标表（P50/P95、内存峰值、掉帧率、崩溃率）
  - 与上版本 diff
- 建议做“性能回归门禁”：关键指标退化超过阈值（例如 +10%）即阻止发布。

---

## 4. 分模块优化方案（可执行清单）

### 4.1 相机预览链路（CameraScanPage）
**目标**：不卡死、不积压、切换稳定、可控地“丢帧保流畅”。

建议措施：
1. **强背压策略**（P0）
   - 保证 `_isProcessingFrame` 为“硬锁”：只允许一个 in-flight 推理。
   - 允许“跳帧”而不是排队：当上一次未完成，直接丢弃当前帧。
2. **取消与 epoch**（已存在 `_scanStreamEpoch`，建议扩大覆盖面）
   - 切模式/切后台/开始拍照时，所有异步推理结果若 epoch 不一致直接丢弃。
3. **start/stopImageStream 的状态机化**（P0）
   - 将 `start/stop` 放入串行队列，避免并发调用导致异常。
4. **Preview 分辨率与格式策略**（P1）
   - 在保证识别质量前提下，探索更低的预览分辨率（例如 `high/medium`）配合 ROI。
5. **日志与调试开关**（P0）
   - 把 per-frame debugPrint 改为采样/聚合输出（例如每 30 帧输出均值/分位）。

### 4.2 ONNX 推理（OnnxCornerDetector / LatexOcrService）
**目标**：推理稳定、波动小、失败可回退、模型加载不阻塞关键路径。

建议措施：
1. **模型加载时机**
   - 角点检测：仅在进入扫描模式时加载 LCNet；离开扫描模式可选择释放或保留（权衡内存与切换延迟）。
   - LaTeX OCR：保持懒加载，但需要“初始化中 UI 状态 + 可取消”。
2. **执行 Provider 策略验证**
   - 记录 NNAPI/XNNPACK 是否启用、是否 fallback，分机型建表。
3. **推理输入策略**
   - 预览流：维持 256 输入，但可加入“动态 ROI 缩放/平滑”。
   - 静态图：`_stillMaxLongEdge`（当前 320）可做机型分级（低端更小）。
4. **异常 fallback**
   - LCNet 推理失败→FastViT；FastViT 过慢→降低频率/减少调用。

### 4.3 扫描风格处理（ScanStyleProcessor）
**目标**：把最慢的形态学/滤波环节从秒级压到百毫秒级，降低内存分配。

建议措施：
1. **优化 `_dilateGray`（P0）**
   - 将二维最大值滤波改为：
     - 可分离最大滤波（先横向 1D max filter，再纵向 1D）或
     - van Herk/Gil-Werman 算法（1D O(n) max filter，再二维分离）。
2. **减少中间数组分配（P1）**
   - 多处 `Float32List(w*h)` 可用缓冲池复用，或按阶段复用变量。
3. **任务下沉到常驻 Isolate（P1）**
   - Smart HD 本质是 CPU 密集型，建议统一走 worker。

### 4.4 Isolate 与并发（compute → Worker）
**目标**：降低抖动与延迟尾部（P95），减少频繁 spawn 的开销。

建议措施：
1. 建立 `ImageTaskWorker`（单 worker 或小型池）
   - 支持 decode+bake、crop、encode、binarize 等任务类型。
2. 任务队列串行化关键资源（例如同一时间只跑一个大任务），避免 CPU 打满影响预览。

### 4.5 UI/渲染（Overlay）
**目标**：overlay 平滑、减少 repaint、避免 setState 过频。

建议措施：
1. overlay 已用 Ticker 插值（做得很好），下一步是：
   - 避免每 tick 都触发大量对象创建（例如 CornerPoint 列表频繁 new）。
2. `CustomPainter.shouldRepaint` 已较严格，保持；但可加入“阈值”避免微小变化 repaint。

### 4.6 网络抠图（CreatinfMattingService）
**目标**：弱网可恢复、失败可重试、有明确提示与降级，不拖垮主线程。

建议措施：
1. 明确超时、重试（指数退避）、可取消。
2. 对错误分类：DNS/连接/超时/HTTP 非 200/返回体异常。
3. 降级策略：
   - 网络失败→保留原图并提示稍后重试；或提供本地简易抠图（可选）。

---

## 5. 稳定性治理方案（长期有效）

### 5.1 监控与告警（建议落地到 Release）
1. 崩溃：建议接入 Crashlytics / Sentry（二选一即可）。
2. 关键链路耗时上报（匿名、聚合）：拍照到结果、Smart HD、OCR。
3. 设备信息维度：机型/系统版本/是否 NNAPI/XNNPACK/内存等级。

### 5.2 降级与兜底（必须清晰）
1. **低内存兜底**：检测到内存压力时降低分辨率、暂停 Smart HD、提示用户。
2. **推理降级**：
   - 预览推理频率动态调节（例如目标 10FPS，超时则降到 6FPS）。
   - LCNet/FastViT fallback。
3. **相机恢复**：后台恢复失败→自动 teardown+rebind；连续失败→提示重启相机页面。
4. **权限与异常**：权限拒绝、永久拒绝必须有引导；相机不可用必须可返回。

### 5.3 测试矩阵（建议）
| 维度 | 最低覆盖 |
|---|---|
| Android 版本 | 8/10/12/14（至少 3 档） |
| 芯片档位 | 低端（A53/入门）/中端/旗舰 |
| 摄像头组合 | 单摄/多摄（含超广角逻辑摄像头） |
| 网络 | WiFi/4G/弱网/离线 |
| 温度 | 常温/高温场景（充电+相机） |

---

## 6. 交付物模板（建议直接纳入 docs）

### 6.1 单次优化迭代必须产出
1. 优化目标与假设（为什么会快）
2. 修改点说明（代码/算法/参数）
3. 基线对比表（至少 P50/P95）
4. 风险与回滚方案
5. 回归验证结论

### 6.2 指标记录表（示例字段）
- 机型/SoC/系统版本/内存
- 模式（scan/aiCutout/formula/style）
- P50/P95 耗时
- 内存峰值
- UI FPS（平均/掉帧率）
- 推理 provider（NNAPI/XNNPACK/CPU）
- 失败率与错误码

---

## 7. 参考资料（建议在实现时补充链接）

> 本节给出“官方入口”，便于团队对齐工具与方法；不依赖第三方博客。

- Flutter 性能与 profiling：
  - https://docs.flutter.dev/perf
  - https://docs.flutter.dev/tools/devtools/performance
- Flutter `addTimingsCallback`/Frame timing（API 文档入口）：
  - https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html
- Android Perfetto：
  - https://perfetto.dev/
- ONNX Runtime（官方文档入口）：
  - https://onnxruntime.ai/docs/
