import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/database.dart';
import 'objectbox.g.dart';

final objectBoxProvider = Provider<ObjectBox>((ref) => throw UnimplementedError());

final storeProvider = Provider<Store>((ref) => ref.watch(objectBoxProvider).store);
