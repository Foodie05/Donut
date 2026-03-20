import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_state.g.dart';

@riverpod
class CurrentPage extends _$CurrentPage {
  @override
  int build() => 0;

  void setPage(int page) => state = page;
}

@riverpod
class AiPanelWidth extends _$AiPanelWidth {
  @override
  double build() => 350.0;

  void setWidth(double width) => state = width;
}
