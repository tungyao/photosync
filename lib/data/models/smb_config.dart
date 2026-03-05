class SmbConfig {
  const SmbConfig({
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.password,
    required this.domain,
    required this.baseDir,
    required this.timeoutMs,
    required this.useSMB1,
  });

  final String host;
  final int port;
  final String share;
  final String username;
  final String password;
  final String domain;
  final String baseDir;
  final int timeoutMs;
  final bool useSMB1;
}
