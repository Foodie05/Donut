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
  String get modelName => '模型名称';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get readingDirection => '阅读方向';

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
  String get apiBaseUrl => 'API 基础地址';

  @override
  String get deleteBook => '删除书籍';

  @override
  String get resetAiData => '重置 AI 数据';

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
  String get multiPageContext => '多页上下文已开启';
}
