import '../models.dart';

/// 推送一篇笔记时要写上去的字段。
///
/// 单独包一层是为了让接口签名不至于越加越长：以后再加字段只改这里。
class NotePayload {
  const NotePayload({
    required this.body,
    this.folderId,
    this.locked = false,
    this.passphraseHash,
    this.passphraseSalt,
  });

  final String body;
  final String? folderId;
  final bool locked;
  final String? passphraseHash;
  final String? passphraseSalt;
}

/// 远端接口。真实实现走 Supabase，测试里用内存假实现。
abstract class RemoteApi {
  // --- 笔记 ---

  /// 拉取 [since] 之后有变化的笔记；[since] 为空表示全量。
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since);

  Future<RemoteNote?> fetchById(String id);

  Future<RemoteNote> insert({
    required String id,
    required NotePayload payload,
    String? lastDeviceId,
  });

  /// 乐观锁更新：仅当服务端版本号等于 [expectedVersion] 时写入。
  ///
  /// 返回 null 表示版本不匹配（期间被别的设备改过），调用方按冲突处理。
  Future<RemoteNote?> updateIfVersion({
    required String id,
    required NotePayload payload,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  });

  // --- 目录 ---

  Future<List<RemoteFolder>> fetchFoldersChangedSince(DateTime? since);

  Future<RemoteFolder?> fetchFolderById(String id);

  Future<RemoteFolder> insertFolder({
    required String id,
    required String name,
    String? lastDeviceId,
  });

  Future<RemoteFolder?> updateFolderIfVersion({
    required String id,
    required String name,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  });

  // --- 图片 ---

  Future<List<RemoteImage>> fetchImagesChangedSince(DateTime? since);

  /// 图片行不可变，按 id upsert 即可，不需要乐观锁。
  Future<RemoteImage> upsertImage({
    required String id,
    required String storagePath,
    required int byteSize,
    int? width,
    int? height,
    DateTime? deletedAt,
  });

  /// 把图片字节传到存储桶。失败抛 [RemoteApiException]。
  Future<void> uploadImage(String storagePath, List<int> bytes);

  /// 从存储桶下载图片字节。
  Future<List<int>> downloadImage(String storagePath);

  /// 从存储桶彻底删掉一个对象（清理孤儿图时用）。
  Future<void> deleteImageObject(String storagePath);

  // --- 实时 ---

  /// 笔记的实时变更流。事件可能来自本机，调用方负责过滤。
  Stream<RemoteNote> watchChanges();

  /// 目录的实时变更流。
  Stream<RemoteFolder> watchFolderChanges();

  Future<void> dispose();
}

class RemoteApiException implements Exception {
  const RemoteApiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'RemoteApiException: $message${cause == null ? '' : ' ($cause)'}';
}
