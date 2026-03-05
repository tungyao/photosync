import 'package:flutter/services.dart';

import '../../data/models/smb_config.dart';
import '../../domain/services/smb_service.dart';

class SmbChannel {
  SmbChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.smb');

  final MethodChannel _channel;

  Future<bool> testConnection(SmbConfig config) async {
    final ok = await _channel.invokeMethod<bool>(
      'testConnection',
      <String, dynamic>{'config': _configToMap(config)},
    );
    return ok ?? false;
  }

  Future<bool> exists({
    required SmbConfig config,
    required String remotePath,
  }) async {
    final result = await _channel.invokeMethod<bool>(
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
    return _channel.invokeMethod<void>(
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
    return _channel.invokeMethod<void>(
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
