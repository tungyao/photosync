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

  SmbConfig copyWith({
    String? host,
    int? port,
    String? share,
    String? username,
    String? password,
    String? domain,
    String? baseDir,
    int? timeoutMs,
    bool? useSMB1,
  }) {
    return SmbConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      share: share ?? this.share,
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      baseDir: baseDir ?? this.baseDir,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      useSMB1: useSMB1 ?? this.useSMB1,
    );
  }
}
