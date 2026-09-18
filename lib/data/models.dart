/// 服务端一条笔记的快照。
///
/// 所有时间均由服务端给出，客户端只做解析，不参与生成，
/// 这样多设备之间的时间线才是可比较的。
class RemoteNote {
  const RemoteNote({
    required this.id,
    required this.body,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.lastDeviceId,
  });

  final String id;
  final String body;

  /// 乐观锁版本号。每次成功写入由客户端递增加一，
  /// 并发控制依赖服务端 `where version = 期望值` 实现。
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? lastDeviceId;

  bool get isDeleted => deletedAt != null;

  factory RemoteNote.fromJson(Map<String, dynamic> json) {
    return RemoteNote(
      id: json['id'] as String,
      body: (json['body'] as String?) ?? '',
      version: (json['version'] as num).toInt(),
      createdAt: _parse(json['created_at'])!,
      updatedAt: _parse(json['updated_at'])!,
      deletedAt: _parse(json['deleted_at']),
      lastDeviceId: json['last_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'last_device_id': lastDeviceId,
  };

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.parse(value as String).toUtc();
  }

  @override
  String toString() =>
      'RemoteNote($id, v$version, deleted=$isDeleted, by=$lastDeviceId)';
}
