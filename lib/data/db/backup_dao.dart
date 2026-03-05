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
