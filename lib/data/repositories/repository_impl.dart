import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/backup_checkpoint.dart';
import '../models/media_asset.dart';
import '../../platform/channels/gallery_channel.dart';
import 'media_repository.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._galleryChannel);

  final GalleryChannel _galleryChannel;

  @override
  Future<List<MediaAsset>> fetchGalleryAssets() {
    return _galleryChannel.fetchAssets();
  }
}

class CheckpointRepositoryImpl implements CheckpointRepository {
  CheckpointRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<BackupCheckpoint>> loadCheckpoints() async {
    final rows = await _db.select(_db.backupRecords).get();
    return rows
        .map(
          (row) => BackupCheckpoint(
            assetId: row.assetId,
            localPath: '',
            remotePath: row.remotePath,
            modifiedAt: DateTime.fromMillisecondsSinceEpoch(row.uploadedAt),
            syncedAt: DateTime.fromMillisecondsSinceEpoch(row.uploadedAt),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertCheckpoint(BackupCheckpoint checkpoint) {
    return _db.into(_db.backupRecords).insertOnConflictUpdate(
          BackupRecordsCompanion(
            assetId: Value(checkpoint.assetId),
            remotePath: Value(checkpoint.remotePath),
            uploadedAt: Value(checkpoint.syncedAt.millisecondsSinceEpoch),
            size: const Value(0),
            sha1: const Value(''),
          ),
        );
  }
}
