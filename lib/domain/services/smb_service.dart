abstract interface class SmbService {
  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    int startByte,
  });
}
