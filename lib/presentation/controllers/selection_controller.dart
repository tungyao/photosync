import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_asset.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/repository_impl.dart';
import '../../domain/usecases/scan_gallery_usecase.dart';
import '../../platform/channels/gallery_channel.dart';

final galleryChannelProvider = Provider<GalleryChannel>((ref) {
  return GalleryChannel();
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(ref.read(galleryChannelProvider));
});

final scanGalleryUseCaseProvider = Provider<ScanGalleryUseCase>((ref) {
  return ScanGalleryUseCase(ref.read(mediaRepositoryProvider));
});

final galleryAssetsProvider = FutureProvider<List<MediaAsset>>((ref) {
  return ref.read(scanGalleryUseCaseProvider).call();
});

final selectedIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

final selectedAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final assets = ref.watch(galleryAssetsProvider).value ?? const <MediaAsset>[];
  final selectedIds = ref.watch(selectedIdsProvider);
  return assets.where((e) => selectedIds.contains(e.id)).toList();
});
