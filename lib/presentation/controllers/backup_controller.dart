import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database_provider.dart';
import '../../data/models/backup_checkpoint.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/repository_impl.dart';
import '../../domain/services/backup_planner_service.dart';
import '../../domain/services/checkpoint_service.dart';
import '../../domain/services/smb_service.dart';
import '../../domain/usecases/run_incremental_backup_usecase.dart';
import '../../platform/channels/smb_channel.dart';
import 'selection_controller.dart';

class CheckpointServiceImpl implements CheckpointService {
  CheckpointServiceImpl(this._repo);

  final CheckpointRepository _repo;

  @override
  Future<List<BackupCheckpoint>> all() => _repo.loadCheckpoints();

  @override
  Future<void> save(BackupCheckpoint checkpoint) => _repo.upsertCheckpoint(checkpoint);
}

final checkpointRepositoryProvider = Provider<CheckpointRepository>((ref) {
  return CheckpointRepositoryImpl(ref.read(appDatabaseProvider));
});

final checkpointServiceProvider = Provider<CheckpointService>((ref) {
  return CheckpointServiceImpl(ref.read(checkpointRepositoryProvider));
});

final smbServiceProvider = Provider<SmbService>((ref) {
  return SmbChannelService();
});

final runIncrementalBackupUseCaseProvider = Provider<RunIncrementalBackupUseCase>((ref) {
  return RunIncrementalBackupUseCase(
    smbService: ref.read(smbServiceProvider),
    checkpointService: ref.read(checkpointServiceProvider),
    planner: const BackupPlannerService(),
  );
});

final backupProgressProvider = StateProvider<double>((ref) => 0);

final backupActionProvider = FutureProvider<int>((ref) async {
  final selected = ref.read(selectedAssetsProvider);
  final useCase = ref.read(runIncrementalBackupUseCaseProvider);

  final total = selected.length;
  if (total == 0) return 0;

  final synced = await useCase.call(selected);
  ref.read(backupProgressProvider.notifier).state = synced / total;
  return synced;
});
