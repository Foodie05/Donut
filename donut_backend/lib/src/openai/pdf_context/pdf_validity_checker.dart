import 'dart:typed_data';

/// Result of PDF validity checks before native document injection.
class PdfValidationResult {
  const PdfValidationResult({
    required this.isValid,
    required this.reasonCode,
    required this.isEncrypted,
    required this.isCorrupted,
    required this.garbleScore,
  });

  final bool isValid;
  final String reasonCode;
  final bool isEncrypted;
  final bool isCorrupted;

  /// 0.0 means no anomaly, 1.0 means severe anomaly.
  final double garbleScore;

  bool get shouldUseExceptionFallback => !isValid;

  Map<String, Object> toJson() {
    return {
      'isValid': isValid,
      'reasonCode': reasonCode,
      'isEncrypted': isEncrypted,
      'isCorrupted': isCorrupted,
      'garbleScore': garbleScore,
      'shouldUseExceptionFallback': shouldUseExceptionFallback,
    };
  }
}

/// Lightweight validator for deciding whether to inject PDF as native document.
///
/// This does not replace a full PDF parser. It is intended as a deterministic,
/// fast gate before request composition.
class PdfValidityChecker {
  const PdfValidityChecker({
    this.maxAllowedGarbleScore = 0.45,
  });

  final double maxAllowedGarbleScore;

  PdfValidationResult validate(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const PdfValidationResult(
        isValid: false,
        reasonCode: 'empty_pdf',
        isEncrypted: false,
        isCorrupted: true,
        garbleScore: 1.0,
      );
    }

    final ascii = String.fromCharCodes(bytes, 0, bytes.length);

    final hasPdfHeader = ascii.startsWith('%PDF-');
    final hasEof = ascii.contains('%%EOF');
    final hasStartXref = ascii.contains('startxref');
    final isEncrypted = ascii.contains('/Encrypt');

    final garbleScore = _estimateGarbleScore(bytes);
    final isCorrupted = !hasPdfHeader || !hasEof || !hasStartXref;

    if (isEncrypted) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'encrypted_pdf',
        isEncrypted: true,
        isCorrupted: isCorrupted,
        garbleScore: garbleScore,
      );
    }

    if (isCorrupted) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'invalid_pdf_structure',
        isEncrypted: false,
        isCorrupted: true,
        garbleScore: garbleScore,
      );
    }

    if (garbleScore > maxAllowedGarbleScore) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'garbled_pdf_content',
        isEncrypted: false,
        isCorrupted: false,
        garbleScore: garbleScore,
      );
    }

    return PdfValidationResult(
      isValid: true,
      reasonCode: 'ok',
      isEncrypted: false,
      isCorrupted: false,
      garbleScore: garbleScore,
    );
  }

  double _estimateGarbleScore(Uint8List bytes) {
    var suspicious = 0;
    var considered = 0;

    for (final b in bytes) {
      // Focus on bytes likely to represent human-readable text in PDF objects.
      final isCommonTextByte =
          (b >= 0x20 && b <= 0x7E) || b == 0x0A || b == 0x0D || b == 0x09;
      final isLikelyBinaryNoise = b == 0x00 || b == 0xFF;

      if (isCommonTextByte || isLikelyBinaryNoise) {
        considered += 1;
        if (isLikelyBinaryNoise) {
          suspicious += 1;
        }
      }
    }

    if (considered == 0) return 1.0;
    return suspicious / considered;
  }
}
