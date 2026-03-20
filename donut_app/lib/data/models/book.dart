import 'package:objectbox/objectbox.dart';
import 'page_data.dart';

@Entity()
class Book {
  @Id()
  int id = 0;

  @Unique()
  String filePath;

  String title;
  String? coverPath;
  String fileHash; // SHA-256
  int lastReadPage;
  int totalPages;
  DateTime addedAt;
  DateTime lastOpened;

  @Backlink()
  final pageData = ToMany<PageData>();

  Book({
    required this.filePath,
    required this.title,
    required this.fileHash,
    this.coverPath,
    this.lastReadPage = 0,
    this.totalPages = 0,
    DateTime? addedAt,
    DateTime? lastOpened,
  }) : addedAt = addedAt ?? DateTime.now(),
       lastOpened = lastOpened ?? DateTime.now();
}
