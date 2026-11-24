import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'profile_cache.g.dart';

class CachedProfiles extends Table {
  TextColumn get accountId => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get username => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

@DriftDatabase(tables: [CachedProfiles])
class ProfileCache extends _$ProfileCache {
  ProfileCache()
      : super(LazyDatabase(() async {
          final home = await getApplicationSupportDirectory();
          return NativeDatabase.createInBackground(
              File('${home.path}/hasta.sqlite'));
        }));

  ProfileCache.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<CachedProfile?> load(String id) =>
      (select(cachedProfiles)..where((row) => row.accountId.equals(id)))
          .getSingleOrNull();

  Future<void> store(CachedProfile profile) => transaction(() async {
        await delete(cachedProfiles).go();
        await into(cachedProfiles).insert(profile);
      });

  Future<void> clear() async {
    await delete(cachedProfiles).go();
  }
}
