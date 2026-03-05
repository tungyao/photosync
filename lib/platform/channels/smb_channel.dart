import 'package:flutter/services.dart';

import '../../domain/services/smb_service.dart';

class SmbChannelService implements SmbService {
  static const _channel = MethodChannel('photosync/smb');

  @override
  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    int startByte = 0,
  }) async {
    await _channel.invokeMethod<void>('uploadFile', {
      'localPath': localPath,
      'remotePath': remotePath,
      'startByte': startByte,
    });
  }
}
