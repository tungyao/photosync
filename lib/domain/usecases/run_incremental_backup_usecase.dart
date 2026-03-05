import '../../data/models/backup_checkpoint.dart';
import '../../data/models/media_asset.dart';
import '../services/backup_planner_service.dart';
import '../services/checkpoint_service.dart';
import '../services/smb_service.dart';

class RunIncrementalBackupUseCase {
  RunIncrementalBackupUseCase({
    required SmbService smbService,
    required CheckpointService checkpointService,
    required BackupPlannerService planner,
  })  : _smbService = smbService,
        _checkpointService = checkpointService,
        _planner = planner;

  final SmbService _smbService;
  final CheckpointService _checkpointService;
  final BackupPlannerService _planner;

  Future<int> call(List<MediaAsset> selected) async {
    final checkpoints = await _checkpointService.all();
    final targets = _planner.incrementalAssets(
      selected: selected,
      checkpoints: checkpoints,
    );

    var synced = 0;
    for (final item in targets) {
      final remotePath = '/photosync/${item.id}';
      await _smbService.uploadFile(localPath: item.path, remotePath: remotePath);
      await _checkpointService.save(
        BackupCheckpoint(
          assetId: item.id,
          localPath: item.path,
          remotePath: remotePath,
          modifiedAt: item.modifiedAt,
          syncedAt: DateTime.now(),
        ),
      );
      synced++;
    }
    return synced;
  }
}
