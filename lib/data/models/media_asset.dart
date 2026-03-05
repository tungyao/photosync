class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.path,
    required this.type,
    required this.modifiedAt,
    required this.size,
    this.isSelected = false,
  });

  final String id;
  final String path;
  final String type;
  final DateTime modifiedAt;
  final int size;
  final bool isSelected;

  MediaAsset copyWith({bool? isSelected}) {
    return MediaAsset(
      id: id,
      path: path,
      type: type,
      modifiedAt: modifiedAt,
      size: size,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
