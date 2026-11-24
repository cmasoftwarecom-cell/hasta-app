// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_cache.dart';

// ignore_for_file: type=lint
class $CachedProfilesTable extends CachedProfiles
    with TableInfo<$CachedProfilesTable, CachedProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [accountId, displayName, username];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<CachedProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  CachedProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProfile(
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username']),
    );
  }

  @override
  $CachedProfilesTable createAlias(String alias) {
    return $CachedProfilesTable(attachedDatabase, alias);
  }
}

class CachedProfile extends DataClass implements Insertable<CachedProfile> {
  final String accountId;
  final String? displayName;
  final String? username;
  const CachedProfile(
      {required this.accountId, this.displayName, this.username});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    return map;
  }

  CachedProfilesCompanion toCompanion(bool nullToAbsent) {
    return CachedProfilesCompanion(
      accountId: Value(accountId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
    );
  }

  factory CachedProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProfile(
      accountId: serializer.fromJson<String>(json['accountId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      username: serializer.fromJson<String?>(json['username']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'displayName': serializer.toJson<String?>(displayName),
      'username': serializer.toJson<String?>(username),
    };
  }

  CachedProfile copyWith(
          {String? accountId,
          Value<String?> displayName = const Value.absent(),
          Value<String?> username = const Value.absent()}) =>
      CachedProfile(
        accountId: accountId ?? this.accountId,
        displayName: displayName.present ? displayName.value : this.displayName,
        username: username.present ? username.value : this.username,
      );
  CachedProfile copyWithCompanion(CachedProfilesCompanion data) {
    return CachedProfile(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      username: data.username.present ? data.username.value : this.username,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfile(')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('username: $username')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, displayName, username);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProfile &&
          other.accountId == this.accountId &&
          other.displayName == this.displayName &&
          other.username == this.username);
}

class CachedProfilesCompanion extends UpdateCompanion<CachedProfile> {
  final Value<String> accountId;
  final Value<String?> displayName;
  final Value<String?> username;
  final Value<int> rowid;
  const CachedProfilesCompanion({
    this.accountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.username = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProfilesCompanion.insert({
    required String accountId,
    this.displayName = const Value.absent(),
    this.username = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<CachedProfile> custom({
    Expression<String>? accountId,
    Expression<String>? displayName,
    Expression<String>? username,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (displayName != null) 'display_name': displayName,
      if (username != null) 'username': username,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProfilesCompanion copyWith(
      {Value<String>? accountId,
      Value<String?>? displayName,
      Value<String?>? username,
      Value<int>? rowid}) {
    return CachedProfilesCompanion(
      accountId: accountId ?? this.accountId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfilesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('username: $username, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProfileCache extends GeneratedDatabase {
  _$ProfileCache(QueryExecutor e) : super(e);
  $ProfileCacheManager get managers => $ProfileCacheManager(this);
  late final $CachedProfilesTable cachedProfiles = $CachedProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedProfiles];
}

typedef $$CachedProfilesTableCreateCompanionBuilder = CachedProfilesCompanion
    Function({
  required String accountId,
  Value<String?> displayName,
  Value<String?> username,
  Value<int> rowid,
});
typedef $$CachedProfilesTableUpdateCompanionBuilder = CachedProfilesCompanion
    Function({
  Value<String> accountId,
  Value<String?> displayName,
  Value<String?> username,
  Value<int> rowid,
});

class $$CachedProfilesTableFilterComposer
    extends FilterComposer<_$ProfileCache, $CachedProfilesTable> {
  $$CachedProfilesTableFilterComposer(super.$state);
  ColumnFilters<String> get accountId => $state.composableBuilder(
      column: $state.table.accountId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get displayName => $state.composableBuilder(
      column: $state.table.displayName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get username => $state.composableBuilder(
      column: $state.table.username,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$CachedProfilesTableOrderingComposer
    extends OrderingComposer<_$ProfileCache, $CachedProfilesTable> {
  $$CachedProfilesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get accountId => $state.composableBuilder(
      column: $state.table.accountId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get displayName => $state.composableBuilder(
      column: $state.table.displayName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get username => $state.composableBuilder(
      column: $state.table.username,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$CachedProfilesTableTableManager extends RootTableManager<
    _$ProfileCache,
    $CachedProfilesTable,
    CachedProfile,
    $$CachedProfilesTableFilterComposer,
    $$CachedProfilesTableOrderingComposer,
    $$CachedProfilesTableCreateCompanionBuilder,
    $$CachedProfilesTableUpdateCompanionBuilder,
    (
      CachedProfile,
      BaseReferences<_$ProfileCache, $CachedProfilesTable, CachedProfile>
    ),
    CachedProfile,
    PrefetchHooks Function()> {
  $$CachedProfilesTableTableManager(
      _$ProfileCache db, $CachedProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CachedProfilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CachedProfilesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> accountId = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> username = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProfilesCompanion(
            accountId: accountId,
            displayName: displayName,
            username: username,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String accountId,
            Value<String?> displayName = const Value.absent(),
            Value<String?> username = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProfilesCompanion.insert(
            accountId: accountId,
            displayName: displayName,
            username: username,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedProfilesTableProcessedTableManager = ProcessedTableManager<
    _$ProfileCache,
    $CachedProfilesTable,
    CachedProfile,
    $$CachedProfilesTableFilterComposer,
    $$CachedProfilesTableOrderingComposer,
    $$CachedProfilesTableCreateCompanionBuilder,
    $$CachedProfilesTableUpdateCompanionBuilder,
    (
      CachedProfile,
      BaseReferences<_$ProfileCache, $CachedProfilesTable, CachedProfile>
    ),
    CachedProfile,
    PrefetchHooks Function()>;

class $ProfileCacheManager {
  final _$ProfileCache _db;
  $ProfileCacheManager(this._db);
  $$CachedProfilesTableTableManager get cachedProfiles =>
      $$CachedProfilesTableTableManager(_db, _db.cachedProfiles);
}
