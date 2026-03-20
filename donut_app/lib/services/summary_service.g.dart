// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(summaryGenerationService)
final summaryGenerationServiceProvider = SummaryGenerationServiceProvider._();

final class SummaryGenerationServiceProvider
    extends
        $FunctionalProvider<
          SummaryGenerationService,
          SummaryGenerationService,
          SummaryGenerationService
        >
    with $Provider<SummaryGenerationService> {
  SummaryGenerationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'summaryGenerationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$summaryGenerationServiceHash();

  @$internal
  @override
  $ProviderElement<SummaryGenerationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SummaryGenerationService create(Ref ref) {
    return summaryGenerationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SummaryGenerationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SummaryGenerationService>(value),
    );
  }
}

String _$summaryGenerationServiceHash() =>
    r'66fd8f38e8db9d68a1e82673fec3feaeea92c226';
