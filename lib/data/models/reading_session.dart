import 'package:objectbox/objectbox.dart';
import 'book.dart';

@Entity()
class ReadingSession {
  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime startTime;

  @Property(type: PropertyType.date)
  DateTime? endTime;

  // Duration in seconds
  int duration;

  final book = ToOne<Book>();

  ReadingSession({
    required this.startTime,
    this.endTime,
    this.duration = 0,
  });
}
