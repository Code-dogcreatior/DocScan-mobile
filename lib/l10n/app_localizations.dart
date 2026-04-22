import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'DocScan'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'智能文档扫描 · AI 增强'**
  String get appTagline;

  /// No description provided for @pro.
  ///
  /// In zh, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @learnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多'**
  String get learnMore;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @exportAndShare.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享'**
  String get exportAndShare;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabDocuments.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get tabDocuments;

  /// No description provided for @tabTools.
  ///
  /// In zh, this message translates to:
  /// **'工具箱'**
  String get tabTools;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// No description provided for @tabComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将开放，敬请期待'**
  String get tabComingSoon;

  /// No description provided for @scanDocument.
  ///
  /// In zh, this message translates to:
  /// **'扫描文档'**
  String get scanDocument;

  /// No description provided for @homeStatsDocsLabel.
  ///
  /// In zh, this message translates to:
  /// **'份文档'**
  String get homeStatsDocsLabel;

  /// No description provided for @homeStatsPagesLabel.
  ///
  /// In zh, this message translates to:
  /// **'页扫描'**
  String get homeStatsPagesLabel;

  /// No description provided for @homeStatsSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'已占用'**
  String get homeStatsSizeLabel;

  /// No description provided for @homeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索功能：扫描 · 翻译 · 证件照 · 抠图'**
  String get homeSearchHint;

  /// No description provided for @homeQuickToolsTitle.
  ///
  /// In zh, this message translates to:
  /// **'快捷工具'**
  String get homeQuickToolsTitle;

  /// No description provided for @homeProBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'Pro 会员限时优惠'**
  String get homeProBannerTitle;

  /// No description provided for @homeProBannerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'去广告 · 无水印 · 批量 OCR · 云同步'**
  String get homeProBannerSubtitle;

  /// No description provided for @homeRecentDocsTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近文档'**
  String get homeRecentDocsTitle;

  /// No description provided for @homeRecentDocsViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get homeRecentDocsViewAll;

  /// No description provided for @homeRecentDocsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'开始你的第一次扫描'**
  String get homeRecentDocsEmptyTitle;

  /// No description provided for @homeRecentDocsEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击下方相机按钮，或从相册导入'**
  String get homeRecentDocsEmptySubtitle;

  /// No description provided for @toolScan.
  ///
  /// In zh, this message translates to:
  /// **'智能扫描'**
  String get toolScan;

  /// No description provided for @toolImport.
  ///
  /// In zh, this message translates to:
  /// **'导入图片'**
  String get toolImport;

  /// No description provided for @toolIdPhoto.
  ///
  /// In zh, this message translates to:
  /// **'证件照'**
  String get toolIdPhoto;

  /// No description provided for @toolText.
  ///
  /// In zh, this message translates to:
  /// **'文字识别'**
  String get toolText;

  /// No description provided for @toolFormula.
  ///
  /// In zh, this message translates to:
  /// **'公式识别'**
  String get toolFormula;

  /// No description provided for @toolTranslate.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get toolTranslate;

  /// No description provided for @toolCutout.
  ///
  /// In zh, this message translates to:
  /// **'AI 抠图'**
  String get toolCutout;

  /// No description provided for @toolErase.
  ///
  /// In zh, this message translates to:
  /// **'AI 擦除'**
  String get toolErase;

  /// No description provided for @toolESign.
  ///
  /// In zh, this message translates to:
  /// **'电子签名'**
  String get toolESign;

  /// No description provided for @toolObject.
  ///
  /// In zh, this message translates to:
  /// **'物体识别'**
  String get toolObject;

  /// No description provided for @proSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'DocScan Pro'**
  String get proSheetTitle;

  /// No description provided for @proFeatureNoAdsTitle.
  ///
  /// In zh, this message translates to:
  /// **'去广告 · 无打扰'**
  String get proFeatureNoAdsTitle;

  /// No description provided for @proFeatureNoAdsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'全局移除插入广告与引导弹窗'**
  String get proFeatureNoAdsSubtitle;

  /// No description provided for @proFeatureNoWatermarkTitle.
  ///
  /// In zh, this message translates to:
  /// **'去水印导出'**
  String get proFeatureNoWatermarkTitle;

  /// No description provided for @proFeatureNoWatermarkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出 PDF / 分享图片不带品牌水印'**
  String get proFeatureNoWatermarkSubtitle;

  /// No description provided for @proFeatureBatchOcrTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量 OCR'**
  String get proFeatureBatchOcrTitle;

  /// No description provided for @proFeatureBatchOcrSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'一次处理整本多页扫描件，导出可复制文字'**
  String get proFeatureBatchOcrSubtitle;

  /// No description provided for @proFeatureCloudSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'云同步（规划中）'**
  String get proFeatureCloudSyncTitle;

  /// No description provided for @proFeatureCloudSyncSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'跨设备同步最近文档与设置'**
  String get proFeatureCloudSyncSubtitle;

  /// No description provided for @proSheetCta.
  ///
  /// In zh, this message translates to:
  /// **'敬请期待'**
  String get proSheetCta;

  /// No description provided for @allDocsTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部文档'**
  String get allDocsTitle;

  /// No description provided for @allDocsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索文档标题'**
  String get allDocsSearchHint;

  /// No description provided for @allDocsClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get allDocsClear;

  /// No description provided for @allDocsClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空全部文档'**
  String get allDocsClearConfirmTitle;

  /// No description provided for @allDocsClearConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除全部扫描记录与页面文件，此操作不可恢复。'**
  String get allDocsClearConfirmBody;

  /// No description provided for @allDocsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有文档'**
  String get allDocsEmpty;

  /// No description provided for @allDocsEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方相机按钮开始扫描'**
  String get allDocsEmptyHint;

  /// No description provided for @allDocsNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配结果'**
  String get allDocsNoMatch;

  /// No description provided for @allDocsNoMatchHint.
  ///
  /// In zh, this message translates to:
  /// **'换个关键词试试'**
  String get allDocsNoMatchHint;

  /// No description provided for @deleteDocTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除文档'**
  String get deleteDocTitle;

  /// No description provided for @deleteDocBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{title}」？'**
  String deleteDocBody(String title);

  /// No description provided for @renameDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameDialogTitle;

  /// No description provided for @renameDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新的文档名称'**
  String get renameDialogHint;

  /// No description provided for @docDetailContinueCapture.
  ///
  /// In zh, this message translates to:
  /// **'继续拍摄'**
  String get docDetailContinueCapture;

  /// No description provided for @docDetailExportShare.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享'**
  String get docDetailExportShare;

  /// No description provided for @docDetailExportPdf.
  ///
  /// In zh, this message translates to:
  /// **'导出 PDF'**
  String get docDetailExportPdf;

  /// No description provided for @docDetailExportZip.
  ///
  /// In zh, this message translates to:
  /// **'导出 ZIP（图片包）'**
  String get docDetailExportZip;

  /// No description provided for @docDetailExportChooseTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择导出格式'**
  String get docDetailExportChooseTitle;

  /// No description provided for @docDetailPagesAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加第 {n} 页'**
  String docDetailPagesAdded(int n);

  /// No description provided for @docDetailPageIndicator.
  ///
  /// In zh, this message translates to:
  /// **'{current} / {total} 页'**
  String docDetailPageIndicator(int current, int total);

  /// No description provided for @docDetailEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法打开该文档'**
  String get docDetailEmptyTitle;

  /// No description provided for @docDetailEmptyLegacy.
  ///
  /// In zh, this message translates to:
  /// **'此文档为旧版本条目，仅有缩略图。请重新扫描生成完整文档。'**
  String get docDetailEmptyLegacy;

  /// No description provided for @docDetailEmptyMissing.
  ///
  /// In zh, this message translates to:
  /// **'页面文件可能被清理，请删除后重新扫描'**
  String get docDetailEmptyMissing;

  /// No description provided for @toolsSectionScan.
  ///
  /// In zh, this message translates to:
  /// **'智能扫描'**
  String get toolsSectionScan;

  /// No description provided for @toolsSectionPdf.
  ///
  /// In zh, this message translates to:
  /// **'PDF 工具'**
  String get toolsSectionPdf;

  /// No description provided for @toolsSectionMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get toolsSectionMore;

  /// No description provided for @pdfMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'PDF 合并'**
  String get pdfMergeTitle;

  /// No description provided for @pdfMergeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从相册选图 · 一键导出为多页 PDF'**
  String get pdfMergeSubtitle;

  /// No description provided for @pdfMergeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'从相册选图以开始合并'**
  String get pdfMergeEmpty;

  /// No description provided for @pdfMergeEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'支持多选，按选择顺序排版'**
  String get pdfMergeEmptyHint;

  /// No description provided for @pdfMergePickImages.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get pdfMergePickImages;

  /// No description provided for @pdfMergeExportLabel.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享 ({n} 页)'**
  String pdfMergeExportLabel(int n);

  /// No description provided for @pdfMergeExporting.
  ///
  /// In zh, this message translates to:
  /// **'处理中…'**
  String get pdfMergeExporting;

  /// No description provided for @pdfCompressTitle.
  ///
  /// In zh, this message translates to:
  /// **'PDF 压缩'**
  String get pdfCompressTitle;

  /// No description provided for @pdfCompressSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择已扫描文档 · 降采样重新导出，体积更小'**
  String get pdfCompressSubtitle;

  /// No description provided for @pdfCompressEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无可压缩的本地文档。\n请先通过相机扫描生成文档。'**
  String get pdfCompressEmpty;

  /// No description provided for @pdfSplitTitle.
  ///
  /// In zh, this message translates to:
  /// **'PDF 拆分'**
  String get pdfSplitTitle;

  /// No description provided for @pdfSplitSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把文档按页拆为多个 PDF · 一并打包分享'**
  String get pdfSplitSubtitle;

  /// No description provided for @pdfSplitDoTitle.
  ///
  /// In zh, this message translates to:
  /// **'拆分并分享'**
  String get pdfSplitDoTitle;

  /// No description provided for @pdfSplitDoneToast.
  ///
  /// In zh, this message translates to:
  /// **'已拆分为 {n} 个 PDF'**
  String pdfSplitDoneToast(int n);

  /// No description provided for @pdfWatermarkTitle.
  ///
  /// In zh, this message translates to:
  /// **'PDF 加水印'**
  String get pdfWatermarkTitle;

  /// No description provided for @pdfWatermarkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加文字水印，导出新的 PDF'**
  String get pdfWatermarkSubtitle;

  /// No description provided for @pdfWatermarkInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'水印文字'**
  String get pdfWatermarkInputLabel;

  /// No description provided for @pdfWatermarkInputHint.
  ///
  /// In zh, this message translates to:
  /// **'如：DocScan / 仅供参考'**
  String get pdfWatermarkInputHint;

  /// No description provided for @pdfWatermarkExportLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加水印并分享'**
  String get pdfWatermarkExportLabel;

  /// No description provided for @pdfPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'PDF 密码保护'**
  String get pdfPasswordTitle;

  /// No description provided for @pdfPasswordSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置密码后导出 · 即将开放'**
  String get pdfPasswordSubtitle;

  /// No description provided for @pdfPasswordPending.
  ///
  /// In zh, this message translates to:
  /// **'PDF 加密能力开发中'**
  String get pdfPasswordPending;

  /// No description provided for @zipExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'打包为 ZIP'**
  String get zipExportTitle;

  /// No description provided for @zipExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把所有页 JPEG 打包成压缩包，便于转发原图'**
  String get zipExportSubtitle;

  /// No description provided for @zipExportEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无可打包的本地文档'**
  String get zipExportEmpty;

  /// No description provided for @zipExportShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'DocScan 图片包'**
  String get zipExportShareSubject;

  /// No description provided for @moreToolsScanWordExcel.
  ///
  /// In zh, this message translates to:
  /// **'扫描到 Word / Excel'**
  String get moreToolsScanWordExcel;

  /// No description provided for @moreToolsComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将开放，敬请期待'**
  String get moreToolsComingSoon;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败：{error}'**
  String shareFailed(String error);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
