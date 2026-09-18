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
    this.folderId,
    this.locked = false,
    this.passphraseHash,
    this.passphraseSalt,
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

  /// 所属目录；为空表示未分类。
  final String? folderId;

  /// 是否加锁。锁只是界面层的一道门，正文始终是明文。
  final bool locked;
  final String? passphraseHash;
  final String? passphraseSalt;

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
    String? folderId,
    bool clearFolderId = false,
    bool? locked,
    String? passphraseHash,
    String? passphraseSalt,
    bool clearPassphrase = false,
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
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      locked: locked ?? this.locked,
      passphraseHash: clearPassphrase
          ? null
          : (passphraseHash ?? this.passphraseHash),
      passphraseSalt: clearPassphrase
          ? null
          : (passphraseSalt ?? this.passphraseSalt),
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      dirty: dirty ?? this.dirty,
      isNew: isNew ?? this.isNew,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    );
  }

  @override
  String toString() =>
      'LocalNote($id, v$version/base$baseVersion, folder=$folderId, '
      'locked=$locked, dirty=$dirty, isNew=$isNew, deleted=$isDeleted)';
}

/// 本地库里的一个目录。同步状态的含义与笔记一致。
class LocalFolder {
  const LocalFolder({
    required this.id,
    required this.name,
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
  final String name;
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

  LocalFolder copyWith({
    String? name,
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
    return LocalFolder(
      id: id,
      name: name ?? this.name,
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
      'LocalFolder($id, $name, v$version/base$baseVersion, '
      'dirty=$dirty, isNew=$isNew, deleted=$isDeleted)';
}

/// 本地库里的图片元数据。文件本体存在本机 `images/<id>.jpg`。
///
/// 图片内容不可变，所以没有版本号；[dirty] 表示文件还没传上服务端。
class LocalImage {
  const LocalImage({
    required this.id,
    required this.storagePath,
    required this.byteSize,
    required this.createdAt,
    required this.updatedAt,
    this.width,
    this.height,
    this.deletedAt,
    this.dirty = true,
  });

  final String id;
  final String storagePath;
  final int byteSize;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;

  bool get isDeleted => deletedAt != null;

  LocalImage copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? dirty,
  }) {
    return LocalImage(
      id: id,
      storagePath: storagePath,
      byteSize: byteSize,
      width: width,
      height: height,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  String toString() =>
      'LocalImage($id, $storagePath, $byteSize bytes, deleted=$isDeleted)';
}

/// 本地存储的抽象。
///
/// 同步引擎只依赖这个接口，真实实现是 SQLite（drift），
/// 测试里换成纯内存实现即可，不需要拉起数据库。
abstract class LocalStore {
  // --- 笔记：界面读取 ---

  /// 按更新时间倒序推送未删除的全部笔记。按目录过滤交给界面层做。
  Stream<List<LocalNote>> watchVisibleNotes();

  Future<List<LocalNote>> allVisibleNotes();

  Future<LocalNote?> findById(String id);

  // --- 目录：界面读取 ---

  /// 按创建时间正序推送未删除的目录。
  Stream<List<LocalFolder>> watchVisibleFolders();

  Future<LocalFolder?> findFolderById(String id);

  // --- 本地编辑（由界面层调用） ---

  Future<void> createNote(LocalNote note);

  Future<void> updateBody({
    required String id,
    required String body,
    required DateTime now,
  });

  Future<void> softDelete({required String id, required DateTime now});

  /// 撤销删除：把软删除标记清掉。
  Future<void> restore({required String id, required DateTime now});

  Future<void> setNoteFolder({
    required String id,
    required String? folderId,
    required DateTime now,
  });

  /// 设置或清除加锁状态。清除时 [hash] 和 [salt] 传空。
  Future<void> setNoteLock({
    required String id,
    required bool locked,
    required String? hash,
    required String? salt,
    required DateTime now,
  });

  Future<void> createFolder(LocalFolder folder);

  Future<void> renameFolder({
    required String id,
    required String name,
    required DateTime now,
  });

  Future<void> softDeleteFolder({required String id, required DateTime now});

  Future<void> createImage(LocalImage image);

  Future<void> softDeleteImage({required String id, required DateTime now});

  // --- 图片文件本体（存在应用目录的 images/ 下） ---

  /// 图片在本机的完整路径。文件可能还不存在。
  Future<String> imageFilePath(String id);

  Future<bool> imageFileExists(String id);

  Future<void> writeImageFile(String id, List<int> bytes);

  Future<List<int>?> readImageFile(String id);

  Future<void> deleteImageFile(String id);

  // --- 同步过程：读取待推送 ---

  /// 待推送的笔记，按本地修改时间升序（先改的先推）。
  Future<List<LocalNote>> pendingNotes();

  Future<List<LocalFolder>> pendingFolders();

  Future<List<LocalImage>> pendingImages();

  /// 全部未删除的图片，供清理孤儿图使用。
  Future<List<LocalImage>> allImages();

  /// 已标记删除的图片，供回收文件本体使用。
  Future<List<LocalImage>> deletedImages();

  Future<LocalImage?> findImageById(String id);

  Future<int> pendingCount();

  // --- 同步过程：水位 ---

  Future<DateTime?> getLastPulledAt();
  Future<void> setLastPulledAt(DateTime value);

  Future<DateTime?> getFoldersPulledAt();
  Future<void> setFoldersPulledAt(DateTime value);

  Future<DateTime?> getImagesPulledAt();
  Future<void> setImagesPulledAt(DateTime value);

  /// 本机标识，写入服务端后用于过滤实时推送里的自身回显。
  Future<String> deviceId();

  // --- 同步过程：回写 ---

  /// 用服务端快照覆盖本地（含删除状态），并清除脏标记。
  Future<void> applyRemote(RemoteNote note);

  Future<void> applyRemoteFolder(RemoteFolder folder);

  Future<void> applyRemoteImage(RemoteImage image);

  /// 服务端已不存在这条记录（被其他设备硬删），本地也清掉。
  Future<void> hardDelete(String id);

  Future<void> hardDeleteFolder(String id);

  Future<void> hardDeleteImage(String id);
}
