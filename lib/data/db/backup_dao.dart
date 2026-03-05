part of 'app_database.dart';

@DriftAccessor(tables: [BackupRecords, Settings])
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  Future<bool> exists(String assetId) async {
    final row = await (select(backupRecords)
          ..where((tbl) => tbl.assetId.equals(assetId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<Set<String>> findExistingIds(Iterable<String> assetIds) async {
    final ids = assetIds.where((id) => id.isNotEmpty).toSet().toList(growable: false);
    if (ids.isEmpty) return <String>{};

    // Keep IN-clause under SQLite variable limits.
    const chunkSize = 900;
    final existing = <String>{};

    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      final rows = await (select(backupRecords)
            ..where((tbl) => tbl.assetId.isIn(chunk)))
          .get();
      existing.addAll(rows.map((row) => row.assetId));
    }
    return existing;
  }

  Future<void> upsert(BackupRecordsCompanion record) {
    return into(backupRecords).insertOnConflictUpdate(record);
  }

  Future<String?> getSetting(String key) async {
    final row =
        await (select(settings)..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }
}
