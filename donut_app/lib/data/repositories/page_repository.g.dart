// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pageRepository)
final pageRepositoryProvider = PageRepositoryProvider._();

final class PageRepositoryProvider
    extends $FunctionalProvider<PageRepository, PageRepository, PageRepository>
    with $Provider<PageRepository> {
  PageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageRepositoryHash();

  @$internal
  @override
  $ProviderElement<PageRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PageRepository create(Ref ref) {
    return pageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageRepository>(value),
    );
  }
}

String _$pageRepositoryHash() => r'ab2a5f1cfe30f21211bbfaa20f1c1c9bc2a4fe88';
