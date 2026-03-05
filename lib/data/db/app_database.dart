import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

part 'app_database.g.dart';

class BackupItems extends Table {
  TextColumn get assetId => text()();
  TextColumn get localPath => text()();
  TextColumn get remotePath => text()();
  DateTimeColumn get modifiedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

class UploadSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get assetId => text()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [BackupItems, UploadSessions])
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
