/// 服务端快照的公共部分。
///
/// 所有时间均由服务端给出，客户端只做解析、不参与生成，
/// 这样多设备之间的时间线才是可比较的。
DateTime? parseServerTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.parse(value as String).toUtc();
}

/// 服务端一条笔记的快照。
class RemoteNote {
  const RemoteNote({
    required this.id,
    required this.body,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.locked = false,
    this.passphraseHash,
    this.passphraseSalt,
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

  /// 所属目录；为空表示「未分类」，指向已被删除的目录时客户端也按未分类显示。
  final String? folderId;

  /// 是否加锁。锁只是界面层的一道门，正文在服务端始终是明文。
  final bool locked;
  final String? passphraseHash;
  final String? passphraseSalt;

  final DateTime? deletedAt;
  final String? lastDeviceId;

  bool get isDeleted => deletedAt != null;

  factory RemoteNote.fromJson(Map<String, dynamic> json) {
    return RemoteNote(
      id: json['id'] as String,
      body: (json['body'] as String?) ?? '',
      version: (json['version'] as num).toInt(),
      createdAt: parseServerTime(json['created_at'])!,
      updatedAt: parseServerTime(json['updated_at'])!,
      folderId: json['folder_id'] as String?,
      locked: (json['locked'] as bool?) ?? false,
      passphraseHash: json['passphrase_hash'] as String?,
      passphraseSalt: json['passphrase_salt'] as String?,
      deletedAt: parseServerTime(json['deleted_at']),
      lastDeviceId: json['last_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'folder_id': folderId,
    'locked': locked,
    'passphrase_hash': passphraseHash,
    'passphrase_salt': passphraseSalt,
    'deleted_at': deletedAt?.toIso8601String(),
    'last_device_id': lastDeviceId,
  };

  @override
  String toString() =>
      'RemoteNote($id, v$version, folder=$folderId, locked=$locked, '
      'deleted=$isDeleted, by=$lastDeviceId)';
}

/// 服务端一个目录的快照。字段与同步语义和笔记完全一致。
class RemoteFolder {
  const RemoteFolder({
    required this.id,
    required this.name,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.lastDeviceId,
  });

  final String id;
  final String name;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? lastDeviceId;

  bool get isDeleted => deletedAt != null;

  factory RemoteFolder.fromJson(Map<String, dynamic> json) {
    return RemoteFolder(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '未命名目录',
      version: (json['version'] as num).toInt(),
      createdAt: parseServerTime(json['created_at'])!,
      updatedAt: parseServerTime(json['updated_at'])!,
      deletedAt: parseServerTime(json['deleted_at']),
      lastDeviceId: json['last_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'last_device_id': lastDeviceId,
  };

  @override
  String toString() => 'RemoteFolder($id, $name, v$version)';
}

/// 服务端一张图片的元数据快照。文件本体在存储桶里。
class RemoteImage {
  const RemoteImage({
    required this.id,
    required this.storagePath,
    required this.byteSize,
    required this.createdAt,
    required this.updatedAt,
    this.width,
    this.height,
    this.deletedAt,
  });

  final String id;
  final String storagePath;
  final int byteSize;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory RemoteImage.fromJson(Map<String, dynamic> json) {
    return RemoteImage(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      createdAt: parseServerTime(json['created_at'])!,
      updatedAt: parseServerTime(json['updated_at'])!,
      deletedAt: parseServerTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storage_path': storagePath,
    'byte_size': byteSize,
    'width': width,
    'height': height,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  @override
  String toString() => 'RemoteImage($id, $storagePath, $byteSize bytes)';
}

/// 服务端一块手写画布的快照。
///
/// 笔迹存成归一化坐标（0~1，相对画布），手机和电脑显示尺寸差很多也不会错位。
class RemoteInk {
  const RemoteInk({
    required this.id,
    required this.strokes,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.lastDeviceId,
  });

  final String id;

  /// 笔迹数据，JSON 数组字符串。见 `InkStroke`。
  final String strokes;

  /// 画布的原始比例，只用来算显示尺寸，笔迹本身是归一化的。
  final int canvasWidth;
  final int canvasHeight;

  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? lastDeviceId;

  bool get isDeleted => deletedAt != null;

  double get aspectRatio => canvasHeight <= 0
      ? 3 / 4
      : canvasWidth / canvasHeight;

  factory RemoteInk.fromJson(Map<String, dynamic> json) {
    return RemoteInk(
      id: json['id'] as String,
      strokes: (json['strokes'] as String?) ?? '[]',
      canvasWidth: (json['canvas_width'] as num?)?.toInt() ?? 1000,
      canvasHeight: (json['canvas_height'] as num?)?.toInt() ?? 1400,
      version: (json['version'] as num).toInt(),
      createdAt: parseServerTime(json['created_at'])!,
      updatedAt: parseServerTime(json['updated_at'])!,
      deletedAt: parseServerTime(json['deleted_at']),
      lastDeviceId: json['last_device_id'] as String?,
    );
  }

  @override
  String toString() => 'RemoteInk($id, v$version, deleted=$isDeleted)';
}
