import '../../data/models/media_asset.dart';
import '../../data/repositories/media_repository.dart';

class ScanGalleryUseCase {
  const ScanGalleryUseCase(this._repo);

  final MediaRepository _repo;

  Future<List<MediaAsset>> call() => _repo.fetchGalleryAssets();
}
