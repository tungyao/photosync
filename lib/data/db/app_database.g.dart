// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BackupRecordsTable extends BackupRecords
    with TableInfo<$BackupRecordsTable, BackupRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
      'asset_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remotePathMeta =
      const VerificationMeta('remotePath');
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
      'remote_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uploadedAtMeta =
      const VerificationMeta('uploadedAt');
  @override
  late final GeneratedColumn<int> uploadedAt = GeneratedColumn<int>(
      'uploaded_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sha1Meta = const VerificationMeta('sha1');
  @override
  late final GeneratedColumn<String> sha1 = GeneratedColumn<String>(
      'sha1', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [assetId, remotePath, uploadedAt, size, sha1];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_records';
  @override
  VerificationContext validateIntegrity(Insertable<BackupRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('remote_path')) {
      context.handle(
          _remotePathMeta,
          remotePath.isAcceptableOrUnknown(
              data['remote_path']!, _remotePathMeta));
    } else if (isInserting) {
      context.missing(_remotePathMeta);
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
          _uploadedAtMeta,
          uploadedAt.isAcceptableOrUnknown(
              data['uploaded_at']!, _uploadedAtMeta));
    } else if (isInserting) {
      context.missing(_uploadedAtMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('sha1')) {
      context.handle(
          _sha1Meta, sha1.isAcceptableOrUnknown(data['sha1']!, _sha1Meta));
    } else if (isInserting) {
      context.missing(_sha1Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  BackupRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRecord(
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asset_id'])!,
      remotePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_path'])!,
      uploadedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}uploaded_at'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      sha1: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha1'])!,
    );
  }

  @override
  $BackupRecordsTable createAlias(String alias) {
    return $BackupRecordsTable(attachedDatabase, alias);
  }
}

class BackupRecord extends DataClass implements Insertable<BackupRecord> {
  final String assetId;
  final String remotePath;
  final int uploadedAt;
  final int size;
  final String sha1;
  const BackupRecord(
      {required this.assetId,
      required this.remotePath,
      required this.uploadedAt,
      required this.size,
      required this.sha1});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['remote_path'] = Variable<String>(remotePath);
    map['uploaded_at'] = Variable<int>(uploadedAt);
    map['size'] = Variable<int>(size);
    map['sha1'] = Variable<String>(sha1);
    return map;
  }

  BackupRecordsCompanion toCompanion(bool nullToAbsent) {
    return BackupRecordsCompanion(
      assetId: Value(assetId),
      remotePath: Value(remotePath),
      uploadedAt: Value(uploadedAt),
      size: Value(size),
      sha1: Value(sha1),
    );
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRecord(
      assetId: serializer.fromJson<String>(json['assetId']),
      remotePath: serializer.fromJson<String>(json['remotePath']),
      uploadedAt: serializer.fromJson<int>(json['uploadedAt']),
      size: serializer.fromJson<int>(json['size']),
      sha1: serializer.fromJson<String>(json['sha1']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'remotePath': serializer.toJson<String>(remotePath),
      'uploadedAt': serializer.toJson<int>(uploadedAt),
      'size': serializer.toJson<int>(size),
      'sha1': serializer.toJson<String>(sha1),
    };
  }

  BackupRecord copyWith(
          {String? assetId,
          String? remotePath,
          int? uploadedAt,
          int? size,
          String? sha1}) =>
      BackupRecord(
        assetId: assetId ?? this.assetId,
        remotePath: remotePath ?? this.remotePath,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        size: size ?? this.size,
        sha1: sha1 ?? this.sha1,
      );
  BackupRecord copyWithCompanion(BackupRecordsCompanion data) {
    return BackupRecord(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      remotePath:
          data.remotePath.present ? data.remotePath.value : this.remotePath,
      uploadedAt:
          data.uploadedAt.present ? data.uploadedAt.value : this.uploadedAt,
      size: data.size.present ? data.size.value : this.size,
      sha1: data.sha1.present ? data.sha1.value : this.sha1,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecord(')
          ..write('assetId: $assetId, ')
          ..write('remotePath: $remotePath, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('size: $size, ')
          ..write('sha1: $sha1')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, remotePath, uploadedAt, size, sha1);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRecord &&
          other.assetId == this.assetId &&
          other.remotePath == this.remotePath &&
          other.uploadedAt == this.uploadedAt &&
          other.size == this.size &&
          other.sha1 == this.sha1);
}

class BackupRecordsCompanion extends UpdateCompanion<BackupRecord> {
  final Value<String> assetId;
  final Value<String> remotePath;
  final Value<int> uploadedAt;
  final Value<int> size;
  final Value<String> sha1;
  final Value<int> rowid;
  const BackupRecordsCompanion({
    this.assetId = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.size = const Value.absent(),
    this.sha1 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupRecordsCompanion.insert({
    required String assetId,
    required String remotePath,
    required int uploadedAt,
    required int size,
    required String sha1,
    this.rowid = const Value.absent(),
  })  : assetId = Value(assetId),
        remotePath = Value(remotePath),
        uploadedAt = Value(uploadedAt),
        size = Value(size),
        sha1 = Value(sha1);
  static Insertable<BackupRecord> custom({
    Expression<String>? assetId,
    Expression<String>? remotePath,
    Expression<int>? uploadedAt,
    Expression<int>? size,
    Expression<String>? sha1,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (remotePath != null) 'remote_path': remotePath,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (size != null) 'size': size,
      if (sha1 != null) 'sha1': sha1,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupRecordsCompanion copyWith(
      {Value<String>? assetId,
      Value<String>? remotePath,
      Value<int>? uploadedAt,
      Value<int>? size,
      Value<String>? sha1,
      Value<int>? rowid}) {
    return BackupRecordsCompanion(
      assetId: assetId ?? this.assetId,
      remotePath: remotePath ?? this.remotePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      size: size ?? this.size,
      sha1: sha1 ?? this.sha1,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<int>(uploadedAt.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (sha1.present) {
      map['sha1'] = Variable<String>(sha1.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('remotePath: $remotePath, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('size: $size, ')
          ..write('sha1: $sha1, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BackupRecordsTable backupRecords = $BackupRecordsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final BackupDao backupDao = BackupDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [backupRecords, settings];
}

typedef $$BackupRecordsTableCreateCompanionBuilder = BackupRecordsCompanion
    Function({
  required String assetId,
  required String remotePath,
  required int uploadedAt,
  required int size,
  required String sha1,
  Value<int> rowid,
});
typedef $$BackupRecordsTableUpdateCompanionBuilder = BackupRecordsCompanion
    Function({
  Value<String> assetId,
  Value<String> remotePath,
  Value<int> uploadedAt,
  Value<int> size,
  Value<String> sha1,
  Value<int> rowid,
});

class $$BackupRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha1 => $composableBuilder(
      column: $table.sha1, builder: (column) => ColumnFilters(column));
}

class $$BackupRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha1 => $composableBuilder(
      column: $table.sha1, builder: (column) => ColumnOrderings(column));
}

class $$BackupRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => column);

  GeneratedColumn<int> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get sha1 =>
      $composableBuilder(column: $table.sha1, builder: (column) => column);
}

class $$BackupRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BackupRecordsTable,
    BackupRecord,
    $$BackupRecordsTableFilterComposer,
    $$BackupRecordsTableOrderingComposer,
    $$BackupRecordsTableAnnotationComposer,
    $$BackupRecordsTableCreateCompanionBuilder,
    $$BackupRecordsTableUpdateCompanionBuilder,
    (
      BackupRecord,
      BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecord>
    ),
    BackupRecord,
    PrefetchHooks Function()> {
  $$BackupRecordsTableTableManager(_$AppDatabase db, $BackupRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> assetId = const Value.absent(),
            Value<String> remotePath = const Value.absent(),
            Value<int> uploadedAt = const Value.absent(),
            Value<int> size = const Value.absent(),
            Value<String> sha1 = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BackupRecordsCompanion(
            assetId: assetId,
            remotePath: remotePath,
            uploadedAt: uploadedAt,
            size: size,
            sha1: sha1,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String assetId,
            required String remotePath,
            required int uploadedAt,
            required int size,
            required String sha1,
            Value<int> rowid = const Value.absent(),
          }) =>
              BackupRecordsCompanion.insert(
            assetId: assetId,
            remotePath: remotePath,
            uploadedAt: uploadedAt,
            size: size,
            sha1: sha1,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BackupRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BackupRecordsTable,
    BackupRecord,
    $$BackupRecordsTableFilterComposer,
    $$BackupRecordsTableOrderingComposer,
    $$BackupRecordsTableAnnotationComposer,
    $$BackupRecordsTableCreateCompanionBuilder,
    $$BackupRecordsTableUpdateCompanionBuilder,
    (
      BackupRecord,
      BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecord>
    ),
    BackupRecord,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db, _db.backupRecords);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

mixin _$BackupDaoMixin on DatabaseAccessor<AppDatabase> {
  $BackupRecordsTable get backupRecords => attachedDatabase.backupRecords;
  $SettingsTable get settings => attachedDatabase.settings;
  BackupDaoManager get managers => BackupDaoManager(this);
}

class BackupDaoManager {
  final _$BackupDaoMixin _db;
  BackupDaoManager(this._db);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db.attachedDatabase, _db.backupRecords);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}
