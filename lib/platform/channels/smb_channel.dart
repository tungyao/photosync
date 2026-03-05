import 'package:flutter/services.dart';

import '../../data/models/smb_config.dart';
import '../../domain/services/smb_service.dart';

class SmbRemoteEntry {
  const SmbRemoteEntry({
    required this.path,
    required this.name,
    required this.isDir,
    required this.size,
    required this.modifiedMs,
    required this.mimeType,
  });

  final String path;
  final String name;
  final bool isDir;
  final int size;
  final int modifiedMs;
  final String mimeType;
  String get localMatchKey => '$name|$size';
  bool get isImage => !isDir && mimeType.toLowerCase().startsWith('image/');

  bool get isMedia => isImage;

  factory SmbRemoteEntry.fromMap(Map<dynamic, dynamic> map) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SmbRemoteEntry(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isDir: (map['isDir'] as bool?) ?? false,
      size: toInt(map['size']),
      modifiedMs: toInt(map['modifiedMs']),
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
    );
  }
}

class SmbListResult {
  const SmbListResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<SmbRemoteEntry> items;
  final String? nextCursor;
  final bool hasMore;

  factory SmbListResult.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'];
    final parsed = <SmbRemoteEntry>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          parsed.add(SmbRemoteEntry.fromMap(item));
        }
      }
    }
    return SmbListResult(
      items: parsed,
      nextCursor: map['nextCursor']?.toString(),
      hasMore: (map['hasMore'] as bool?) ?? false,
    );
  }
}

class SmbDownloadResult {
  const SmbDownloadResult({
    required this.localPath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  final String localPath;
  final String fileName;
  final int fileSize;
  final String mimeType;

  factory SmbDownloadResult.fromMap(Map<dynamic, dynamic> map) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SmbDownloadResult(
      localPath: map['localPath']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      fileSize: toInt(map['fileSize']),
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
    );
  }
}

class SaveToAlbumResult {
  const SaveToAlbumResult({
    required this.assetId,
    required this.duplicateSkipped,
    required this.bytesWritten,
  });

  final String? assetId;
  final bool duplicateSkipped;
  final int bytesWritten;

  factory SaveToAlbumResult.fromMap(Map<dynamic, dynamic> map) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SaveToAlbumResult(
      assetId: map['assetId']?.toString(),
      duplicateSkipped: (map['duplicateSkipped'] as bool?) ?? false,
      bytesWritten: toInt(map['bytesWritten']),
    );
  }
}

class SmbChannel {
  SmbChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.smb');

  final MethodChannel _channel;

  Future<bool> testConnection(SmbConfig config) async {
    final ok = await _invokeMethod<bool>(
      'testConnection',
      <String, dynamic>{'config': _configToMap(config)},
    );
    return ok ?? false;
  }

  Future<bool> exists({
    required SmbConfig config,
    required String remotePath,
  }) async {
    final result = await _invokeMethod<bool>(
      'exists',
      <String, dynamic>{
        'config': _configToMap(config),
        'remotePath': remotePath,
      },
    );
    return result ?? false;
  }

  Future<void> ensureDir({
    required SmbConfig config,
    required String remoteDir,
  }) {
    return _invokeMethod<void>(
      'ensureDir',
      <String, dynamic>{
        'config': _configToMap(config),
        'remoteDir': remoteDir,
      },
    );
  }

  Future<void> uploadFile({
    required SmbConfig config,
    required String localPath,
    required String remotePath,
    bool overwrite = true,
    bool createParentDirs = true,
    int chunkSize = 256 * 1024,
  }) {
    return _invokeMethod<void>(
      'uploadFile',
      <String, dynamic>{
        'config': _configToMap(config),
        'localPath': localPath,
        'remotePath': remotePath,
        'overwrite': overwrite,
        'createParentDirs': createParentDirs,
        'chunkSize': chunkSize,
      },
    );
  }

  Future<SmbListResult> listRemote({
    required SmbConfig config,
    required String dir,
    int limit = 100,
    String? cursor,
    bool latestFirst = false,
  }) async {
    final map = await _invokeMethod<Map<dynamic, dynamic>>(
      'listRemote',
      <String, dynamic>{
        'config': _configToMap(config),
        'dir': dir,
        'limit': limit,
        'latestFirst': latestFirst,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return SmbListResult.fromMap(map ?? const <String, dynamic>{});
  }

  Future<SmbDownloadResult> downloadRemoteToTemp({
    required SmbConfig config,
    required String remotePath,
  }) async {
    final map = await _invokeMethod<Map<dynamic, dynamic>>(
      'downloadRemoteToTemp',
      <String, dynamic>{
        'config': _configToMap(config),
        'remotePath': remotePath,
      },
    );
    return SmbDownloadResult.fromMap(map ?? const <String, dynamic>{});
  }

  Future<SaveToAlbumResult> saveTempToAlbum({
    required String localPath,
    required String fileName,
    required String mimeType,
    bool skipDuplicates = true,
  }) async {
    final map = await _invokeMethod<Map<dynamic, dynamic>>(
      'saveTempToAlbum',
      <String, dynamic>{
        'localPath': localPath,
        'fileName': fileName,
        'mimeType': mimeType,
        'skipDuplicates': skipDuplicates,
      },
    );
    return SaveToAlbumResult.fromMap(map ?? const <String, dynamic>{});
  }

  Future<Uint8List?> getRemoteThumbnail({
    required SmbConfig config,
    required String remotePath,
    int width = 200,
    int height = 200,
  }) {
    return _invokeMethod<Uint8List>(
      'getRemoteThumbnail',
      <String, dynamic>{
        'config': _configToMap(config),
        'remotePath': remotePath,
        'width': width,
        'height': height,
      },
    );
  }

  Future<T?> _invokeMethod<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw PlatformException(
        code: 'UNSUPPORTED_PLATFORM',
        message: 'This SMB operation is not implemented on current platform.',
      );
    }
  }

  Map<String, dynamic> _configToMap(SmbConfig config) {
    return <String, dynamic>{
      'host': config.host,
      'port': config.port,
      'share': config.share,
      'username': config.username,
      'password': config.password,
      'domain': config.domain,
      'baseDir': config.baseDir,
      'timeoutMs': config.timeoutMs,
      'useSMB1': config.useSMB1,
    };
  }
}

class SmbChannelService implements SmbService {
  SmbChannelService({SmbConfig? config})
      : _config = config ??
            const SmbConfig(
              host: '',
              port: 445,
              share: '',
              username: '',
              password: '',
              domain: '',
              baseDir: '/',
              timeoutMs: 15000,
              useSMB1: false,
            );

  final SmbConfig _config;
  final SmbChannel _smb = SmbChannel();

  @override
  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    int startByte = 0,
  }) async {
    await _smb.uploadFile(
      config: _config,
      localPath: localPath,
      remotePath: remotePath,
      overwrite: true,
      createParentDirs: true,
      chunkSize: 256 * 1024,
    );
  }
}
