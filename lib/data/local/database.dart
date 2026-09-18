import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 本地笔记镜像。字段与服务端一一对应，另外多了同步状态：
/// [baseVersion] 记录上次同步成功时的服务端版本号，[dirty] / [isNew] 标记待推送。
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get baseVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isNew => boolean().withDefault(const Constant(false))();
  TextColumn get lastDeviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同步用的零碎状态：本机标识、上次拉取到的服务端时间水位。
class SyncMetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Notes, SyncMetaEntries])
class AppDatabase extends _$AppDatabase {
  /// 数据库文件按账号分开，换账号登录时不会看到上一个账号的笔记。
  AppDatabase([String name = 'sync_notes'])
    : super(driftDatabase(name: name));

  @override
  int get schemaVersion => 1;
}
