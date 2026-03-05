import '../models/backup_checkpoint.dart';
import '../models/media_asset.dart';

abstract interface class MediaRepository {
  Future<List<MediaAsset>> fetchGalleryAssets();
}

abstract interface class CheckpointRepository {
  Future<List<BackupCheckpoint>> loadCheckpoints();
  Future<void> upsertCheckpoint(BackupCheckpoint checkpoint);
}
