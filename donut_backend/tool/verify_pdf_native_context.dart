import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const String _defaultPrompt = '请根据文档内容总结当前页重点。';
const int _defaultMaxNativePdfBytes = 8 * 1024 * 1024;
const List<String> _defaultModels = <String>[
  'gemini-3.1-flash-image-preview',
  'claude-haiku-4-5',
  'claude-sonnet-4-0',
];

Future<void> main(List<String> args) async {
  final options = await _Options.parse(args);
  final backendRoot = _backendRootUri(options.baseUrl);
  final apiBase = _normalizeApiBaseUrl(options.baseUrl);

  stdout.writeln('Backend root: $backendRoot');
  stdout.writeln('API base: $apiBase');
  stdout.writeln('PDF path: ${options.pdfPath}');
  stdout.writeln('Usage mode: ${options.usageMode}');
  stdout.writeln('Stream: ${options.stream}');
  stdout.writeln('Max native PDF bytes: ${options.maxNativePdfBytes}');

  final modelsToTest = options.model == null || options.model!.trim().isEmpty
      ? _defaultModels
      : options.model!
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
  stdout.writeln('Models to test: ${modelsToTest.join(', ')}');

  final auth = await _authenticate(backendRoot);
  stdout.writeln('Authenticated as: ${auth.userEmail ?? auth.userSubject}');

  final pdfFile = File(options.pdfPath);
  if (!await pdfFile.exists()) {
    stderr.writeln('PDF 不存在: ${options.pdfPath}');
    exitCode = 2;
    return;
  }
  final singlePagePdfPath = await _extractFirstPagePdf(pdfFile.path);
  final pdfBytes = await File(singlePagePdfPath).readAsBytes();
  final pdfSha256 = sha256.convert(pdfBytes).toString();
  final pdfBase64 = base64Encode(pdfBytes);
  if (!options.allowLargePdf && pdfBytes.length > options.maxNativePdfBytes) {
    stderr.writeln(
      'PDF 太大（${pdfBytes.length} bytes），超过 native 注入阈值 '
      '${options.maxNativePdfBytes} bytes。',
    );
    stderr.writeln(
      '这与 App 当前行为一致：会走异常回退路径，避免上游 599 资源限制。',
    );
    stderr.writeln('如需强行测试整本，请加 --allow-large true');
    exitCode = 2;
    return;
  }

  final requestUri = Uri.parse(apiBase).resolve('responses');
  stdout.writeln('Request URL: $requestUri');
  stdout.writeln('Source PDF bytes: ${await pdfFile.length()}');
  stdout.writeln('Single-page PDF path: $singlePagePdfPath');
  stdout.writeln('Single-page PDF bytes: ${pdfBytes.length}');
  stdout.writeln('PDF sha256: $pdfSha256');

  var apiToken = auth.apiToken;

  var hasFailure = false;
  for (final model in modelsToTest) {
    stdout.writeln('\n========== MODEL: $model ==========');
    final requestBody = _buildOpenAiResponsesRequestBody(
      model: model,
      prompt: options.prompt,
      stream: false,
      docSha256: pdfSha256,
      docBase64: pdfBase64,
      docId: 'manual_verify_doc',
    );

    var modelDone = false;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final response = await http.post(
        requestUri,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $apiToken',
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          HttpHeaders.acceptHeader: ContentType.json.mimeType,
          'X-Donut-Usage-Mode': options.usageMode,
        },
        body: jsonEncode(requestBody),
      );

      final contentType = response.headers[HttpHeaders.contentTypeHeader] ?? '';
      final responseText =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      stdout.writeln('HTTP ${response.statusCode}');
      stdout.writeln('content-type: $contentType');

      if (_shouldRefreshToken(response.statusCode, responseText) &&
          attempt < 2) {
        stdout.writeln('Token 可能过期，刷新后重试...');
        apiToken = await _refreshApiToken(backendRoot, auth.sessionToken);
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        stdout.writeln('失败响应预览:');
        stdout.writeln(_preview(responseText));
        hasFailure = true;
        modelDone = true;
        break;
      }

      final json = _tryParseJson(responseText);
      if (json == null) {
        stdout.writeln('响应不是 JSON，预览如下:');
        stdout.writeln(_preview(responseText));
        hasFailure = true;
        modelDone = true;
        break;
      }
      final text = _extractAssistantText(json);
      stdout.writeln('\n=== Assistant Output ===');
      stdout.writeln(text ?? '<empty>');
      modelDone = true;
      break;
    }
    if (!modelDone) {
      hasFailure = true;
      stdout.writeln('模型测试未完成。');
    }
  }

  if (hasFailure) {
    exitCode = 1;
  }
}

Future<String> _extractFirstPagePdf(String sourcePath) async {
  final tempDir = await Directory.systemTemp.createTemp('donut_pdf_test_');
  final outputPath = '${tempDir.path}/first_page.pdf';
  final run = await _runPythonExtract(sourcePath, outputPath);
  if (run.exitCode == 0) {
    return outputPath;
  }

  if (run.exitCode == 3) {
    stdout.writeln('Python 缺少 pypdf，正在安装...');
    final install = await Process.run(
      'python3',
      ['-m', 'pip', 'install', '--user', 'pypdf'],
    );
    if (install.exitCode != 0) {
      throw Exception(
        '安装 pypdf 失败: ${install.stderr}\n'
        '你也可以手动执行: python3 -m pip install --user pypdf',
      );
    }
    final retry = await _runPythonExtract(sourcePath, outputPath);
    if (retry.exitCode == 0) {
      return outputPath;
    }
    throw Exception('提取第一页失败: ${retry.stderr}');
  }

  throw Exception('提取第一页失败: ${run.stderr}');
}

Future<ProcessResult> _runPythonExtract(String sourcePath, String outputPath) {
  final script = '''
import sys
source = sys.argv[1]
target = sys.argv[2]
try:
    from pypdf import PdfReader, PdfWriter
except Exception:
    sys.exit(3)
reader = PdfReader(source)
if len(reader.pages) < 1:
    raise RuntimeError("pdf has no pages")
writer = PdfWriter()
writer.add_page(reader.pages[0])
with open(target, "wb") as f:
    writer.write(f)
''';
  return Process.run(
    'python3',
    ['-c', script, sourcePath, outputPath],
  );
}

Map<String, dynamic> _buildOpenAiResponsesRequestBody({
  required String model,
  required String prompt,
  required bool stream,
  required String docSha256,
  required String docBase64,
  required String docId,
}) {
  final stablePrefix = {
    'system_prompt_version': 'pdf_native_v1',
    'tool_schema_version': 'donut_pdf_ctx_v1',
    'document_meta': {
      'doc_id': docId,
      'doc_sha256': docSha256,
    },
    'stable_evidence_ids': <String>[],
    'stable_evidence_refs': <Object>[],
    'pseudo_kb_mode': false,
  };
  final stablePrefixCanonical = _canonicalJson(stablePrefix);
  final stablePrefixHash =
      sha256.convert(utf8.encode(stablePrefixCanonical)).toString();

  final volatileSuffix = {
    'latest_user_query': prompt,
    'pool_delta': {
      'added_evidence_ids': <String>[],
      'removed_evidence_ids': <String>[],
    },
    'read_log_delta': {
      'read_evidence_ids': <String>[],
    },
    'turn_state': {
      'focus_pages': <int>[1],
    },
  };

  final promptText = '[DONUT_STABLE_PREFIX_HASH]\n$stablePrefixHash\n\n'
      '[DONUT_STABLE_PREFIX_JSON]\n$stablePrefixCanonical\n\n'
      '[DONUT_VOLATILE_SUFFIX_JSON]\n${_canonicalJson(volatileSuffix)}\n\n'
      '[USER_QUERY]\n$prompt';

  return {
    'model': model,
    'stream': stream,
    'temperature': 0.2,
    'input': <Object>[
      {
        'role': 'user',
        'content': <Object>[
          {
            'type': 'input_text',
            'text': promptText,
          },
          {
            'type': 'input_file',
            'filename': '$docId.pdf',
            'file_data': 'data:application/pdf;base64,$docBase64',
          },
        ],
      },
    ],
    'instructions': 'You are a helpful AI assistant for a PDF reader.',
    'max_output_tokens': 512,
  };
}

Future<_AuthResult> _authenticate(Uri backendRoot) async {
  final startResponse =
      await http.post(backendRoot.resolve('auth/login/start'));
  if (startResponse.statusCode != 200) {
    throw Exception(
      'Failed to start login: ${startResponse.statusCode} ${startResponse.body}',
    );
  }

  final startBody = _asJsonMap(jsonDecode(startResponse.body));
  final authorizationUrl = startBody['authorizationUrl']?.toString() ?? '';
  final pollToken = startBody['pollToken']?.toString() ?? '';
  if (authorizationUrl.isEmpty || pollToken.isEmpty) {
    throw Exception('Login start response was missing authorization data.');
  }

  stdout.writeln('\nOpen URL and finish sign-in:');
  stdout.writeln(authorizationUrl);
  stdout.writeln('');
  await _tryOpenBrowser(authorizationUrl);

  while (true) {
    final pollResponse = await http.get(
      backendRoot.resolve('auth/login/poll/$pollToken'),
    );
    final body = _asJsonMap(jsonDecode(pollResponse.body));
    final status = body['status']?.toString() ?? '';

    if (pollResponse.statusCode == 200 && status == 'pending') {
      stdout.writeln('Waiting for sign-in completion...');
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }

    if (pollResponse.statusCode == 200 && status == 'complete') {
      final sessionToken = body['sessionToken']?.toString() ?? '';
      final apiToken = body['apiToken']?.toString() ?? '';
      final user = _asJsonMap(body['user']);
      if (sessionToken.isEmpty) {
        throw Exception('Login completed without a session token.');
      }
      final resolvedApiToken = apiToken.isNotEmpty
          ? apiToken
          : await _refreshApiToken(backendRoot, sessionToken);
      return _AuthResult(
        sessionToken: sessionToken,
        apiToken: resolvedApiToken,
        userEmail: user['email']?.toString(),
        userSubject: user['sub']?.toString() ?? '',
      );
    }

    throw Exception(
      'Login failed: ${pollResponse.statusCode} ${pollResponse.body}',
    );
  }
}

Future<String> _refreshApiToken(Uri backendRoot, String sessionToken) async {
  final response = await http.get(
    backendRoot.resolve('auth/session'),
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer $sessionToken',
    },
  );
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to refresh API token: ${response.statusCode} ${response.body}',
    );
  }
  final body = _asJsonMap(jsonDecode(response.body));
  final apiToken = body['apiToken']?.toString() ?? '';
  if (apiToken.isEmpty) {
    throw Exception('Session response did not include apiToken.');
  }
  return apiToken;
}

bool _shouldRefreshToken(int statusCode, String body) {
  if (statusCode != 401) return false;
  final code = _extractErrorCode(body);
  return code == 'token_refresh_required' ||
      code == 'invalid_or_expired_api_token' ||
      code == 'auth_session_expired';
}

String? _extractErrorCode(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    final map = _asJsonMap(decoded);
    final error = map['error'];
    if (error is Map) {
      return error['code']?.toString();
    }
  } catch (_) {
    return null;
  }
  return null;
}

List<String> _parseSse(String body) {
  final results = <String>[];
  final lines = const LineSplitter().convert(body);
  final dataLines = <String>[];

  void flushEvent() {
    if (dataLines.isEmpty) return;
    final payload = dataLines.join('\n').trim();
    dataLines.clear();
    if (payload.isEmpty || payload == '[DONE]') return;
    final parsed = _tryParseJson(payload);
    if (parsed == null) return;
    final text = _extractAssistantText(parsed);
    if (text != null && text.isNotEmpty) {
      results.add(text);
    }
  }

  for (final line in lines) {
    if (line.isEmpty) {
      flushEvent();
      continue;
    }
    if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trimLeft());
    }
  }
  flushEvent();
  return results;
}

Map<String, dynamic>? _tryParseJson(String body) {
  try {
    final decoded = jsonDecode(body);
    return _asJsonMap(decoded);
  } catch (_) {
    return null;
  }
}

String? _extractAssistantText(Map<String, dynamic> body) {
  final outputText = body['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText;
  }

  final output = body['output'];
  if (output is List) {
    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map) continue;
        final type = block['type']?.toString();
        if (type == 'output_text') {
          final text = block['text']?.toString();
          if (text != null && text.isNotEmpty) buffer.write(text);
        }
      }
    }
    final merged = buffer.toString();
    if (merged.isNotEmpty) return merged;
  }

  final choices = body['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  if (first is! Map) return null;
  final choice = _asJsonMap(first);
  final message = choice['message'];
  if (message is Map) {
    final content = _asJsonMap(message)['content'];
    return _contentToText(content);
  }
  final delta = choice['delta'];
  if (delta is Map) {
    final content = _asJsonMap(delta)['content'];
    return _contentToText(content);
  }
  return null;
}

String? _contentToText(dynamic content) {
  if (content is String) return content;
  if (content is List) {
    final buffer = StringBuffer();
    for (final item in content) {
      if (item is Map) {
        final text = item['text']?.toString();
        if (text != null && text.isNotEmpty) {
          buffer.write(text);
        }
      } else if (item != null) {
        buffer.write(item.toString());
      }
    }
    final value = buffer.toString();
    return value.isEmpty ? null : value;
  }
  return content?.toString();
}

String _preview(String body, {int maxLength = 1200}) {
  if (body.length <= maxLength) return body;
  return '${body.substring(0, maxLength)}\n...[truncated ${body.length - maxLength} chars]';
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

Future<void> _tryOpenBrowser(String url) async {
  final candidates = <List<String>>[];
  if (Platform.isMacOS) {
    candidates.add(<String>['open', url]);
  } else if (Platform.isLinux) {
    candidates.add(<String>['xdg-open', url]);
  } else if (Platform.isWindows) {
    candidates.add(<String>['cmd', '/c', 'start', url]);
  }

  for (final command in candidates) {
    try {
      await Process.start(command.first, command.sublist(1));
      stdout.writeln('Browser launch requested automatically.');
      return;
    } catch (_) {
      // fallback to manual open
    }
  }
}

Uri _backendRootUri(String baseUrl) {
  final uri = Uri.parse(baseUrl);
  var normalizedPath = uri.path;
  if (normalizedPath.endsWith('/')) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
  }
  if (normalizedPath == '/v1') {
    normalizedPath = '/';
  } else if (normalizedPath.endsWith('/v1')) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 3);
    if (normalizedPath.isEmpty) {
      normalizedPath = '/';
    }
  }
  return uri.replace(
    path: normalizedPath.isEmpty ? '/' : normalizedPath,
    query: null,
    fragment: null,
  );
}

String _normalizeApiBaseUrl(String baseUrl) {
  final uri = Uri.parse(baseUrl.trim());
  var normalizedPath = uri.path.trim();
  if (normalizedPath.isEmpty || normalizedPath == '/') {
    normalizedPath = '/v1/';
  } else if (normalizedPath == '/v1') {
    normalizedPath = '/v1/';
  } else if (!normalizedPath.endsWith('/')) {
    normalizedPath = '$normalizedPath/';
  }

  return uri
      .replace(
        path: normalizedPath,
        query: null,
        fragment: null,
      )
      .toString();
}

String _canonicalJson(Map<String, Object?> input) {
  final keys = input.keys.toList()..sort();
  final sorted = <String, Object?>{};
  for (final key in keys) {
    final value = input[key];
    if (value is Map<String, Object?>) {
      sorted[key] = jsonDecode(_canonicalJson(value)) as Object;
    } else {
      sorted[key] = value;
    }
  }
  return jsonEncode(sorted);
}

class _Options {
  const _Options({
    required this.baseUrl,
    required this.pdfPath,
    required this.prompt,
    required this.usageMode,
    required this.stream,
    required this.maxNativePdfBytes,
    required this.allowLargePdf,
    this.model,
  });

  final String baseUrl;
  final String pdfPath;
  final String prompt;
  final String usageMode;
  final bool stream;
  final int maxNativePdfBytes;
  final bool allowLargePdf;
  final String? model;

  static Future<_Options> parse(List<String> args) async {
    String? baseUrl;
    String? pdfPath;
    var prompt = _defaultPrompt;
    var usageMode = 'summary';
    var stream = true;
    var maxNativePdfBytes = _defaultMaxNativePdfBytes;
    var allowLargePdf = false;
    String? model;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--base-url' && i + 1 < args.length) {
        baseUrl = args[++i];
      } else if (arg == '--pdf' && i + 1 < args.length) {
        pdfPath = args[++i];
      } else if (arg == '--prompt' && i + 1 < args.length) {
        prompt = args[++i];
      } else if (arg == '--usage-mode' && i + 1 < args.length) {
        usageMode = args[++i].trim().toLowerCase();
      } else if (arg == '--stream' && i + 1 < args.length) {
        final v = args[++i].trim().toLowerCase();
        stream = v == '1' || v == 'true' || v == 'yes';
      } else if (arg == '--model' && i + 1 < args.length) {
        model = args[++i];
      } else if (arg == '--max-native-pdf-bytes' && i + 1 < args.length) {
        final parsed = int.tryParse(args[++i].trim());
        if (parsed != null && parsed > 0) {
          maxNativePdfBytes = parsed;
        }
      } else if (arg == '--allow-large' && i + 1 < args.length) {
        final v = args[++i].trim().toLowerCase();
        allowLargePdf = v == '1' || v == 'true' || v == 'yes';
      }
    }

    final resolvedBaseUrl = (baseUrl == null || baseUrl.trim().isEmpty)
        ? await _promptBaseUrl()
        : baseUrl.trim();
    final resolvedPdfPath = (pdfPath == null || pdfPath.trim().isEmpty)
        ? await _promptPdfPath()
        : pdfPath.trim();

    return _Options(
      baseUrl: _normalizeApiBaseUrl(resolvedBaseUrl),
      pdfPath: resolvedPdfPath,
      prompt: prompt,
      usageMode: usageMode.isEmpty ? 'summary' : usageMode,
      stream: stream,
      maxNativePdfBytes: maxNativePdfBytes,
      allowLargePdf: allowLargePdf,
      model: model,
    );
  }

  static Future<String> _promptBaseUrl() async {
    const fallback = String.fromEnvironment(
      'DONUT_API_BASE_URL',
      defaultValue: 'https://apidonut.cruty.cn/v1',
    );
    stdout.write('API Base URL [$fallback]: ');
    final line = stdin.readLineSync();
    final value = line?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static Future<String> _promptPdfPath() async {
    while (true) {
      stdout.write('PDF path: ');
      final line = stdin.readLineSync()?.trim() ?? '';
      if (line.isEmpty) {
        stderr.writeln('PDF path is required.');
        continue;
      }
      final file = File(line);
      if (!file.existsSync()) {
        stderr.writeln('File does not exist: $line');
        continue;
      }
      return line;
    }
  }
}

class _AuthResult {
  const _AuthResult({
    required this.sessionToken,
    required this.apiToken,
    required this.userSubject,
    this.userEmail,
  });

  final String sessionToken;
  final String apiToken;
  final String userSubject;
  final String? userEmail;
}
