import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../objectbox.g.dart';
import '../../providers.dart';
import '../../services/dpdf_service.dart';
import '../models/book.dart';
import '../models/chat_message.dart';
import '../models/page_data.dart';

part 'page_repository.g.dart';

@riverpod
PageRepository pageRepository(Ref ref) {
  return PageRepository(ref.watch(storeProvider));
}

final watchPageDataProvider = StreamProvider.autoDispose
    .family<PageData?, ({int bookId, int pageIndex, String profileId})>((ref, args) {
  return ref
      .watch(pageRepositoryProvider)
      .watchPageData(args.bookId, args.pageIndex, args.profileId);
});

final watchMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, int>((ref, pageDataId) {
  return ref.watch(pageRepositoryProvider).watchMessages(pageDataId);
});

class _ProfileAiData {
  String summary;
  final List<ChatMessage> messages;

  _ProfileAiData({
    required this.summary,
    required this.messages,
  });
}

class _BookAiState {
  final Map<String, _ProfileAiData> profilesByKey = {};
  final Map<int, ({int pageIndex, String profileId})> pageKeyById = {};
  final Map<int, ({int pageDataId, int index})> messageKeyById = {};
  final Map<int, StreamController<PageData?>> pageControllers = {};
  final Map<int, StreamController<List<ChatMessage>>> messageControllers = {};
  int nextMessageId = 1;
  Timer? persistTimer;
}

class PageRepository {
  final Store _store;
  late final Box<Book> _bookBox;

  final Map<int, _BookAiState> _states = {};
  final Map<int, int> _bookIdByPageDataId = {};
  final Map<int, int> _bookIdByMessageId = {};

  PageRepository(this._store) {
    _bookBox = _store.box<Book>();
  }

  String _profileKey(int pageIndex, String profileId) => '$pageIndex|$profileId';

  int _stableIntId(String input) {
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  int _pageDataId(int bookId, int pageIndex, String profileId) {
    return _stableIntId('$bookId|$pageIndex|$profileId');
  }

  Book? _bookById(int bookId) => _bookBox.get(bookId);

  _BookAiState _ensureStateLoaded(int bookId) {
    if (_states.containsKey(bookId)) return _states[bookId]!;

    final state = _BookAiState();
    final book = _bookById(bookId);
    if (book != null &&
        isDpdfPath(book.filePath) &&
        File(book.filePath).existsSync()) {
      try {
        final bytes = File(book.filePath).readAsBytesSync();
        final doc = readDpdfFromBytes(bytes);
        final aiData = doc.aiData;

        final nextId = aiData['nextMessageId'];
        if (nextId is num && nextId.toInt() > 0) {
          state.nextMessageId = nextId.toInt();
        }

        final pages = aiData['pages'];
        if (pages is List) {
          for (final pageItem in pages) {
            if (pageItem is! Map) continue;
            final page = Map<String, dynamic>.from(pageItem);
            final pageIndex = (page['pageIndex'] as num?)?.toInt();
            if (pageIndex == null || pageIndex <= 0) continue;

            final profiles = page['profiles'];
            if (profiles is! Map) continue;

            for (final entry in profiles.entries) {
              final profileId = entry.key.toString();
              final profileDataRaw = entry.value;
              if (profileDataRaw is! Map) continue;
              final profileData = Map<String, dynamic>.from(profileDataRaw);
              final summary = (profileData['summary'] as String?) ?? '';

              final messages = <ChatMessage>[];
              final jsonMessages = profileData['messages'];
              if (jsonMessages is List) {
                for (final msgRaw in jsonMessages) {
                  if (msgRaw is! Map) continue;
                  final msg = Map<String, dynamic>.from(msgRaw);
                  final text = (msg['text'] as String?) ?? '';
                  final isUser = (msg['isUser'] as bool?) ?? false;
                  final timestamp = DateTime.tryParse(
                        (msg['timestamp'] as String?) ?? '',
                      ) ??
                      DateTime.now();

                  final message = ChatMessage(
                    text: text,
                    isUser: isUser,
                    timestamp: timestamp,
                  );
                  final id = (msg['id'] as num?)?.toInt() ?? state.nextMessageId++;
                  if (id >= state.nextMessageId) {
                    state.nextMessageId = id + 1;
                  }
                  message.id = id;
                  messages.add(message);
                }
              }

              final key = _profileKey(pageIndex, profileId);
              state.profilesByKey[key] = _ProfileAiData(
                summary: summary,
                messages: messages,
              );

              final pageDataId = _pageDataId(bookId, pageIndex, profileId);
              state.pageKeyById[pageDataId] =
                  (pageIndex: pageIndex, profileId: profileId);
              _bookIdByPageDataId[pageDataId] = bookId;

              for (var i = 0; i < messages.length; i++) {
                final msgId = messages[i].id;
                if (msgId > 0) {
                  state.messageKeyById[msgId] = (pageDataId: pageDataId, index: i);
                  _bookIdByMessageId[msgId] = bookId;
                }
              }
            }
          }
        }
      } catch (_) {
        // Ignore malformed AI payload. The app can still continue with empty data.
      }
    }

    _states[bookId] = state;
    return state;
  }

  PageData? _buildPageData(
    int bookId,
    int pageIndex,
    String profileId,
  ) {
    final state = _ensureStateLoaded(bookId);
    final key = _profileKey(pageIndex, profileId);
    final profile = state.profilesByKey[key];
    if (profile == null) return null;

    final page = PageData(
      pageIndex: pageIndex,
      profileId: profileId,
      summary: profile.summary,
    );
    page.id = _pageDataId(bookId, pageIndex, profileId);
    page.book.targetId = bookId;
    state.pageKeyById[page.id] = (pageIndex: pageIndex, profileId: profileId);
    _bookIdByPageDataId[page.id] = bookId;
    return page;
  }

  List<ChatMessage> _messagesForPageDataId(int pageDataId) {
    final bookId = _bookIdByPageDataId[pageDataId];
    if (bookId == null) return const [];
    final state = _ensureStateLoaded(bookId);
    final keyInfo = state.pageKeyById[pageDataId];
    if (keyInfo == null) return const [];
    final profile = state.profilesByKey[_profileKey(keyInfo.pageIndex, keyInfo.profileId)];
    if (profile == null) return const [];

    return profile.messages.map((item) {
      final copy = ChatMessage(
        text: item.text,
        isUser: item.isUser,
        timestamp: item.timestamp,
      );
      copy.id = item.id;
      return copy;
    }).toList();
  }

  void _emitPageData(int bookId, int pageIndex, String profileId) {
    final state = _ensureStateLoaded(bookId);
    final pageDataId = _pageDataId(bookId, pageIndex, profileId);
    final controller = state.pageControllers[pageDataId];
    if (controller == null || controller.isClosed) return;
    controller.add(_buildPageData(bookId, pageIndex, profileId));
  }

  void _emitMessages(int pageDataId) {
    final bookId = _bookIdByPageDataId[pageDataId];
    if (bookId == null) return;
    final state = _ensureStateLoaded(bookId);
    final controller = state.messageControllers[pageDataId];
    if (controller == null || controller.isClosed) return;
    controller.add(_messagesForPageDataId(pageDataId));
  }

  Map<String, dynamic> _stateToAiData(_BookAiState state) {
    final pages = <int, Map<String, dynamic>>{};
    for (final entry in state.profilesByKey.entries) {
      final split = entry.key.split('|');
      if (split.length < 2) continue;
      final pageIndex = int.tryParse(split.first);
      if (pageIndex == null) continue;
      final profileId = split.sublist(1).join('|');
      final profile = entry.value;

      final page = pages.putIfAbsent(pageIndex, () {
        return {
          'pageIndex': pageIndex,
          'profiles': <String, dynamic>{},
        };
      });
      final profiles = page['profiles'] as Map<String, dynamic>;
      profiles[profileId] = {
        'summary': profile.summary,
        'messages': profile.messages
            .map((msg) => {
                  'id': msg.id,
                  'text': msg.text,
                  'isUser': msg.isUser,
                  'timestamp': msg.timestamp.toUtc().toIso8601String(),
                })
            .toList(),
      };
    }

    final sortedPages = pages.values.toList()
      ..sort((a, b) => (a['pageIndex'] as int).compareTo(b['pageIndex'] as int));

    return {
      'schemaVersion': 1,
      'nextMessageId': state.nextMessageId,
      'pages': sortedPages,
    };
  }

  void _schedulePersist(int bookId) {
    final state = _ensureStateLoaded(bookId);
    state.persistTimer?.cancel();
    state.persistTimer = Timer(const Duration(milliseconds: 600), () async {
      final book = _bookById(bookId);
      if (book == null || !isDpdfPath(book.filePath)) return;
      try {
        await updateDpdfAiData(book.filePath, _stateToAiData(state));
      } catch (_) {
        // Avoid crashing UI on persistence failures.
      }
    });
  }

  PageData? getPageData(int bookId, int pageIndex, String profileId) {
    return _buildPageData(bookId, pageIndex, profileId);
  }

  Stream<PageData?> watchPageData(int bookId, int pageIndex, String profileId) {
    final state = _ensureStateLoaded(bookId);
    final pageDataId = _pageDataId(bookId, pageIndex, profileId);
    _bookIdByPageDataId[pageDataId] = bookId;
    state.pageKeyById[pageDataId] = (pageIndex: pageIndex, profileId: profileId);

    final controller = state.pageControllers.putIfAbsent(
      pageDataId,
      () => StreamController<PageData?>.broadcast(),
    );

    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(_buildPageData(bookId, pageIndex, profileId));
      }
    });
    return controller.stream;
  }

  int savePageSummary(
    int bookId,
    int pageIndex,
    String profileId,
    String summary,
    String? screenshotPath,
  ) {
    final state = _ensureStateLoaded(bookId);
    final key = _profileKey(pageIndex, profileId);
    final profile = state.profilesByKey.putIfAbsent(
      key,
      () => _ProfileAiData(summary: '', messages: []),
    );
    profile.summary = summary;

    final pageDataId = _pageDataId(bookId, pageIndex, profileId);
    state.pageKeyById[pageDataId] = (pageIndex: pageIndex, profileId: profileId);
    _bookIdByPageDataId[pageDataId] = bookId;

    _emitPageData(bookId, pageIndex, profileId);
    _schedulePersist(bookId);
    return pageDataId;
  }

  int updatePageSummaryDirectly(int pageDataId, String summary) {
    final bookId = _bookIdByPageDataId[pageDataId];
    if (bookId == null) return 0;
    final state = _ensureStateLoaded(bookId);
    final pageKey = state.pageKeyById[pageDataId];
    if (pageKey == null) return 0;

    final key = _profileKey(pageKey.pageIndex, pageKey.profileId);
    final profile = state.profilesByKey[key];
    if (profile == null) return 0;

    profile.summary = summary;
    _emitPageData(bookId, pageKey.pageIndex, pageKey.profileId);
    _schedulePersist(bookId);
    return pageDataId;
  }

  int addMessage(int pageDataId, String text, bool isUser) {
    final bookId = _bookIdByPageDataId[pageDataId];
    if (bookId == null) return 0;
    final state = _ensureStateLoaded(bookId);
    final pageKey = state.pageKeyById[pageDataId];
    if (pageKey == null) return 0;

    final key = _profileKey(pageKey.pageIndex, pageKey.profileId);
    final profile = state.profilesByKey.putIfAbsent(
      key,
      () => _ProfileAiData(summary: '', messages: []),
    );

    final msg = ChatMessage(text: text, isUser: isUser);
    msg.id = state.nextMessageId++;
    profile.messages.add(msg);
    final index = profile.messages.length - 1;
    state.messageKeyById[msg.id] = (pageDataId: pageDataId, index: index);
    _bookIdByMessageId[msg.id] = bookId;

    _emitMessages(pageDataId);
    _schedulePersist(bookId);
    return msg.id;
  }

  void updateMessage(int messageId, String text) {
    final bookId = _bookIdByMessageId[messageId];
    if (bookId == null) return;
    final state = _ensureStateLoaded(bookId);
    final location = state.messageKeyById[messageId];
    if (location == null) return;

    final pageKey = state.pageKeyById[location.pageDataId];
    if (pageKey == null) return;
    final profile = state.profilesByKey[_profileKey(pageKey.pageIndex, pageKey.profileId)];
    if (profile == null) return;
    if (location.index < 0 || location.index >= profile.messages.length) return;

    profile.messages[location.index].text = text;
    _emitMessages(location.pageDataId);
    _schedulePersist(bookId);
  }

  Stream<List<ChatMessage>> watchMessages(int pageDataId) {
    final bookId = _bookIdByPageDataId[pageDataId];
    if (bookId == null) {
      return Stream<List<ChatMessage>>.value(const []);
    }
    final state = _ensureStateLoaded(bookId);

    final controller = state.messageControllers.putIfAbsent(
      pageDataId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );

    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(_messagesForPageDataId(pageDataId));
      }
    });
    return controller.stream;
  }

  List<ChatMessage> getRecentMessages(int pageDataId, {int limit = 10}) {
    final messages = _messagesForPageDataId(pageDataId);
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  void clearBookAiData(int bookId) {
    final state = _ensureStateLoaded(bookId);
    state.profilesByKey.clear();
    state.messageKeyById.clear();
    _bookIdByMessageId.removeWhere((_, value) => value == bookId);

    for (final entry in state.pageKeyById.entries) {
      _emitPageData(bookId, entry.value.pageIndex, entry.value.profileId);
      _emitMessages(entry.key);
    }

    _schedulePersist(bookId);
  }
}
