import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 本地笔记镜像。字段与服务端一一对应，另外多了同步状态：
/// [baseVersion] 记录上次同步成功时的服务端版本号，[dirty] / [isNew] 标记待推送。
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// 所属目录，空表示未分类。
  TextColumn get folderId => text().nullable()();

  /// 加锁标记与口令摘要。锁只是界面层的一道门，正文始终是明文。
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  TextColumn get passphraseHash => text().nullable()();
  TextColumn get passphraseSalt => text().nullable()();

  /// 置顶。纯粹是本机的偏好：不参与同步，也不影响 updated_at。
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

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

/// 本地目录镜像。同步状态的含义与笔记一致。
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant('新目录'))();
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

/// 本地图片元数据。文件本体在应用目录的 `images/<id>.jpg`。
///
/// 图片内容不可变，所以没有版本号：只要有 [dirty] 就说明文件还没传上去。
class NoteImages extends Table {
  TextColumn get id => text()();
  TextColumn get storagePath => text()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地手写画布。笔迹本身是归一化坐标的 JSON，不占多少空间，
/// 直接存在这一列里，不必像图片那样单独放存储桶。
class NoteInks extends Table {
  TextColumn get id => text()();
  TextColumn get strokes => text().withDefault(const Constant('[]'))();
  IntColumn get canvasWidth => integer().withDefault(const Constant(1000))();
  IntColumn get canvasHeight => integer().withDefault(const Constant(1400))();
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

/// 同步用的零碎状态：本机标识、三张表各自的拉取水位。
class SyncMetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Notes, Folders, NoteImages, NoteInks, SyncMetaEntries])
class AppDatabase extends _$AppDatabase {
  /// 数据库文件按账号分开，换账号登录时不会看到上一个账号的笔记。
  AppDatabase([String name = 'sync_notes'])
    : super(driftDatabase(name: name));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 从 v1 升到 v2：加目录、图片两张表，以及笔记上的目录归属和加锁字段。
      // 这里刻意不做任何删除动作——升级失败就直接抛错，
      // 让用户看到问题，而不是悄悄把已有笔记抹掉。
      if (from < 2) {
        await m.createTable(folders);
        await m.createTable(noteImages);
        await m.addColumn(notes, notes.folderId);
        await m.addColumn(notes, notes.locked);
        await m.addColumn(notes, notes.passphraseHash);
        await m.addColumn(notes, notes.passphraseSalt);
      }
      // v2 → v3：加手写画布。
      if (from < 3) {
        await m.createTable(noteInks);
      }
      // v3 → v4：加「置顶」。只加一列，不动任何已有数据。
      if (from < 4) {
        await m.addColumn(notes, notes.pinned);
      }
    },
  );
}
