import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/chat_message.dart' as db;
import 'settings_service.dart';

part 'ai_service.g.dart';

@riverpod
AiService aiService(Ref ref) {
  final settings = ref.watch(settingsProvider);
  return AiService(settings.apiKey, settings.baseUrl, settings.modelName);
}

class AiService {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  late final openai.OpenAIClient _client;

  AiService(this.apiKey, this.baseUrl, this.modelName) {
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
      if (locale != null && locale.isNotEmpty) {
        finalPrompt += "\nIMPORTANT: Your response MUST be in the same language as the user's system interface. Current system language: $locale. Do not respond in English unless the system language is English.";
      }

      final contentParts = <openai.ContentPart>[
        openai.ContentPart.text(finalPrompt),
      ];
      
      for (final img in base64Images) {
        contentParts.add(openai.ContentPart.imageUrl("data:image/jpeg;base64,$img"));
      }

      final stream = _client.chat.completions.createStream(
        openai.ChatCompletionCreateRequest(
          model: modelName.isNotEmpty ? modelName : "gpt-4o",
          messages: [
            openai.ChatMessage.user(contentParts),
          ],
          maxTokens: 1000,
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
      contentParts.add(openai.ContentPart.imageUrl("data:image/jpeg;base64,$img"));
    }

    messages.add(openai.ChatMessage.user(contentParts));

    try {
      final stream = _client.chat.completions.createStream(
        openai.ChatCompletionCreateRequest(
          model: modelName.isNotEmpty ? modelName : "gpt-4o",
          messages: messages,
          maxTokens: 1000,
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
}
