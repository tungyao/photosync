import '../../data/models/backup_checkpoint.dart';
import '../../data/models/media_asset.dart';

class BackupPlannerService {
  const BackupPlannerService();

  List<MediaAsset> incrementalAssets({
    required List<MediaAsset> selected,
    required List<BackupCheckpoint> checkpoints,
  }) {
    final map = {for (final c in checkpoints) c.assetId: c};

    return selected.where((asset) {
      final old = map[asset.id];
      if (old == null) return true;
      return old.modifiedAt.isBefore(asset.modifiedAt);
    }).toList();
  }
}
