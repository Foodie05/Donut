import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/chat_message.dart' as db;
import 'settings_service.dart';

part 'ai_service.g.dart';

@riverpod
AiService aiService(Ref ref) {
  final settings = ref.watch(settingsProvider);
  return AiService(
    settings.apiKey,
    settings.baseUrl,
    settings.modelName,
    settings.modelReplyLength,
  );
}

class AiService {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final ModelReplyLength modelReplyLength;
  late final openai.OpenAIClient _client;

  AiService(this.apiKey, this.baseUrl, this.modelName, this.modelReplyLength) {
    if (apiKey.isNotEmpty) {
      _client = openai.OpenAIClient(
        config: openai.OpenAIConfig(
          authProvider: openai.ApiKeyProvider(apiKey),
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1',
        ),
      );
    }
  }

  Stream<String> analyzeImageStream(List<String> base64Images, String prompt, {String? locale}) async* {
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    try {
      String finalPrompt = prompt;
      if (_looksLikeTranslationTask(prompt)) {
        finalPrompt = '${_strictTranslationInstruction()}\n\n$prompt';
      }
      if (locale != null && locale.isNotEmpty) {
        finalPrompt += "\nIMPORTANT: Your response MUST be in the same language as the user's system interface. Current system language: $locale. Do not respond in English unless the system language is English.";
      }

      final contentParts = <openai.ContentPart>[
        openai.ContentPart.text(finalPrompt),
      ];
      
      for (final img in base64Images) {
        contentParts.add(
          openai.ContentPart.imageUrl(
            "data:image/jpeg;base64,$img",
            detail: openai.ImageDetail.high,
          ),
        );
      }

      final stream = _client.chat.completions.createStream(
        openai.ChatCompletionCreateRequest(
          model: modelName.isNotEmpty ? modelName : "gpt-4o",
          messages: [
            openai.ChatMessage.user(contentParts),
          ],
          maxTokens: modelReplyLength.maxTokens,
          temperature: 0.2,
        ),
      );

      await for (final res in stream) {
        final content = res.choices?.first.delta.content;
        if (content != null) {
          yield content;
        }
      }
    } catch (e) {
      throw Exception('AI Request Failed: $e');
    }
  }

  Stream<String> chatWithPage({
    required String prompt,
    required List<String> base64Images,
    String? summary,
    List<db.ChatMessage> history = const [],
    String? locale,
  }) async* {
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    String systemPrompt = "You are a helpful AI assistant in a PDF Reader application. "
        "You have access to the current page image(s) and its summary. "
        "If multiple images are provided, they represent the previous pages for context (n-2, n-1, n). "
        "Answer the user's questions based on this context.";
    
    if (locale != null && locale.isNotEmpty) {
      systemPrompt += " IMPORTANT: Your response MUST be in the same language as the user's system interface. Current system language: $locale. Do not respond in English unless the system language is English.";
    }

    final messages = <openai.ChatMessage>[
      openai.ChatMessage.system(systemPrompt),
    ];

    // Add History
    for (final msg in history) {
      if (msg.isUser) {
        messages.add(openai.ChatMessage.user(msg.text));
      } else {
        messages.add(openai.ChatMessage.assistant(content: msg.text));
      }
    }

    // Add Current Context (Image + Summary + New Prompt)
    final contentParts = <openai.ContentPart>[
      openai.ContentPart.text(prompt),
    ];
    
    if (summary != null && summary.isNotEmpty) {
      contentParts.insert(0, openai.ContentPart.text("Page Summary: $summary\n\n"));
    }
    
    for (final img in base64Images) {
      contentParts.add(
        openai.ContentPart.imageUrl(
          "data:image/jpeg;base64,$img",
          detail: openai.ImageDetail.high,
        ),
      );
    }

    messages.add(openai.ChatMessage.user(contentParts));

    try {
      final stream = _client.chat.completions.createStream(
        openai.ChatCompletionCreateRequest(
          model: modelName.isNotEmpty ? modelName : "gpt-4o",
          messages: messages,
          maxTokens: modelReplyLength.maxTokens,
          temperature: 0.3,
        ),
      );

      await for (final res in stream) {
        final content = res.choices?.first.delta.content;
        if (content != null) {
          yield content;
        }
      }
    } catch (e) {
      throw Exception('AI Request Failed: $e');
    }
  }

  bool _looksLikeTranslationTask(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('translate') ||
        lower.contains('translation') ||
        lower.contains('verbatim') ||
        lower.contains('一字不落') ||
        lower.contains('原封不动') ||
        lower.contains('逐字') ||
        lower.contains('翻译');
  }

  String _strictTranslationInstruction() {
    return '''
你是“逐字完整翻译器”。你的唯一任务是把输入页面内容完整翻译为简体中文。

必须遵守：
1) 不得省略、跳过、合并、总结、改写任何信息。
2) 必须保持原文顺序；标题、段落、列表、脚注、编号、标点、数字、单位、日期、公式、代码、URL、邮箱、专有名词都必须保留。
3) 每一行或每一项都必须在译文中有对应内容，不得少项。
4) 对于无法辨认的字符或片段，在对应位置标注「[无法辨认]」，不得直接跳过。
5) 只输出译文本体，不要输出解释或额外说明。

在输出前先进行完整性检查，确认没有遗漏任何可见文本。
''';
  }
}
