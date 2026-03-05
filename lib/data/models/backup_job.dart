enum BackupMode {
  latestOnly,
  all,
}

class BackupJob {
  const BackupJob({
    required this.jobId,
    required this.mode,
    required this.startTimeMs,
    required this.skipIfRemoteExists,
    required this.concurrency,
  });

  final String jobId;
  final BackupMode mode;
  final int startTimeMs;
  final bool skipIfRemoteExists;
  final int concurrency;
}
