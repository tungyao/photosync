class BackupCheckpoint {
  const BackupCheckpoint({
    required this.assetId,
    required this.localPath,
    required this.remotePath,
    required this.modifiedAt,
    required this.syncedAt,
  });

  final String assetId;
  final String localPath;
  final String remotePath;
  final DateTime modifiedAt;
  final DateTime syncedAt;
}
