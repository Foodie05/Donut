import 'package:objectbox/objectbox.dart';
import 'page_data.dart';

@Entity()
class ChatMessage {
  @Id()
  int id = 0;

  String text;
  bool isUser;
  DateTime timestamp;

  final pageData = ToOne<PageData>();

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
