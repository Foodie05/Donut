import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart'; // created by `flutter pub run build_runner build`

class ObjectBox {
  /// The Store of this app.
  late final Store store;

  ObjectBox._create(this.store);

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationSupportDirectory();
    print('ObjectBox: Application Support Directory: ${docsDir.path}');
    
    final dbPath = p.join(docsDir.path, "pdf_reader_db");
    print('ObjectBox: Database Path: $dbPath');
    
    // Ensure the directory exists
    final dir = Directory(dbPath);
    if (!dir.existsSync()) {
      print('ObjectBox: Creating directory...');
      try {
        await dir.create(recursive: true);
        print('ObjectBox: Directory created successfully.');
      } catch (e) {
        print('ObjectBox: Error creating directory: $e');
      }
    }
    
    // Test write permission
    try {
      final testFile = File(p.join(dbPath, 'test_write.txt'));
      await testFile.writeAsString('test');
      print('ObjectBox: Test write successful.');
      await testFile.delete();
    } catch (e) {
      print('ObjectBox: Test write failed: $e');
    }
    
    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    print('ObjectBox: Opening store...');
    final store = await openStore(directory: dbPath);
    print('ObjectBox: Store opened.');
    return ObjectBox._create(store);
  }
}
