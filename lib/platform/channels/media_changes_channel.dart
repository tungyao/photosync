import 'package:flutter/services.dart';

class MediaLibraryChangeEvent {
  const MediaLibraryChangeEvent({
    required this.type,
    required this.reason,
    required this.timestampMs,
    this.changedAfterMs,
  });

  final String type;
  final String reason;
  final int timestampMs;
  final int? changedAfterMs;

  factory MediaLibraryChangeEvent.fromMap(Map<dynamic, dynamic> map) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final timestamp = toInt(map['timestampMs']);
    final changedAfterRaw = map['changedAfterMs'];
    final changedAfter = changedAfterRaw == null ? null : toInt(changedAfterRaw);

    return MediaLibraryChangeEvent(
      type: map['type']?.toString() ?? 'libraryChanged',
      reason: map['reason']?.toString() ?? 'unknown',
      timestampMs: timestamp,
      changedAfterMs: changedAfter,
    );
  }
}

class MediaChangesChannel {
  MediaChangesChannel({EventChannel? channel})
      : _channel = channel ?? const EventChannel('app.mediaChanges');

  final EventChannel _channel;

  Stream<MediaLibraryChangeEvent> changes() {
    return _channel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => MediaLibraryChangeEvent.fromMap(event as Map));
  }
}
