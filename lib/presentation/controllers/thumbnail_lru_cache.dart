import 'dart:collection';
import 'dart:typed_data';

class ThumbnailLruCache {
  ThumbnailLruCache({this.maxEntries = 300});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _inFlight = <String, Future<Uint8List?>>{};

  Uint8List? get(String key) {
    final bytes = _cache.remove(key);
    if (bytes != null) {
      _cache[key] = bytes;
    }
    return bytes;
  }

  Future<Uint8List?> getOrLoad(String key, Future<Uint8List?> Function() loader) {
    final hit = get(key);
    if (hit != null) return Future<Uint8List?>.value(hit);

    final running = _inFlight[key];
    if (running != null) return running;

    final future = loader().then((bytes) {
      if (bytes != null && bytes.isNotEmpty) {
        put(key, bytes);
      }
      return bytes;
    }).whenComplete(() {
      _inFlight.remove(key);
    });

    _inFlight[key] = future;
    return future;
  }

  void put(String key, Uint8List value) {
    _cache.remove(key);
    _cache[key] = value;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
