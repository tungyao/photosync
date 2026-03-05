import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/models/media_asset.dart';

class GalleryChannel {
  static const _channel = MethodChannel('photosync/gallery');

  Future<List<MediaAsset>> fetchAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return const [];

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    final all = <MediaAsset>[];
    for (final album in paths) {
      final assets = await album.getAssetListPaged(page: 0, size: 200);
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;
        all.add(
          MediaAsset(
            id: asset.id,
            createTimeMs: asset.createDateTime.millisecondsSinceEpoch,
            mimeType: asset.mimeType ?? '',
            mediaType: asset.type.name,
            width: asset.width,
            height: asset.height,
            durationMs: asset.duration * 1000,
            fileSize: await file.length(),
          ),
        );
      }
    }

    return all;
  }

  Future<void> pingNative() async {
    await _channel.invokeMethod<void>('ping');
  }
}
