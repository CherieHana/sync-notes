import '../models.dart';

/// 本地库里的一条笔记。
///
/// 与服务端快照的区别在于多了三样同步状态：
///
/// - [baseVersion]：上次同步成功时服务端给的版本号，推送时用作乐观锁条件
/// - [dirty]：本地有改动尚未推送到服务端
/// - [isNew]：服务端还不存在这条记录
class LocalNote {
  const LocalNote({
    required this.id,
    required this.body,
    required this.version,
    required this.baseVersion,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    this.deletedAt,
    this.dirty = true,
    this.isNew = false,
    this.lastDeviceId,
  });

  final String id;
  final String body;
  final int version;
  final int baseVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final bool isNew;
  final String? lastDeviceId;

  bool get isDeleted => deletedAt != null;

  LocalNote copyWith({
    String? body,
    int? version,
    int? baseVersion,
    DateTime? updatedAt,
    DateTime? serverUpdatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? dirty,
    bool? isNew,
    String? lastDeviceId,
  }) {
    return LocalNote(
      id: id,
      body: body ?? this.body,
      version: version ?? this.version,
      baseVersion: baseVersion ?? this.baseVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      dirty: dirty ?? this.dirty,
      isNew: isNew ?? this.isNew,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    );
  }

  @override
  String toString() =>
      'LocalNote($id, v$version/base$baseVersion, dirty=$dirty, '
      'isNew=$isNew, deleted=$isDeleted)';
}

/// 本地存储的抽象。
///
/// 同步引擎只依赖这个接口，真实实现是 SQLite（drift），
/// 测试里换成纯内存实现即可，不需要拉起数据库。
abstract class LocalStore {
  /// 界面用：按更新时间倒序推送未删除的笔记。
  Stream<List<LocalNote>> watchVisibleNotes();

  Future<LocalNote?> findById(String id);

  /// 待推送的笔记，按本地修改时间升序（先改的先推）。
  Future<List<LocalNote>> pendingNotes();

  Future<int> pendingCount();

  Future<DateTime?> getLastPulledAt();

  Future<void> setLastPulledAt(DateTime value);

  /// 本机标识，写入服务端后用于过滤实时推送里的自身回显。
  Future<String> deviceId();

  // --- 本地编辑（由界面层调用） ---

  Future<void> createNote(LocalNote note);

  Future<void> updateBody({
    required String id,
    required String body,
    required DateTime now,
  });

  Future<void> softDelete({required String id, required DateTime now});

  // --- 同步过程回写 ---

  /// 用服务端快照覆盖本地（含删除状态），并清除脏标记。
  Future<void> applyRemote(RemoteNote note);

  /// 服务端已不存在这条记录（被其他设备硬删），本地也清掉。
  Future<void> hardDelete(String id);
}
