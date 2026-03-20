import 'package:flutter/widgets.dart';

String termsOfServiceText(Locale locale) {
  if (locale.languageCode == 'zh') {
    return '''
《Donut 服务条款》

更新日期：2026年3月19日
生效日期：2026年3月19日

欢迎使用 Donut。请在使用前仔细阅读本条款。您勾选同意并点击确认，即表示您与 Donut 运营方就本服务达成具有法律约束力的协议。

一、服务内容
1. Donut 提供 PDF 阅读、文档分析、AI 对话、设置管理、配置备份与导入导出等功能。
2. AI 功能通过您配置的第三方模型服务提供商完成请求与返回，您应自行确保所使用模型服务的合法性与可用性。

二、账号与密钥安全
1. 您可在本地配置 API Key、模型名称与服务地址。
2. 您应妥善保管自己的 API Key，不得以任何方式向第三方泄露。
3. 因 API Key 泄露、误配或被滥用造成的损失，由您自行承担。

三、用户内容与使用规范
1. 您上传、导入、阅读、输入、导出的内容均由您自行负责，您应保证拥有合法权利并不侵犯他人权益。
2. 您不得利用 Donut 从事违法违规活动，包括但不限于侵犯知识产权、传播违法信息、破坏网络安全等。
3. 您不得恶意干扰服务运行或绕过合理技术限制。

四、知识产权
1. Donut 软件及其相关界面、标识、文档等知识产权归权利人所有。
2. 在不违反本条款前提下，您获得非独占、不可转让、可撤销的使用许可。

五、第三方服务
1. Donut 可能依赖第三方 SDK、开源组件及模型服务接口。
2. 对于第三方服务的可用性、准确性、安全性或合规性，Donut 不作额外保证。
3. 因第三方服务中断、限流、封禁、计费变化导致的影响，Donut 不承担责任。

六、免责声明
1. Donut 及 AI 生成内容仅供参考，不构成法律、医疗、金融或其他专业建议。
2. 您应自行判断并承担使用 AI 结果所产生的风险与后果。
3. 在法律允许范围内，Donut 对间接损失、附带损失、利润损失不承担责任。

七、服务变更、中止与终止
1. Donut 有权基于维护、升级、合规要求对功能进行调整。
2. 若您违反本条款，Donut 有权限制或终止您继续使用相关功能。

八、法律适用与争议解决
1. 本条款的订立、执行与解释适用中华人民共和国法律。
2. 因本条款引发的争议，双方应优先协商；协商不成的，提交有管辖权的人民法院处理。

九、条款更新
1. Donut 有权不定期更新本条款。
2. 更新后，您继续使用即视为接受更新后的条款。
''';
  }

  return '''
Donut Terms of Service

Last Updated: March 19, 2026
Effective Date: March 19, 2026

Welcome to Donut. Please read these Terms carefully before using the app. By checking the consent box and confirming, you enter into a legally binding agreement with the Donut operator.

1. Service Scope
1) Donut provides PDF reading, document analysis, AI chat, settings management, and settings backup/import/export.
2) AI responses are generated through third-party model providers configured by you. You are responsible for lawful and proper use of those providers.

2. API Credentials
1) You may configure your API key, model name, and service endpoint locally.
2) You are responsible for keeping your API key secure.
3) Any loss caused by credential leakage or misuse is your responsibility.

3. User Content and Conduct
1) You are responsible for all files and content you import, process, or export.
2) You must have lawful rights to the content and must not infringe others' rights.
3) You must not use Donut for unlawful activities or to disrupt service operations.

4. Intellectual Property
1) Donut software, UI, marks, and related materials are owned by their rights holders.
2) You receive a limited, non-exclusive, non-transferable, revocable license to use the app under these Terms.

5. Third-Party Services
1) Donut may rely on third-party SDKs, open-source components, and model APIs.
2) Donut does not guarantee availability, accuracy, security, or compliance of third-party services.
3) Donut is not liable for impacts caused by third-party outages, rate limits, policy changes, or billing changes.

6. Disclaimer and Limitation
1) Donut and AI-generated outputs are for informational purposes only and do not constitute legal, medical, financial, or other professional advice.
2) You are solely responsible for evaluating and using generated outputs.
3) To the extent permitted by law, Donut is not liable for indirect, incidental, special, or consequential damages.

7. Changes and Termination
1) Donut may modify features for maintenance, upgrades, or compliance.
2) Donut may suspend or terminate access if you violate these Terms.

8. Governing Law and Disputes
1) These Terms are governed by the laws of the People's Republic of China.
2) Disputes should be resolved through good-faith negotiation first; failing that, disputes shall be submitted to a court with competent jurisdiction.

9. Updates
1) Donut may update these Terms from time to time.
2) Continued use after updates constitutes acceptance of the updated Terms.
''';
}

String privacyPolicyText(Locale locale) {
  if (locale.languageCode == 'zh') {
    return '''
《Donut 用户隐私协议》

更新日期：2026年3月19日
生效日期：2026年3月19日

本协议说明 Donut 如何处理您的个人信息与数据。请您在使用前仔细阅读。

一、我们处理的数据类型
1. 本地设置数据：如 API Key、模型名称、服务地址、阅读偏好、摘要配置等。
2. 文档与交互数据：您在应用内选择的 PDF 文件、页面摘要、聊天记录、统计数据等（主要保存在本地）。
3. 配置备份文件：您导出或应用自动生成的设置 JSON 文件。

二、数据存储与处理方式
1. Donut 以本地优先方式运行，设置和阅读相关数据默认保存在您的设备上。
2. 为便于恢复，应用会在本地目录中维护设置 JSON 备份文件。
3. 当本地设置为空时，应用会尝试读取该备份以恢复可配置项。

三、第三方模型服务与数据传输
1. 当您使用 AI 分析/对话功能时，相关页面内容、提示词和必要上下文会发送至您配置的模型服务地址。
2. 第三方服务对数据的处理遵循其自身隐私政策与服务条款，不受 Donut 直接控制。
3. 您应自行评估并承担使用第三方服务的合规与风险责任。

四、我们如何使用数据
1. 提供并改进应用核心功能（阅读、分析、对话、统计、个性化设置）。
2. 保障功能稳定性与故障排查（仅限本地必要范围）。
3. 响应您的主动操作（导入/导出配置、查看条款与隐私政策等）。

五、数据共享与披露
1. 我们不会在未经授权的情况下将您的本地数据主动出售给第三方。
2. 仅在以下场景可能发生共享：
  a) 您主动配置并使用第三方模型服务；
  b) 法律法规或司法机关依法要求。

六、您的权利
1. 您可随时修改或删除应用内设置、聊天与摘要等本地数据。
2. 您可导出配置文件，也可导入配置文件进行恢复。
3. 您可在设置中随时重新查看本隐私协议与服务条款。

七、数据安全
1. 我们采取合理措施保护本地存储数据，但无法保证任何系统绝对安全。
2. 请您妥善保管设备、账号与 API Key，避免敏感信息泄露。

八、未成年人保护
若您为未成年人，应在监护人指导下阅读并同意本协议后使用 Donut。

九、协议更新
我们可能根据产品变化或法律要求更新本协议。更新后您继续使用即视为同意更新内容。
''';
  }

  return '''
Donut Privacy Policy

Last Updated: March 19, 2026
Effective Date: March 19, 2026

This Policy explains how Donut handles your data.

1. Data We Process
1) Local settings data: API key, model name, endpoint, reading preferences, summary profile settings, etc.
2) Document and interaction data: selected PDF files, summaries, chat history, and reading statistics (primarily stored locally).
3) Settings backup files: JSON files generated or exported for backup/import.

2. Storage and Processing
1) Donut is local-first; settings and reading data are stored on your device by default.
2) The app keeps a local JSON backup file for settings recovery.
3) If local settings are empty, Donut may try to restore from that backup file.

3. Third-Party Model Services
1) When AI analysis/chat is used, relevant page content, prompts, and necessary context are sent to the model service endpoint configured by you.
2) Third-party providers process data under their own privacy policies and terms.
3) You are responsible for compliance and risk assessment when using third-party providers.

4. Purpose of Processing
1) Deliver and improve core features (reading, analysis, chat, statistics, personalization).
2) Maintain app stability and troubleshoot issues in a local-necessary scope.
3) Execute your direct actions (import/export settings, viewing legal documents, etc.).

5. Sharing and Disclosure
1) We do not proactively sell your local data.
2) Data may be shared only when:
  a) You choose and use third-party model services.
  b) Required by applicable law or lawful requests from authorities.

6. Your Rights
1) You may edit or delete local settings, chat records, and summaries at any time.
2) You may export and import settings JSON files.
3) You may re-open this Privacy Policy and the Terms in Settings at any time.

7. Security
1) We use reasonable measures to protect local data, but no system is absolutely secure.
2) Please keep your device and API credentials secure.

8. Minors
If you are a minor, use Donut under guidance of your legal guardian.

9. Policy Updates
We may update this Policy based on product or legal changes. Continued use after updates indicates acceptance of the updated Policy.
''';
}
