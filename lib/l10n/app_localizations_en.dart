// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DocScan';

  @override
  String get appTagline => 'Smart document scanner · AI enhanced';

  @override
  String get pro => 'Pro';

  @override
  String get learnMore => 'Learn more';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get exportAndShare => 'Export & share';

  @override
  String get tabHome => 'Home';

  @override
  String get tabDocuments => 'Documents';

  @override
  String get tabTools => 'Tools';

  @override
  String get tabProfile => 'Me';

  @override
  String get tabComingSoon => 'Coming soon';

  @override
  String get scanDocument => 'Scan document';

  @override
  String get homeStatsDocsLabel => 'Documents';

  @override
  String get homeStatsPagesLabel => 'Pages';

  @override
  String get homeStatsSizeLabel => 'Storage';

  @override
  String get homeSearchHint => 'Search: scan · translate · ID photo · cutout';

  @override
  String get homeQuickToolsTitle => 'Quick tools';

  @override
  String get homeProBannerTitle => 'Pro membership · limited time';

  @override
  String get homeProBannerSubtitle =>
      'No ads · no watermark · batch OCR · cloud sync';

  @override
  String get homeRecentDocsTitle => 'Recent documents';

  @override
  String get homeRecentDocsViewAll => 'View all';

  @override
  String get homeRecentDocsEmptyTitle => 'Start your first scan';

  @override
  String get homeRecentDocsEmptySubtitle =>
      'Tap the camera button or import from gallery';

  @override
  String get toolScan => 'Smart scan';

  @override
  String get toolImport => 'Import image';

  @override
  String get toolIdPhoto => 'ID photo';

  @override
  String get toolText => 'Text OCR';

  @override
  String get toolFormula => 'Formula OCR';

  @override
  String get toolTranslate => 'Translate';

  @override
  String get toolCutout => 'AI cutout';

  @override
  String get toolErase => 'AI erase';

  @override
  String get toolESign => 'E-signature';

  @override
  String get toolObject => 'Object recognition';

  @override
  String get proSheetTitle => 'DocScan Pro';

  @override
  String get proFeatureNoAdsTitle => 'No ads · distraction-free';

  @override
  String get proFeatureNoAdsSubtitle =>
      'Removes inserted ads and onboarding popups';

  @override
  String get proFeatureNoWatermarkTitle => 'Watermark-free export';

  @override
  String get proFeatureNoWatermarkSubtitle =>
      'Export PDFs / share images without branding';

  @override
  String get proFeatureBatchOcrTitle => 'Batch OCR';

  @override
  String get proFeatureBatchOcrSubtitle =>
      'OCR an entire scan in one shot; copy text out';

  @override
  String get proFeatureCloudSyncTitle => 'Cloud sync (planned)';

  @override
  String get proFeatureCloudSyncSubtitle =>
      'Sync recent documents and settings across devices';

  @override
  String get proSheetCta => 'Coming soon';

  @override
  String get allDocsTitle => 'All documents';

  @override
  String get allDocsSearchHint => 'Search by title';

  @override
  String get allDocsClear => 'Clear';

  @override
  String get allDocsClearConfirmTitle => 'Clear all documents';

  @override
  String get allDocsClearConfirmBody =>
      'This will delete every scan record and page file. Cannot be undone.';

  @override
  String get allDocsEmpty => 'No documents yet';

  @override
  String get allDocsEmptyHint =>
      'Tap the camera button below to start scanning';

  @override
  String get allDocsNoMatch => 'No matches';

  @override
  String get allDocsNoMatchHint => 'Try different keywords';

  @override
  String get deleteDocTitle => 'Delete document';

  @override
  String deleteDocBody(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get renameDialogTitle => 'Rename';

  @override
  String get renameDialogHint => 'Enter a new document name';

  @override
  String get docDetailContinueCapture => 'Continue capture';

  @override
  String get docDetailExportShare => 'Export & share';

  @override
  String get docDetailExportPdf => 'Export PDF';

  @override
  String get docDetailExportZip => 'Export ZIP (image bundle)';

  @override
  String get docDetailExportChooseTitle => 'Choose export format';

  @override
  String docDetailPagesAdded(int n) {
    return 'Page $n added';
  }

  @override
  String docDetailPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get docDetailEmptyTitle => 'Can\'t open this document';

  @override
  String get docDetailEmptyLegacy =>
      'This is a legacy entry with only a thumbnail. Re-scan to create a full document.';

  @override
  String get docDetailEmptyMissing =>
      'Page files may have been cleaned up. Delete and re-scan.';

  @override
  String get toolsSectionScan => 'Smart scan';

  @override
  String get toolsSectionPdf => 'PDF tools';

  @override
  String get toolsSectionMore => 'More';

  @override
  String get pdfMergeTitle => 'Merge PDF';

  @override
  String get pdfMergeSubtitle =>
      'Pick photos from gallery · export as multi-page PDF';

  @override
  String get pdfMergeEmpty => 'Pick images to start merging';

  @override
  String get pdfMergeEmptyHint =>
      'Multi-select supported; pages follow selection order';

  @override
  String get pdfMergePickImages => 'Pick images';

  @override
  String pdfMergeExportLabel(int n) {
    return 'Export & share ($n pages)';
  }

  @override
  String get pdfMergeExporting => 'Processing…';

  @override
  String get pdfCompressTitle => 'Compress PDF';

  @override
  String get pdfCompressSubtitle =>
      'Pick a scan · downsample & re-export at smaller size';

  @override
  String get pdfCompressEmpty =>
      'No local documents to compress.\nUse the camera to scan a document first.';

  @override
  String get pdfSplitTitle => 'Split PDF';

  @override
  String get pdfSplitSubtitle =>
      'Split a document into per-page PDFs · share as one bundle';

  @override
  String get pdfSplitDoTitle => 'Split & share';

  @override
  String pdfSplitDoneToast(int n) {
    return 'Split into $n PDFs';
  }

  @override
  String get pdfWatermarkTitle => 'Watermark PDF';

  @override
  String get pdfWatermarkSubtitle => 'Add a text watermark to every page';

  @override
  String get pdfWatermarkInputLabel => 'Watermark text';

  @override
  String get pdfWatermarkInputHint => 'e.g. DocScan / Confidential';

  @override
  String get pdfWatermarkExportLabel => 'Add watermark & share';

  @override
  String get pdfPasswordTitle => 'Password-protect PDF';

  @override
  String get pdfPasswordSubtitle => 'Encrypt with password · coming soon';

  @override
  String get pdfPasswordPending => 'PDF encryption is under development';

  @override
  String get zipExportTitle => 'Bundle as ZIP';

  @override
  String get zipExportSubtitle => 'Pack all page JPEGs into a single archive';

  @override
  String get zipExportEmpty => 'No local documents to bundle';

  @override
  String get zipExportShareSubject => 'DocScan image bundle';

  @override
  String get moreToolsScanWordExcel => 'Scan to Word / Excel';

  @override
  String get moreToolsComingSoon => 'Coming soon';

  @override
  String shareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }
}
