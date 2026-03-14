import 'package:objectbox/objectbox.dart';
import 'book.dart';
import 'chat_message.dart';

@Entity()
class PageData {
  @Id()
  int id = 0;

  int pageIndex;
  String profileId;
  String? summary;
  String? screenshotPath; // Path to the screenshot image

  final book = ToOne<Book>();

  @Backlink()
  final messages = ToMany<ChatMessage>();

  PageData({
    required this.pageIndex,
    required this.profileId,
    this.summary,
    this.screenshotPath,
  });
}
