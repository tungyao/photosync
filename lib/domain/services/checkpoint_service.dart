import '../../data/models/backup_checkpoint.dart';

abstract interface class CheckpointService {
  Future<List<BackupCheckpoint>> all();
  Future<void> save(BackupCheckpoint checkpoint);
}
