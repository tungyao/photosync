import '../../data/models/media_asset.dart';

abstract interface class GalleryService {
  Future<List<MediaAsset>> scanAllAssets();
}
