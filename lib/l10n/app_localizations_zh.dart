// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get bookshelf => '书籍库';

  @override
  String get settings => '设置';

  @override
  String get reader => '阅读器';

  @override
  String get modelName => '模型名称';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get readingDirection => '阅读方向';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色';

  @override
  String get darkMode => '深色';

  @override
  String get horizontal => '横向';

  @override
  String get vertical => '纵向';

  @override
  String get debounceDelay => '防抖时间';

  @override
  String get autoGenerate => '自动生成摘要';

  @override
  String get autoGenerateSubtitle => '阅读时自动分析页面内容';

  @override
  String debounceDelaySubtitle(Object seconds) {
    return '翻页后等待 $seconds 秒生成摘要';
  }

  @override
  String get regenerate => '重新生成';

  @override
  String get summary => '摘要';

  @override
  String get chat => '对话';

  @override
  String get pageSummary => '页面摘要';

  @override
  String get noSummary => '暂无摘要';

  @override
  String get closePanel => '关闭面板';

  @override
  String get regenerateSummary => '重新生成摘要';

  @override
  String get errorPrefix => '错误: ';

  @override
  String get aiSummary => 'AI 摘要';

  @override
  String get analyzePrompt => '分析此 PDF 页面内容。提供简洁的 Markdown 格式摘要。';

  @override
  String get systemPrompt => '你是一个 PDF 阅读器应用程序中的有用的 AI 助手。你可以访问当前页面图像及其摘要。根据此上下文回答用户的问题。';

  @override
  String get apiKeyMissing => 'API 密钥未配置';

  @override
  String get aiRequestFailed => 'AI 请求失败: ';

  @override
  String get enterMessage => '输入消息...';

  @override
  String pageIndicator(Object current, Object total) {
    return '$current/$total';
  }

  @override
  String get noBooks => '暂无书籍';

  @override
  String get addPdf => '添加 PDF';

  @override
  String get errorAddingBook => '添加书籍失败: ';

  @override
  String get aiConfiguration => 'AI 配置';

  @override
  String get aiCategorySubtitle => '配置模型、接口地址、密钥和回复长度';

  @override
  String get apiBaseUrl => 'API 基础地址';

  @override
  String get modelReplyLength => '模型回复长度';

  @override
  String get modelReplyLengthSubtitle => '为模型回复设置上限以节约额度，但可能导致得到的内容不完整';

  @override
  String get modelReplyLengthShort => '短';

  @override
  String get modelReplyLengthMedium => '中';

  @override
  String get modelReplyLengthLong => '长';

  @override
  String get modelReplyLengthUnlimited => '无限';

  @override
  String get deleteBook => '删除书籍';

  @override
  String get resetAiData => '重置 AI 数据';

  @override
  String get deleteBookWarning => '删除后将移除该书籍文件、封面和相关 AI 数据，此操作不可撤销。';

  @override
  String get resetAiDataWarning => '重置后将清空这本书的所有页面摘要和对话记录，且不可恢复。';

  @override
  String get resetAiDataDone => '已重置该书籍的 AI 数据';

  @override
  String get exportBookFile => '导出文件';

  @override
  String get exportFormatPdfSubtitle => '在任何 PDF 软件中阅读书籍';

  @override
  String get exportFormatDpdfSubtitle => '将你的 AI 内容和对话记录共享给他人';

  @override
  String get exportBookFileSuccess => '导出成功';

  @override
  String get exportBookFileFailed => '导出失败，请检查目标位置是否可写';

  @override
  String get duplicateBookTitle => '检测到重复书籍';

  @override
  String duplicateBookMessage(Object title) {
    return '该书与“$title”内容相同（哈希一致），是否仍要重复导入？';
  }

  @override
  String get statistics => '阅读统计';

  @override
  String get day => '本日';

  @override
  String get week => '本周';

  @override
  String get month => '本月';

  @override
  String get year => '本年';

  @override
  String get all => '总计';

  @override
  String get nav_statistics => '统计';

  @override
  String get readingTime => '阅读时长';

  @override
  String get readingFrequency => '阅读频次';

  @override
  String get topBooks => '书籍排行';

  @override
  String get noReadingData => '暂无阅读数据';

  @override
  String get startReading => '开始阅读';

  @override
  String get exploreBookshelf => '探索书架';

  @override
  String get hourShort => '小时';

  @override
  String get minuteShort => '分钟';

  @override
  String get goal => '目标';

  @override
  String get pseudoKBMode => '伪知识库模式';

  @override
  String get pseudoKBModeSubtitle => '包含前两页内容以增强上下文理解';

  @override
  String get smoothSummary => '平滑的摘要';

  @override
  String get smoothSummarySubtitle => 'AI 面板开启时，提前生成下一页摘要';

  @override
  String get powerSavingMode => '节能模式';

  @override
  String get powerSavingModeSubtitle => 'AI 面板关闭时，不启动新的摘要任务和倒计时';

  @override
  String get summaryProfiles => '摘要配置文件';

  @override
  String get createProfile => '新建配置';

  @override
  String get editProfile => '编辑配置';

  @override
  String get viewProfile => '查看配置';

  @override
  String get deleteProfile => '删除配置';

  @override
  String get profileName => '配置名称';

  @override
  String get promptTemplate => '提示词模板';

  @override
  String get copyPrompt => '复制提示词';

  @override
  String get promptCopied => '提示词已复制';

  @override
  String get defaultSummaryProfileSubtitle => '内置默认提示词，不可编辑';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get multiPageContext => '多页上下文已开启';

  @override
  String get dataAndLegal => '数据与法律';

  @override
  String get readerCategorySubtitle => '管理摘要生成、上下文与阅读辅助';

  @override
  String get appearanceCategorySubtitle => '调整主题与阅读方向显示方式';

  @override
  String get dataLegalCategorySubtitle => '导入导出配置、查看协议与开源许可';

  @override
  String get importSettings => '导入设置';

  @override
  String get importSettingsSubtitle => '从外部 JSON 配置文件导入可配置项';

  @override
  String get exportSettings => '导出设置';

  @override
  String get exportSettingsSubtitle => '将当前配置导出为 JSON 文件';

  @override
  String get settingsHistory => '历史配置';

  @override
  String get settingsHistorySubtitle => '查看最近 10 份配置并快速回退';

  @override
  String get settingsHistoryEmpty => '暂无历史配置';

  @override
  String get settingsHistoryRestoreSuccess => '已恢复历史配置';

  @override
  String get settingsHistoryRestoreFailed => '恢复失败，请检查配置文件是否有效';

  @override
  String get pickSettingsJson => '选择设置 JSON 文件';

  @override
  String get saveSettingsJson => '保存设置 JSON 文件';

  @override
  String get importSettingsSuccess => '设置导入成功';

  @override
  String get importSettingsInvalidJson => '导入失败：JSON 格式无效';

  @override
  String get importSettingsInvalidStructure => '导入失败：配置结构不正确';

  @override
  String get importSettingsIoError => '导入失败：无法读取文件';

  @override
  String get exportSettingsSuccess => '设置导出成功';

  @override
  String get exportSettingsIoError => '导出失败：无法写入文件';

  @override
  String get exportDebugLogs => '提取调试日志';

  @override
  String get exportDebugLogsSubtitle => '导出文件打开/导入链路日志用于排查问题';

  @override
  String get saveDebugLog => '保存调试日志';

  @override
  String get exportDebugLogsSuccess => '调试日志导出成功';

  @override
  String get exportDebugLogsFailed => '调试日志导出失败';

  @override
  String get termsOfService => 'Donut 服务条款';

  @override
  String get termsOfServiceSubtitle => '查看 Donut 服务条款全文';

  @override
  String get privacyPolicy => '用户隐私协议';

  @override
  String get privacyPolicySubtitle => '查看 Donut 用户隐私协议全文';

  @override
  String get openSourceLicenses => '开放源代码许可';

  @override
  String get openSourceLicensesSubtitle => '查看本应用使用的第三方开源许可';

  @override
  String get welcomeTitle => '欢迎来吃Donut!';

  @override
  String get welcomeMessageLine1 => '在这里轻松阅读你的PDF，并获得见解和灵感。';

  @override
  String get welcomeMessageLine2 => '与模型对话，获得新思路。';

  @override
  String get welcomeMessageLine3 => '请先阅读并同意服务条款与隐私协议。';

  @override
  String currentVersionBeta(Object version) {
    return '当前版本：$version 内测版';
  }

  @override
  String get agreementCheckboxLabel => '我已阅读并同意《Donut服务条款》和《用户隐私协议》';

  @override
  String get viewTermsOfService => '查看《Donut服务条款》';

  @override
  String get viewPrivacyPolicy => '查看《用户隐私协议》';

  @override
  String get agreementRequiredTitle => '继续使用前请先同意';

  @override
  String get agreementRequiredBody => '为继续使用 Donut，请阅读并同意服务条款与隐私协议。';

  @override
  String get releaseNotesTitle => '更新日志';

  @override
  String get noReleaseNotes => '暂无可展示的更新内容。';

  @override
  String get confirm => '确认';

  @override
  String get restore => '恢复';
}
