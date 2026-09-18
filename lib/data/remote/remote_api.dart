import '../models.dart';

/// 远端接口。真实实现走 Supabase，测试里用内存假实现。
abstract class RemoteApi {
  /// 拉取 [since] 之后有变化的笔记；[since] 为空表示全量。
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since);

  Future<RemoteNote?> fetchById(String id);

  Future<RemoteNote> insert({
    required String id,
    required String body,
    String? lastDeviceId,
  });

  /// 乐观锁更新：仅当服务端版本号等于 [expectedVersion] 时写入。
  ///
  /// 返回 null 表示版本不匹配（期间被别的设备改过），调用方按冲突处理。
  Future<RemoteNote?> updateIfVersion({
    required String id,
    required String body,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  });

  /// 实时变更流。事件里的笔记可能来自本机，调用方负责过滤。
  Stream<RemoteNote> watchChanges();

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
