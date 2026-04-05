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
  String get aiCategorySubtitle => '配置模型来源、回复长度和自定义连接';

  @override
  String get apiBaseUrl => 'API 基础地址';

  @override
  String get serverModelSelection => '服务器模型';

  @override
  String get serverModelSelectionSubtitle => '登录后可使用服务器提供的模型';

  @override
  String get customModelOption => '自定义';

  @override
  String get customModelOptionSubtitle => '使用你自己的模型服务连接';

  @override
  String get loginForAiService => '请登录以获得AI服务';

  @override
  String get loginForAiServiceSubtitle => '登录后即可使用服务器提供的模型';

  @override
  String get recommendedModelTag => '推荐';

  @override
  String get customConnectionTitle => '自定义连接';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '测试连接中...';

  @override
  String testConnectionSuccess(Object count) {
    return '连接成功，已获取 $count 个模型。';
  }

  @override
  String get testConnectionFailed => '连接失败，请检查 Base URL 和 API Key。';

  @override
  String get customConnectionHint => '启用自定义后，将直接使用你填写的 Base URL、模型和 API Key。';

  @override
  String get serverModelsUnavailable => '服务器当前没有可用模型，请联系管理员。';

  @override
  String get aiServiceUnavailable => 'AI服务暂不可用';

  @override
  String get aiServiceUnavailableSubtitle => '请选择有效的配置';

  @override
  String get aiServiceSignInRequiredSubtitle => '请登录账号以享受服务';

  @override
  String get aiUnknownError => '发生未知错误';

  @override
  String get aiUnknownErrorSubtitle => '请尝试更换模型或联系开发者';

  @override
  String get aiQuotaExceededTitle => '今日额度已用完';

  @override
  String get aiQuotaExceededSubtitle => '您已经用完了今天的用量。稍后我们会提供更顺畅的服务，敬请期待！';

  @override
  String get aiModelUnavailableTitle => '模型暂不可用';

  @override
  String get aiModelUnavailableSubtitle => '模型暂不可用，请尝试使用其他模型或联系开发者';

  @override
  String get aiCustomModelHint => '您正在使用自定义模型，切换到Donut提供的模型以获得更稳定的体验。';

  @override
  String get aiNetworkUnavailableTitle => '网络无法连接';

  @override
  String get aiNetworkUnavailableSubtitle => '网络无法连接，请检查您的网络';

  @override
  String get openModelSettings => '前往模型配置';

  @override
  String get pageNote => '笔记';

  @override
  String get pageNoteHint => '在这里记录这一页的笔记，支持 Markdown。';

  @override
  String get pageNoteEmpty => '这一页还没有笔记，点击这里开始编辑。';

  @override
  String get editNote => '编辑笔记';

  @override
  String get previewNote => '预览笔记';

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
  String get swapReaderPanels => '对调左右栏';

  @override
  String get swapReaderPanelsSubtitle => '交换缩略图栏与 AI 栏的位置';

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

  @override
  String get account => '账户';

  @override
  String get accountCategorySubtitle => '查看登录状态和当前会话信息';

  @override
  String get signInTitle => '登录到Donut';

  @override
  String get signInSubtitle => '登录到Donut以享受完整体验';

  @override
  String get sessionActive => '会话已生效';

  @override
  String sessionExpiresAt(Object time) {
    return '会话将于 $time 过期';
  }

  @override
  String get waitingForBrowserSignIn => '正在等待浏览器完成登录...';

  @override
  String get signOut => '退出登录';

  @override
  String get authenticatedStatus => '已登录';

  @override
  String get dailyQuotaLabel => '今日额度';

  @override
  String dailyQuotaUsage(Object used, Object limit) {
    return '$used/$limit 页';
  }

  @override
  String get chatOnlyModelTag => '仅聊天';

  @override
  String get signedOutStatus => '未登录';

  @override
  String get accountNameLabel => '名称';

  @override
  String get accountEmailLabel => '邮箱';

  @override
  String get accountSubjectLabel => '主体标识';

  @override
  String get accountExpiresAtLabel => '过期时间';

  @override
  String get accountBffHint => '当前应用会先通过 Donut 后端建立会话，再访问受保护功能。';

  @override
  String get refreshSignIn => '刷新登录';

  @override
  String get signIn => '登录';

  @override
  String get authErrorGeneric => '登录暂时未能完成，请稍后再试。';

  @override
  String get authErrorOpenBrowser => '无法打开浏览器，请稍后再试。';

  @override
  String get authErrorTimedOut => '登录等待时间过长，请重新尝试。';

  @override
  String get authErrorSessionExpired => '当前登录状态已过期，请重新登录。';

  @override
  String get authErrorNetwork => '当前网络似乎不可用，请检查后再试。';

  @override
  String get authErrorNotConfigured => '登录功能尚未配置完成，请联系管理员。';

  @override
  String get checkAppUpdateTitle => '检查应用更新（Rosemary）';

  @override
  String checkAppUpdateSubtitle(Object platform) {
    return '$platform';
  }

  @override
  String get platformWeb => '网页';

  @override
  String get platformAndroid => '安卓';

  @override
  String get platformIos => 'iOS';

  @override
  String get platformMacos => 'macOS';

  @override
  String get platformWindows => 'Windows';

  @override
  String get platformLinux => 'Linux';

  @override
  String get platformFuchsia => 'Fuchsia';

  @override
  String get rosemaryUnsupportedPlatform => '当前平台暂不支持 Rosemary 更新。';

  @override
  String get rosemaryNotConfigured => 'Rosemary 未配置，请先在 Admin 中完成配置。';

  @override
  String get rosemaryNoUpdate => '当前已是最新版本。';

  @override
  String rosemaryNoUpdateWithVersion(Object version) {
    return '当前已是最新版本（$version）。';
  }

  @override
  String get rosemaryCheckFailedBrief => '检查更新失败，请稍后重试。';

  @override
  String get rosemaryUpdateAvailableTitle => '发现可用更新';

  @override
  String get rosemaryAppUpdateSectionTitle => '应用更新';

  @override
  String get rosemaryResourceUpdateSectionTitle => '资源更新';

  @override
  String get rosemaryAppUpdateAvailable => '有新的应用版本可用。';

  @override
  String get rosemaryResourceUpdateAvailable => '有新的资源包可用。';

  @override
  String rosemaryNotesLabel(Object notes) {
    return '说明：$notes';
  }

  @override
  String get rosemaryLater => '稍后';

  @override
  String get rosemaryStartUpdate => '开始更新';

  @override
  String get rosemaryPreparingUpdate => '正在准备更新...';

  @override
  String get rosemaryRunningUpdateTitle => '正在执行 Rosemary 更新';

  @override
  String get rosemaryProcessing => '处理中...';

  @override
  String rosemaryProgress(Object progress) {
    return '进度：$progress%';
  }

  @override
  String get rosemaryUpdateFailedCloseAndRetry => '更新失败，请关闭窗口后重试。';

  @override
  String get rosemaryClose => '关闭';

  @override
  String get rosemaryUpdateFailedBrief => '更新失败，请稍后重试。';

  @override
  String get rosemaryUpdateCompleted => '更新流程已完成。';

  @override
  String get rosemaryChecking => '正在检查更新...';

  @override
  String get rosemaryDownloadingApp => '正在下载应用更新...';

  @override
  String get rosemaryInstallingApp => '正在安装应用更新...';

  @override
  String get rosemaryDownloadingResources => '正在下载资源...';

  @override
  String get rosemaryInstallingResources => '正在安装资源...';

  @override
  String get rosemaryDmgOpenedHint => 'DMG 已打开，请挂载后将应用拖入“应用程序”以完成更新。';

  @override
  String get rosemaryMacDmgPromptTitle => '准备安装更新';

  @override
  String get rosemaryMacDmgPromptBody => '接下来将打开 DMG。请将新版本应用拖入“应用程序”覆盖安装。打开后本应用会自动退出，以便你完成替换。';

  @override
  String get rosemaryMacDmgPromptConfirm => '继续并打开 DMG';
}
