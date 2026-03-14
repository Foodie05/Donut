// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookRepository)
final bookRepositoryProvider = BookRepositoryProvider._();

final class BookRepositoryProvider
    extends $FunctionalProvider<BookRepository, BookRepository, BookRepository>
    with $Provider<BookRepository> {
  BookRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookRepository create(Ref ref) {
    return bookRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookRepository>(value),
    );
  }
}

String _$bookRepositoryHash() => r'edd377ef0d4bac55bb02f4a0357862a9c6063022';

@ProviderFor(books)
final booksProvider = BooksProvider._();

final class BooksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Book>>,
          List<Book>,
          Stream<List<Book>>
        >
    with $FutureModifier<List<Book>>, $StreamProvider<List<Book>> {
  BooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'booksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$booksHash();

  @$internal
  @override
  $StreamProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Book>> create(Ref ref) {
    return books(ref);
  }
}

String _$booksHash() => r'cda6a572c4294f6aa7b680edbe6ff0cbaa8bd12e';

@ProviderFor(book)
final bookProvider = BookFamily._();

final class BookProvider extends $FunctionalProvider<Book?, Book?, Book?>
    with $Provider<Book?> {
  BookProvider._({required BookFamily super.from, required int super.argument})
    : super(
        retry: null,
        name: r'bookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookHash();

  @override
  String toString() {
    return r'bookProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Book?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Book? create(Ref ref) {
    final argument = this.argument as int;
    return book(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Book? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Book?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookHash() => r'6c13d0f6d709b29c518dd1665f684b31de69549d';

final class BookFamily extends $Family
    with $FunctionalFamilyOverride<Book?, int> {
  BookFamily._()
    : super(
        retry: null,
        name: r'bookProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BookProvider call(int id) => BookProvider._(argument: id, from: this);

  @override
  String toString() => r'bookProvider';
}
