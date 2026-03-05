import 'package:flutter/services.dart';

class MediaListResult {
  const MediaListResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
  final bool hasMore;

  factory MediaListResult.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final parsedItems = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          parsedItems.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return MediaListResult(
      items: parsedItems,
      nextCursor: map['nextCursor'] as String?,
      hasMore: (map['hasMore'] as bool?) ?? false,
    );
  }
}

class ExportTempFileResult {
  const ExportTempFileResult({
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });

  final String localPath;
  final String fileName;
  final String mimeType;
  final int fileSize;

  factory ExportTempFileResult.fromMap(Map<String, dynamic> map) {
    return ExportTempFileResult(
      localPath: (map['localPath'] as String?) ?? '',
      fileName: (map['fileName'] as String?) ?? '',
      mimeType: (map['mimeType'] as String?) ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

class MediaChannel {
  MediaChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.media');

  final MethodChannel _channel;

  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<dynamic>('requestPermission');
    if (result is bool) return result;
    if (result is Map) {
      final map = Map<String, dynamic>.from(result);
      return (map['granted'] as bool?) ?? false;
    }
    return false;
  }

  Future<MediaListResult> listAssets({
    int? startTimeMs,
    int? limit,
    String? cursor,
    bool? ascending,
  }) async {
    final args = <String, dynamic>{
      if (startTimeMs != null) 'startTimeMs': startTimeMs,
      if (limit != null) 'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (ascending != null) 'ascending': ascending,
    };

    final result =
        await _channel.invokeMapMethod<String, dynamic>('listAssets', args);
    return MediaListResult.fromMap(result ?? const <String, dynamic>{});
  }

  Future<ExportTempFileResult> exportToTempFile(String assetId) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'exportToTempFile',
      <String, dynamic>{'assetId': assetId},
    );
    return ExportTempFileResult.fromMap(result ?? const <String, dynamic>{});
  }

  Future<Uint8List?> getThumbnail({
    required String assetId,
    int width = 256,
    int height = 256,
  }) {
    return _channel.invokeMethod<Uint8List>(
      'getThumbnail',
      <String, dynamic>{
        'assetId': assetId,
        'width': width,
        'height': height,
      },
    );
  }
}
