// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'DocScan';

  @override
  String get appTagline => '智能文档扫描 · AI 增强';

  @override
  String get pro => 'Pro';

  @override
  String get learnMore => '了解更多';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get share => '分享';

  @override
  String get save => '保存';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get tabHome => '首页';

  @override
  String get tabDocuments => '文档';

  @override
  String get tabTools => '工具箱';

  @override
  String get tabProfile => '我的';

  @override
  String get tabComingSoon => '即将开放，敬请期待';

  @override
  String get scanDocument => '扫描文档';

  @override
  String get homeStatsDocsLabel => '份文档';

  @override
  String get homeStatsPagesLabel => '页扫描';

  @override
  String get homeStatsSizeLabel => '已占用';

  @override
  String get homeSearchHint => '搜索功能：扫描 · 翻译 · 证件照 · 抠图';

  @override
  String get homeQuickToolsTitle => '快捷工具';

  @override
  String get homeProBannerTitle => 'Pro 会员限时优惠';

  @override
  String get homeProBannerSubtitle => '去广告 · 无水印 · 批量 OCR · 云同步';

  @override
  String get homeRecentDocsTitle => '最近文档';

  @override
  String get homeRecentDocsViewAll => '查看全部';

  @override
  String get homeRecentDocsEmptyTitle => '开始你的第一次扫描';

  @override
  String get homeRecentDocsEmptySubtitle => '点击下方相机按钮，或从相册导入';

  @override
  String get toolScan => '智能扫描';

  @override
  String get toolImport => '导入图片';

  @override
  String get toolIdPhoto => '证件照';

  @override
  String get toolText => '文字识别';

  @override
  String get toolFormula => '公式识别';

  @override
  String get toolTranslate => '翻译';

  @override
  String get toolCutout => 'AI 抠图';

  @override
  String get toolErase => 'AI 擦除';

  @override
  String get toolESign => '电子签名';

  @override
  String get toolObject => '物体识别';

  @override
  String get proSheetTitle => 'DocScan Pro';

  @override
  String get proFeatureNoAdsTitle => '去广告 · 无打扰';

  @override
  String get proFeatureNoAdsSubtitle => '全局移除插入广告与引导弹窗';

  @override
  String get proFeatureNoWatermarkTitle => '去水印导出';

  @override
  String get proFeatureNoWatermarkSubtitle => '导出 PDF / 分享图片不带品牌水印';

  @override
  String get proFeatureBatchOcrTitle => '批量 OCR';

  @override
  String get proFeatureBatchOcrSubtitle => '一次处理整本多页扫描件，导出可复制文字';

  @override
  String get proFeatureCloudSyncTitle => '云同步（规划中）';

  @override
  String get proFeatureCloudSyncSubtitle => '跨设备同步最近文档与设置';

  @override
  String get proSheetCta => '敬请期待';

  @override
  String get allDocsTitle => '全部文档';

  @override
  String get allDocsSearchHint => '搜索文档标题';

  @override
  String get allDocsClear => '清空';

  @override
  String get allDocsClearConfirmTitle => '清空全部文档';

  @override
  String get allDocsClearConfirmBody => '将删除全部扫描记录与页面文件，此操作不可恢复。';

  @override
  String get allDocsEmpty => '还没有文档';

  @override
  String get allDocsEmptyHint => '点击下方相机按钮开始扫描';

  @override
  String get allDocsNoMatch => '没有匹配结果';

  @override
  String get allDocsNoMatchHint => '换个关键词试试';

  @override
  String get deleteDocTitle => '删除文档';

  @override
  String deleteDocBody(String title) {
    return '确定删除「$title」？';
  }

  @override
  String get renameDialogTitle => '重命名';

  @override
  String get renameDialogHint => '输入新的文档名称';

  @override
  String get docDetailContinueCapture => '继续拍摄';

  @override
  String get docDetailExportShare => '导出并分享';

  @override
  String get docDetailExportPdf => '导出 PDF';

  @override
  String get docDetailExportZip => '导出 ZIP（图片包）';

  @override
  String get docDetailExportChooseTitle => '选择导出格式';

  @override
  String docDetailPagesAdded(int n) {
    return '已添加第 $n 页';
  }

  @override
  String docDetailPageIndicator(int current, int total) {
    return '$current / $total 页';
  }

  @override
  String get docDetailEmptyTitle => '无法打开该文档';

  @override
  String get docDetailEmptyLegacy => '此文档为旧版本条目，仅有缩略图。请重新扫描生成完整文档。';

  @override
  String get docDetailEmptyMissing => '页面文件可能被清理，请删除后重新扫描';

  @override
  String get toolsSectionScan => '智能扫描';

  @override
  String get toolsSectionPdf => 'PDF 工具';

  @override
  String get toolsSectionMore => '更多';

  @override
  String get pdfMergeTitle => 'PDF 合并';

  @override
  String get pdfMergeSubtitle => '从相册选图 · 一键导出为多页 PDF';

  @override
  String get pdfMergeEmpty => '从相册选图以开始合并';

  @override
  String get pdfMergeEmptyHint => '支持多选，按选择顺序排版';

  @override
  String get pdfMergePickImages => '选择图片';

  @override
  String pdfMergeExportLabel(int n) {
    return '导出并分享 ($n 页)';
  }

  @override
  String get pdfMergeExporting => '处理中…';

  @override
  String get pdfCompressTitle => 'PDF 压缩';

  @override
  String get pdfCompressSubtitle => '选择已扫描文档 · 降采样重新导出，体积更小';

  @override
  String get pdfCompressEmpty => '暂无可压缩的本地文档。\n请先通过相机扫描生成文档。';

  @override
  String get pdfSplitTitle => 'PDF 拆分';

  @override
  String get pdfSplitSubtitle => '把文档按页拆为多个 PDF · 一并打包分享';

  @override
  String get pdfSplitDoTitle => '拆分并分享';

  @override
  String pdfSplitDoneToast(int n) {
    return '已拆分为 $n 个 PDF';
  }

  @override
  String get pdfWatermarkTitle => 'PDF 加水印';

  @override
  String get pdfWatermarkSubtitle => '添加文字水印，导出新的 PDF';

  @override
  String get pdfWatermarkInputLabel => '水印文字';

  @override
  String get pdfWatermarkInputHint => '如：DocScan / 仅供参考';

  @override
  String get pdfWatermarkExportLabel => '添加水印并分享';

  @override
  String get pdfPasswordTitle => 'PDF 密码保护';

  @override
  String get pdfPasswordSubtitle => '设置密码后导出 · 即将开放';

  @override
  String get pdfPasswordPending => 'PDF 加密能力开发中';

  @override
  String get zipExportTitle => '打包为 ZIP';

  @override
  String get zipExportSubtitle => '把所有页 JPEG 打包成压缩包，便于转发原图';

  @override
  String get zipExportEmpty => '暂无可打包的本地文档';

  @override
  String get zipExportShareSubject => 'DocScan 图片包';

  @override
  String get moreToolsScanWordExcel => '扫描到 Word / Excel';

  @override
  String get moreToolsComingSoon => '即将开放，敬请期待';

  @override
  String shareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }
}
