class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.createTimeMs,
    required this.mimeType,
    required this.mediaType,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fileSize,
  });

  final String id;
  final int createTimeMs;
  final String mimeType;
  final String mediaType;
  final int width;
  final int height;
  final int durationMs;
  final int fileSize;

  // Backward-compatible aliases for existing code paths.
  String get path => id;
  String get type => mediaType;
  DateTime get modifiedAt => DateTime.fromMillisecondsSinceEpoch(createTimeMs);
  int get size => fileSize;
}
