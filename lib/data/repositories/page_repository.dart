import 'package:objectbox/objectbox.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../objectbox.g.dart';
import '../models/page_data.dart';
import '../models/chat_message.dart';
import '../../providers.dart';

part 'page_repository.g.dart';

@riverpod
PageRepository pageRepository(Ref ref) {
  return PageRepository(ref.watch(storeProvider));
}

// Manual providers to handle stream subscription sharing
final watchPageDataProvider = StreamProvider.autoDispose.family<PageData?, ({int bookId, int pageIndex})>((ref, args) {
  return ref.watch(pageRepositoryProvider).watchPageData(args.bookId, args.pageIndex);
});

final watchMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, int>((ref, pageDataId) {
  return ref.watch(pageRepositoryProvider).watchMessages(pageDataId);
});

class PageRepository {
  final Store _store;
  late final Box<PageData> _pageBox;
  late final Box<ChatMessage> _messageBox;

  PageRepository(this._store) {
    _pageBox = _store.box<PageData>();
    _messageBox = _store.box<ChatMessage>();
  }

  PageData? getPageData(int bookId, int pageIndex) {
    final query = _pageBox.query(
      PageData_.book.equals(bookId).and(PageData_.pageIndex.equals(pageIndex))
    ).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Stream<PageData?> watchPageData(int bookId, int pageIndex) {
    return _pageBox
        .query(PageData_.book.equals(bookId).and(PageData_.pageIndex.equals(pageIndex)))
        .watch(triggerImmediately: true)
        .map((query) => query.findFirst());
  }

  int savePageSummary(int bookId, int pageIndex, String summary, String? screenshotPath) {
    return _store.runInTransaction(TxMode.write, () {
      final query = _pageBox.query(
        PageData_.book.equals(bookId).and(PageData_.pageIndex.equals(pageIndex))
      ).build();
      var pageData = query.findFirst();
      query.close();

      if (pageData == null) {
        pageData = PageData(pageIndex: pageIndex);
        pageData.book.targetId = bookId;
      }

      pageData.summary = summary;
      if (screenshotPath != null) {
        pageData.screenshotPath = screenshotPath;
      }
      
      return _pageBox.put(pageData);
    });
  }

  int updatePageSummaryDirectly(int pageDataId, String summary) {
    final pageData = _pageBox.get(pageDataId);
    if (pageData != null) {
      pageData.summary = summary;
      return _pageBox.put(pageData);
    }
    return 0;
  }

  int addMessage(int pageDataId, String text, bool isUser) {
    final message = ChatMessage(text: text, isUser: isUser);
    message.pageData.targetId = pageDataId;
    return _messageBox.put(message);
  }

  void updateMessage(int messageId, String text) {
    final message = _messageBox.get(messageId);
    if (message != null) {
      message.text = text;
      _messageBox.put(message);
    }
  }

  Stream<List<ChatMessage>> watchMessages(int pageDataId) {
    return _messageBox.query(ChatMessage_.pageData.equals(pageDataId))
        .order(ChatMessage_.timestamp)
        .watch(triggerImmediately: true)
        .map((query) => query.find());
  }

  List<ChatMessage> getRecentMessages(int pageDataId, {int limit = 10}) {
    final query = _messageBox.query(ChatMessage_.pageData.equals(pageDataId))
        .order(ChatMessage_.timestamp, flags: Order.descending)
        .build();
    query.limit = limit;
    final messages = query.find();
    query.close();
    return messages.reversed.toList(); // Return in chronological order
  }
}
