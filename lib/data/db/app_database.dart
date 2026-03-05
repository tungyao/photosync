import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

part 'backup_dao.dart';
part 'app_database.g.dart';

class BackupRecords extends Table {
  TextColumn get assetId => text()();
  TextColumn get remotePath => text()();
  IntColumn get uploadedAt => integer()();
  IntColumn get size => integer()();
  TextColumn get sha1 => text()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [BackupRecords, Settings], daos: [BackupDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, AppConstants.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
