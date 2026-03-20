import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const _dpdfMagic = 'DPDF';
const _dpdfVersion = 1;

class DpdfDocument {
  final Map<String, dynamic> manifest;
  final Uint8List pdfBytes;
  final Map<String, dynamic> aiData;

  const DpdfDocument({
    required this.manifest,
    required this.pdfBytes,
    required this.aiData,
  });
}

Map<String, dynamic> defaultAiData() {
  return {
    'schemaVersion': 1,
    'nextMessageId': 1,
    'pages': <Map<String, dynamic>>[],
  };
}

bool isDpdfPath(String path) {
  return p.extension(path).toLowerCase() == '.dpdf';
}

Future<DpdfDocument> readDpdf(String filePath) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  return readDpdfFromBytes(bytes);
}

DpdfDocument readDpdfFromBytes(Uint8List bytes) {
  if (bytes.length < 4 + 1 + 8) {
    throw const FormatException('DPDF file is too small');
  }

  final magic = utf8.decode(bytes.sublist(0, 4));
  if (magic != _dpdfMagic) {
    throw const FormatException('Invalid DPDF magic');
  }

  final version = bytes[4];
  if (version != _dpdfVersion) {
    throw const FormatException('Unsupported DPDF version');
  }

  final manifestLenData = ByteData.sublistView(bytes, 5, 13);
  final manifestLength = manifestLenData.getUint64(0, Endian.big);
  if (manifestLength <= 0) {
    throw const FormatException('Invalid DPDF manifest length');
  }

  final manifestStart = 13;
  final manifestEnd = manifestStart + manifestLength;
  if (manifestEnd > bytes.length) {
    throw const FormatException('Corrupted DPDF manifest');
  }

  Map<String, dynamic> manifest;
  try {
    manifest = jsonDecode(utf8.decode(bytes.sublist(manifestStart, manifestEnd)))
        as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('Invalid DPDF manifest JSON');
  }

  final pdfLength = (manifest['pdfLength'] as num?)?.toInt() ?? -1;
  final aiLength = (manifest['aiDataLength'] as num?)?.toInt() ?? -1;
  if (pdfLength < 0 || aiLength < 0) {
    throw const FormatException('Invalid DPDF segment lengths');
  }

  final pdfStart = manifestEnd;
  final pdfEnd = pdfStart + pdfLength;
  final aiStart = pdfEnd;
  final aiEnd = aiStart + aiLength;
  if (aiEnd > bytes.length) {
    throw const FormatException('Corrupted DPDF segment bounds');
  }

  final pdfBytes = Uint8List.fromList(bytes.sublist(pdfStart, pdfEnd));
  final aiBytes = bytes.sublist(aiStart, aiEnd);

  Map<String, dynamic> aiData;
  try {
    final decoded = jsonDecode(utf8.decode(aiBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI data root');
    }
    aiData = decoded;
  } catch (_) {
    aiData = defaultAiData();
  }

  return DpdfDocument(
    manifest: manifest,
    pdfBytes: pdfBytes,
    aiData: aiData,
  );
}

Future<void> createDpdfFromPdf({
  required String sourcePdfPath,
  required String targetDpdfPath,
  Map<String, dynamic>? aiData,
}) async {
  final bytes = await File(sourcePdfPath).readAsBytes();
  await writeDpdf(
    targetDpdfPath,
    pdfBytes: bytes,
    aiData: aiData ?? defaultAiData(),
  );
}

Future<void> createDpdfFromDpdf({
  required String sourceDpdfPath,
  required String targetDpdfPath,
}) async {
  final doc = await readDpdf(sourceDpdfPath);
  await writeDpdf(
    targetDpdfPath,
    pdfBytes: doc.pdfBytes,
    aiData: doc.aiData,
    previousManifest: doc.manifest,
  );
}

Future<void> writeDpdf(
  String targetPath, {
  required List<int> pdfBytes,
  required Map<String, dynamic> aiData,
  Map<String, dynamic>? previousManifest,
}) async {
  final aiJson = jsonEncode(aiData);
  final aiBytes = utf8.encode(aiJson);

  final manifest = <String, dynamic>{
    'format': 'dpdf',
    'schemaVersion': 1,
    'containerVersion': _dpdfVersion,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'pdfLength': pdfBytes.length,
    'aiDataLength': aiBytes.length,
    if (previousManifest != null) ...{
      // preserve extension fields from previous manifest
      for (final entry in previousManifest.entries)
        if (!{
          'format',
          'schemaVersion',
          'containerVersion',
          'createdAt',
          'pdfLength',
          'aiDataLength',
        }.contains(entry.key))
          entry.key: entry.value,
    },
  };

  final manifestBytes = utf8.encode(jsonEncode(manifest));
  final output = BytesBuilder(copy: false);
  output.add(utf8.encode(_dpdfMagic)); // 4 bytes
  output.add([_dpdfVersion]); // 1 byte

  final len = ByteData(8)..setUint64(0, manifestBytes.length, Endian.big);
  output.add(len.buffer.asUint8List());
  output.add(manifestBytes);
  output.add(pdfBytes);
  output.add(aiBytes);

  final file = File(targetPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(output.toBytes(), flush: true);
}

Future<void> updateDpdfAiData(
  String dpdfPath,
  Map<String, dynamic> aiData,
) async {
  final doc = await readDpdf(dpdfPath);
  await writeDpdf(
    dpdfPath,
    pdfBytes: doc.pdfBytes,
    aiData: aiData,
    previousManifest: doc.manifest,
  );
}

Future<Uint8List> extractPdfBytes(String dpdfPath) async {
  final doc = await readDpdf(dpdfPath);
  return doc.pdfBytes;
}

Future<Map<String, dynamic>> extractAiData(String dpdfPath) async {
  final doc = await readDpdf(dpdfPath);
  return doc.aiData;
}
