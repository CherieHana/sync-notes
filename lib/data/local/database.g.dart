// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _passphraseHashMeta = const VerificationMeta(
    'passphraseHash',
  );
  @override
  late final GeneratedColumn<String> passphraseHash = GeneratedColumn<String>(
    'passphrase_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passphraseSaltMeta = const VerificationMeta(
    'passphraseSalt',
  );
  @override
  late final GeneratedColumn<String> passphraseSalt = GeneratedColumn<String>(
    'passphrase_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastDeviceIdMeta = const VerificationMeta(
    'lastDeviceId',
  );
  @override
  late final GeneratedColumn<String> lastDeviceId = GeneratedColumn<String>(
    'last_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    body,
    folderId,
    locked,
    passphraseHash,
    passphraseSalt,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('passphrase_hash')) {
      context.handle(
        _passphraseHashMeta,
        passphraseHash.isAcceptableOrUnknown(
          data['passphrase_hash']!,
          _passphraseHashMeta,
        ),
      );
    }
    if (data.containsKey('passphrase_salt')) {
      context.handle(
        _passphraseSaltMeta,
        passphraseSalt.isAcceptableOrUnknown(
          data['passphrase_salt']!,
          _passphraseSaltMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('last_device_id')) {
      context.handle(
        _lastDeviceIdMeta,
        lastDeviceId.isAcceptableOrUnknown(
          data['last_device_id']!,
          _lastDeviceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      passphraseHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passphrase_hash'],
      ),
      passphraseSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passphrase_salt'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      lastDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_device_id'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String body;

  /// 所属目录，空表示未分类。
  final String? folderId;

  /// 加锁标记与口令摘要。锁只是界面层的一道门，正文始终是明文。
  final bool locked;
  final String? passphraseHash;
  final String? passphraseSalt;
  final int version;
  final int baseVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final bool isNew;
  final String? lastDeviceId;
  const Note({
    required this.id,
    required this.body,
    this.folderId,
    required this.locked,
    this.passphraseHash,
    this.passphraseSalt,
    required this.version,
    required this.baseVersion,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    this.deletedAt,
    required this.dirty,
    required this.isNew,
    this.lastDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['locked'] = Variable<bool>(locked);
    if (!nullToAbsent || passphraseHash != null) {
      map['passphrase_hash'] = Variable<String>(passphraseHash);
    }
    if (!nullToAbsent || passphraseSalt != null) {
      map['passphrase_salt'] = Variable<String>(passphraseSalt);
    }
    map['version'] = Variable<int>(version);
    map['base_version'] = Variable<int>(baseVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['is_new'] = Variable<bool>(isNew);
    if (!nullToAbsent || lastDeviceId != null) {
      map['last_device_id'] = Variable<String>(lastDeviceId);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      body: Value(body),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      locked: Value(locked),
      passphraseHash: passphraseHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passphraseHash),
      passphraseSalt: passphraseSalt == null && nullToAbsent
          ? const Value.absent()
          : Value(passphraseSalt),
      version: Value(version),
      baseVersion: Value(baseVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      isNew: Value(isNew),
      lastDeviceId: lastDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeviceId),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      locked: serializer.fromJson<bool>(json['locked']),
      passphraseHash: serializer.fromJson<String?>(json['passphraseHash']),
      passphraseSalt: serializer.fromJson<String?>(json['passphraseSalt']),
      version: serializer.fromJson<int>(json['version']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      lastDeviceId: serializer.fromJson<String?>(json['lastDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'body': serializer.toJson<String>(body),
      'folderId': serializer.toJson<String?>(folderId),
      'locked': serializer.toJson<bool>(locked),
      'passphraseHash': serializer.toJson<String?>(passphraseHash),
      'passphraseSalt': serializer.toJson<String?>(passphraseSalt),
      'version': serializer.toJson<int>(version),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'isNew': serializer.toJson<bool>(isNew),
      'lastDeviceId': serializer.toJson<String?>(lastDeviceId),
    };
  }

  Note copyWith({
    String? id,
    String? body,
    Value<String?> folderId = const Value.absent(),
    bool? locked,
    Value<String?> passphraseHash = const Value.absent(),
    Value<String?> passphraseSalt = const Value.absent(),
    int? version,
    int? baseVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    bool? isNew,
    Value<String?> lastDeviceId = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    body: body ?? this.body,
    folderId: folderId.present ? folderId.value : this.folderId,
    locked: locked ?? this.locked,
    passphraseHash: passphraseHash.present
        ? passphraseHash.value
        : this.passphraseHash,
    passphraseSalt: passphraseSalt.present
        ? passphraseSalt.value
        : this.passphraseSalt,
    version: version ?? this.version,
    baseVersion: baseVersion ?? this.baseVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    isNew: isNew ?? this.isNew,
    lastDeviceId: lastDeviceId.present ? lastDeviceId.value : this.lastDeviceId,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      locked: data.locked.present ? data.locked.value : this.locked,
      passphraseHash: data.passphraseHash.present
          ? data.passphraseHash.value
          : this.passphraseHash,
      passphraseSalt: data.passphraseSalt.present
          ? data.passphraseSalt.value
          : this.passphraseSalt,
      version: data.version.present ? data.version.value : this.version,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      lastDeviceId: data.lastDeviceId.present
          ? data.lastDeviceId.value
          : this.lastDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('folderId: $folderId, ')
          ..write('locked: $locked, ')
          ..write('passphraseHash: $passphraseHash, ')
          ..write('passphraseSalt: $passphraseSalt, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    body,
    folderId,
    locked,
    passphraseHash,
    passphraseSalt,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.body == this.body &&
          other.folderId == this.folderId &&
          other.locked == this.locked &&
          other.passphraseHash == this.passphraseHash &&
          other.passphraseSalt == this.passphraseSalt &&
          other.version == this.version &&
          other.baseVersion == this.baseVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.isNew == this.isNew &&
          other.lastDeviceId == this.lastDeviceId);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> body;
  final Value<String?> folderId;
  final Value<bool> locked;
  final Value<String?> passphraseHash;
  final Value<String?> passphraseSalt;
  final Value<int> version;
  final Value<int> baseVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<bool> isNew;
  final Value<String?> lastDeviceId;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.folderId = const Value.absent(),
    this.locked = const Value.absent(),
    this.passphraseHash = const Value.absent(),
    this.passphraseSalt = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    this.body = const Value.absent(),
    this.folderId = const Value.absent(),
    this.locked = const Value.absent(),
    this.passphraseHash = const Value.absent(),
    this.passphraseSalt = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<String>? folderId,
    Expression<bool>? locked,
    Expression<String>? passphraseHash,
    Expression<String>? passphraseSalt,
    Expression<int>? version,
    Expression<int>? baseVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<bool>? isNew,
    Expression<String>? lastDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (folderId != null) 'folder_id': folderId,
      if (locked != null) 'locked': locked,
      if (passphraseHash != null) 'passphrase_hash': passphraseHash,
      if (passphraseSalt != null) 'passphrase_salt': passphraseSalt,
      if (version != null) 'version': version,
      if (baseVersion != null) 'base_version': baseVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (isNew != null) 'is_new': isNew,
      if (lastDeviceId != null) 'last_device_id': lastDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<String?>? folderId,
    Value<bool>? locked,
    Value<String?>? passphraseHash,
    Value<String?>? passphraseSalt,
    Value<int>? version,
    Value<int>? baseVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<bool>? isNew,
    Value<String?>? lastDeviceId,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      folderId: folderId ?? this.folderId,
      locked: locked ?? this.locked,
      passphraseHash: passphraseHash ?? this.passphraseHash,
      passphraseSalt: passphraseSalt ?? this.passphraseSalt,
      version: version ?? this.version,
      baseVersion: baseVersion ?? this.baseVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      isNew: isNew ?? this.isNew,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (passphraseHash.present) {
      map['passphrase_hash'] = Variable<String>(passphraseHash.value);
    }
    if (passphraseSalt.present) {
      map['passphrase_salt'] = Variable<String>(passphraseSalt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (lastDeviceId.present) {
      map['last_device_id'] = Variable<String>(lastDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('folderId: $folderId, ')
          ..write('locked: $locked, ')
          ..write('passphraseHash: $passphraseHash, ')
          ..write('passphraseSalt: $passphraseSalt, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('新目录'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastDeviceIdMeta = const VerificationMeta(
    'lastDeviceId',
  );
  @override
  late final GeneratedColumn<String> lastDeviceId = GeneratedColumn<String>(
    'last_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('last_device_id')) {
      context.handle(
        _lastDeviceIdMeta,
        lastDeviceId.isAcceptableOrUnknown(
          data['last_device_id']!,
          _lastDeviceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      lastDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_device_id'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
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
  const Folder({
    required this.id,
    required this.name,
    required this.version,
    required this.baseVersion,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    this.deletedAt,
    required this.dirty,
    required this.isNew,
    this.lastDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<int>(version);
    map['base_version'] = Variable<int>(baseVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['is_new'] = Variable<bool>(isNew);
    if (!nullToAbsent || lastDeviceId != null) {
      map['last_device_id'] = Variable<String>(lastDeviceId);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      version: Value(version),
      baseVersion: Value(baseVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      isNew: Value(isNew),
      lastDeviceId: lastDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeviceId),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<int>(json['version']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      lastDeviceId: serializer.fromJson<String?>(json['lastDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<int>(version),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'isNew': serializer.toJson<bool>(isNew),
      'lastDeviceId': serializer.toJson<String?>(lastDeviceId),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    int? version,
    int? baseVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    bool? isNew,
    Value<String?> lastDeviceId = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    version: version ?? this.version,
    baseVersion: baseVersion ?? this.baseVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    isNew: isNew ?? this.isNew,
    lastDeviceId: lastDeviceId.present ? lastDeviceId.value : this.lastDeviceId,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      lastDeviceId: data.lastDeviceId.present
          ? data.lastDeviceId.value
          : this.lastDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.version == this.version &&
          other.baseVersion == this.baseVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.isNew == this.isNew &&
          other.lastDeviceId == this.lastDeviceId);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> version;
  final Value<int> baseVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<bool> isNew;
  final Value<String?> lastDeviceId;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? version,
    Expression<int>? baseVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<bool>? isNew,
    Expression<String>? lastDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (baseVersion != null) 'base_version': baseVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (isNew != null) 'is_new': isNew,
      if (lastDeviceId != null) 'last_device_id': lastDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? version,
    Value<int>? baseVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<bool>? isNew,
    Value<String?>? lastDeviceId,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      baseVersion: baseVersion ?? this.baseVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      isNew: isNew ?? this.isNew,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (lastDeviceId.present) {
      map['last_device_id'] = Variable<String>(lastDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteImagesTable extends NoteImages
    with TableInfo<$NoteImagesTable, NoteImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storagePath,
    byteSize,
    width,
    height,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storagePathMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $NoteImagesTable createAlias(String alias) {
    return $NoteImagesTable(attachedDatabase, alias);
  }
}

class NoteImage extends DataClass implements Insertable<NoteImage> {
  final String id;
  final String storagePath;
  final int byteSize;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  const NoteImage({
    required this.id,
    required this.storagePath,
    required this.byteSize,
    this.width,
    this.height,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['storage_path'] = Variable<String>(storagePath);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  NoteImagesCompanion toCompanion(bool nullToAbsent) {
    return NoteImagesCompanion(
      id: Value(id),
      storagePath: Value(storagePath),
      byteSize: Value(byteSize),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
    );
  }

  factory NoteImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteImage(
      id: serializer.fromJson<String>(json['id']),
      storagePath: serializer.fromJson<String>(json['storagePath']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storagePath': serializer.toJson<String>(storagePath),
      'byteSize': serializer.toJson<int>(byteSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  NoteImage copyWith({
    String? id,
    String? storagePath,
    int? byteSize,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
  }) => NoteImage(
    id: id ?? this.id,
    storagePath: storagePath ?? this.storagePath,
    byteSize: byteSize ?? this.byteSize,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
  );
  NoteImage copyWithCompanion(NoteImagesCompanion data) {
    return NoteImage(
      id: data.id.present ? data.id.value : this.id,
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteImage(')
          ..write('id: $id, ')
          ..write('storagePath: $storagePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storagePath,
    byteSize,
    width,
    height,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteImage &&
          other.id == this.id &&
          other.storagePath == this.storagePath &&
          other.byteSize == this.byteSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty);
}

class NoteImagesCompanion extends UpdateCompanion<NoteImage> {
  final Value<String> id;
  final Value<String> storagePath;
  final Value<int> byteSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const NoteImagesCompanion({
    this.id = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteImagesCompanion.insert({
    required String id,
    required String storagePath,
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storagePath = Value(storagePath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteImage> custom({
    Expression<String>? id,
    Expression<String>? storagePath,
    Expression<int>? byteSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storagePath != null) 'storage_path': storagePath,
      if (byteSize != null) 'byte_size': byteSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? storagePath,
    Value<int>? byteSize,
    Value<int?>? width,
    Value<int?>? height,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return NoteImagesCompanion(
      id: id ?? this.id,
      storagePath: storagePath ?? this.storagePath,
      byteSize: byteSize ?? this.byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteImagesCompanion(')
          ..write('id: $id, ')
          ..write('storagePath: $storagePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteInksTable extends NoteInks with TableInfo<$NoteInksTable, NoteInk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteInksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strokesMeta = const VerificationMeta(
    'strokes',
  );
  @override
  late final GeneratedColumn<String> strokes = GeneratedColumn<String>(
    'strokes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _canvasWidthMeta = const VerificationMeta(
    'canvasWidth',
  );
  @override
  late final GeneratedColumn<int> canvasWidth = GeneratedColumn<int>(
    'canvas_width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1000),
  );
  static const VerificationMeta _canvasHeightMeta = const VerificationMeta(
    'canvasHeight',
  );
  @override
  late final GeneratedColumn<int> canvasHeight = GeneratedColumn<int>(
    'canvas_height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1400),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastDeviceIdMeta = const VerificationMeta(
    'lastDeviceId',
  );
  @override
  late final GeneratedColumn<String> lastDeviceId = GeneratedColumn<String>(
    'last_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    strokes,
    canvasWidth,
    canvasHeight,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_inks';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteInk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('strokes')) {
      context.handle(
        _strokesMeta,
        strokes.isAcceptableOrUnknown(data['strokes']!, _strokesMeta),
      );
    }
    if (data.containsKey('canvas_width')) {
      context.handle(
        _canvasWidthMeta,
        canvasWidth.isAcceptableOrUnknown(
          data['canvas_width']!,
          _canvasWidthMeta,
        ),
      );
    }
    if (data.containsKey('canvas_height')) {
      context.handle(
        _canvasHeightMeta,
        canvasHeight.isAcceptableOrUnknown(
          data['canvas_height']!,
          _canvasHeightMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('last_device_id')) {
      context.handle(
        _lastDeviceIdMeta,
        lastDeviceId.isAcceptableOrUnknown(
          data['last_device_id']!,
          _lastDeviceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteInk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteInk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      strokes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strokes'],
      )!,
      canvasWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}canvas_width'],
      )!,
      canvasHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}canvas_height'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      lastDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_device_id'],
      ),
    );
  }

  @override
  $NoteInksTable createAlias(String alias) {
    return $NoteInksTable(attachedDatabase, alias);
  }
}

class NoteInk extends DataClass implements Insertable<NoteInk> {
  final String id;
  final String strokes;
  final int canvasWidth;
  final int canvasHeight;
  final int version;
  final int baseVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final bool isNew;
  final String? lastDeviceId;
  const NoteInk({
    required this.id,
    required this.strokes,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.version,
    required this.baseVersion,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    this.deletedAt,
    required this.dirty,
    required this.isNew,
    this.lastDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['strokes'] = Variable<String>(strokes);
    map['canvas_width'] = Variable<int>(canvasWidth);
    map['canvas_height'] = Variable<int>(canvasHeight);
    map['version'] = Variable<int>(version);
    map['base_version'] = Variable<int>(baseVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['is_new'] = Variable<bool>(isNew);
    if (!nullToAbsent || lastDeviceId != null) {
      map['last_device_id'] = Variable<String>(lastDeviceId);
    }
    return map;
  }

  NoteInksCompanion toCompanion(bool nullToAbsent) {
    return NoteInksCompanion(
      id: Value(id),
      strokes: Value(strokes),
      canvasWidth: Value(canvasWidth),
      canvasHeight: Value(canvasHeight),
      version: Value(version),
      baseVersion: Value(baseVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      isNew: Value(isNew),
      lastDeviceId: lastDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeviceId),
    );
  }

  factory NoteInk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteInk(
      id: serializer.fromJson<String>(json['id']),
      strokes: serializer.fromJson<String>(json['strokes']),
      canvasWidth: serializer.fromJson<int>(json['canvasWidth']),
      canvasHeight: serializer.fromJson<int>(json['canvasHeight']),
      version: serializer.fromJson<int>(json['version']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      lastDeviceId: serializer.fromJson<String?>(json['lastDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'strokes': serializer.toJson<String>(strokes),
      'canvasWidth': serializer.toJson<int>(canvasWidth),
      'canvasHeight': serializer.toJson<int>(canvasHeight),
      'version': serializer.toJson<int>(version),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'isNew': serializer.toJson<bool>(isNew),
      'lastDeviceId': serializer.toJson<String?>(lastDeviceId),
    };
  }

  NoteInk copyWith({
    String? id,
    String? strokes,
    int? canvasWidth,
    int? canvasHeight,
    int? version,
    int? baseVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    bool? isNew,
    Value<String?> lastDeviceId = const Value.absent(),
  }) => NoteInk(
    id: id ?? this.id,
    strokes: strokes ?? this.strokes,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
    version: version ?? this.version,
    baseVersion: baseVersion ?? this.baseVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    isNew: isNew ?? this.isNew,
    lastDeviceId: lastDeviceId.present ? lastDeviceId.value : this.lastDeviceId,
  );
  NoteInk copyWithCompanion(NoteInksCompanion data) {
    return NoteInk(
      id: data.id.present ? data.id.value : this.id,
      strokes: data.strokes.present ? data.strokes.value : this.strokes,
      canvasWidth: data.canvasWidth.present
          ? data.canvasWidth.value
          : this.canvasWidth,
      canvasHeight: data.canvasHeight.present
          ? data.canvasHeight.value
          : this.canvasHeight,
      version: data.version.present ? data.version.value : this.version,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      lastDeviceId: data.lastDeviceId.present
          ? data.lastDeviceId.value
          : this.lastDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteInk(')
          ..write('id: $id, ')
          ..write('strokes: $strokes, ')
          ..write('canvasWidth: $canvasWidth, ')
          ..write('canvasHeight: $canvasHeight, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    strokes,
    canvasWidth,
    canvasHeight,
    version,
    baseVersion,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deletedAt,
    dirty,
    isNew,
    lastDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteInk &&
          other.id == this.id &&
          other.strokes == this.strokes &&
          other.canvasWidth == this.canvasWidth &&
          other.canvasHeight == this.canvasHeight &&
          other.version == this.version &&
          other.baseVersion == this.baseVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.isNew == this.isNew &&
          other.lastDeviceId == this.lastDeviceId);
}

class NoteInksCompanion extends UpdateCompanion<NoteInk> {
  final Value<String> id;
  final Value<String> strokes;
  final Value<int> canvasWidth;
  final Value<int> canvasHeight;
  final Value<int> version;
  final Value<int> baseVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<bool> isNew;
  final Value<String?> lastDeviceId;
  final Value<int> rowid;
  const NoteInksCompanion({
    this.id = const Value.absent(),
    this.strokes = const Value.absent(),
    this.canvasWidth = const Value.absent(),
    this.canvasHeight = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteInksCompanion.insert({
    required String id,
    this.strokes = const Value.absent(),
    this.canvasWidth = const Value.absent(),
    this.canvasHeight = const Value.absent(),
    this.version = const Value.absent(),
    this.baseVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.serverUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.isNew = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteInk> custom({
    Expression<String>? id,
    Expression<String>? strokes,
    Expression<int>? canvasWidth,
    Expression<int>? canvasHeight,
    Expression<int>? version,
    Expression<int>? baseVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<bool>? isNew,
    Expression<String>? lastDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (strokes != null) 'strokes': strokes,
      if (canvasWidth != null) 'canvas_width': canvasWidth,
      if (canvasHeight != null) 'canvas_height': canvasHeight,
      if (version != null) 'version': version,
      if (baseVersion != null) 'base_version': baseVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (isNew != null) 'is_new': isNew,
      if (lastDeviceId != null) 'last_device_id': lastDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteInksCompanion copyWith({
    Value<String>? id,
    Value<String>? strokes,
    Value<int>? canvasWidth,
    Value<int>? canvasHeight,
    Value<int>? version,
    Value<int>? baseVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<bool>? isNew,
    Value<String?>? lastDeviceId,
    Value<int>? rowid,
  }) {
    return NoteInksCompanion(
      id: id ?? this.id,
      strokes: strokes ?? this.strokes,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      version: version ?? this.version,
      baseVersion: baseVersion ?? this.baseVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      isNew: isNew ?? this.isNew,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (strokes.present) {
      map['strokes'] = Variable<String>(strokes.value);
    }
    if (canvasWidth.present) {
      map['canvas_width'] = Variable<int>(canvasWidth.value);
    }
    if (canvasHeight.present) {
      map['canvas_height'] = Variable<int>(canvasHeight.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (lastDeviceId.present) {
      map['last_device_id'] = Variable<String>(lastDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteInksCompanion(')
          ..write('id: $id, ')
          ..write('strokes: $strokes, ')
          ..write('canvasWidth: $canvasWidth, ')
          ..write('canvasHeight: $canvasHeight, ')
          ..write('version: $version, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('isNew: $isNew, ')
          ..write('lastDeviceId: $lastDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaEntriesTable extends SyncMetaEntries
    with TableInfo<$SyncMetaEntriesTable, SyncMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaEntriesTable createAlias(String alias) {
    return $SyncMetaEntriesTable(attachedDatabase, alias);
  }
}

class SyncMetaEntry extends DataClass implements Insertable<SyncMetaEntry> {
  final String key;
  final String value;
  const SyncMetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaEntry copyWith({String? key, String? value}) =>
      SyncMetaEntry(key: key ?? this.key, value: value ?? this.value);
  SyncMetaEntry copyWithCompanion(SyncMetaEntriesCompanion data) {
    return SyncMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaEntriesCompanion extends UpdateCompanion<SyncMetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $NoteImagesTable noteImages = $NoteImagesTable(this);
  late final $NoteInksTable noteInks = $NoteInksTable(this);
  late final $SyncMetaEntriesTable syncMetaEntries = $SyncMetaEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notes,
    folders,
    noteImages,
    noteInks,
    syncMetaEntries,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String id,
  Value<String> body,
  Value<String?> folderId,
  Value<bool> locked,
  Value<String?> passphraseHash,
  Value<String?> passphraseSalt,
  Value<int> version,
  Value<int> baseVersion,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> id,
  Value<String> body,
  Value<String?> folderId,
  Value<bool> locked,
  Value<String?> passphraseHash,
  Value<String?> passphraseSalt,
  Value<int> version,
  Value<int> baseVersion,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passphraseHash => $composableBuilder(
    column: $table.passphraseHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passphraseSalt => $composableBuilder(
    column: $table.passphraseSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passphraseHash => $composableBuilder(
    column: $table.passphraseHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passphraseSalt => $composableBuilder(
    column: $table.passphraseSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<String> get passphraseHash => $composableBuilder(
    column: $table.passphraseHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passphraseSalt => $composableBuilder(
    column: $table.passphraseSalt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<String?> passphraseHash = const Value.absent(),
                Value<String?> passphraseSalt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                body: body,
                folderId: folderId,
                locked: locked,
                passphraseHash: passphraseHash,
                passphraseSalt: passphraseSalt,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> body = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<String?> passphraseHash = const Value.absent(),
                Value<String?> passphraseSalt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                body: body,
                folderId: folderId,
                locked: locked,
                passphraseHash: passphraseHash,
                passphraseSalt: passphraseSalt,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  BaseReferences<_$AppDatabase, $NotesTable, Note>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String id,
  Value<String> name,
  Value<int> version,
  Value<int> baseVersion,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> version,
  Value<int> baseVersion,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => column,
  );
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, Folder>(table),
                  BaseReferences<_$AppDatabase, $FoldersTable, Folder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$NoteImagesTableCreateCompanionBuilder = NoteImagesCompanion Function({
  required String id,
  required String storagePath,
  Value<int> byteSize,
  Value<int?> width,
  Value<int?> height,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<int> rowid,
});
typedef $$NoteImagesTableUpdateCompanionBuilder = NoteImagesCompanion Function({
  Value<String> id,
  Value<String> storagePath,
  Value<int> byteSize,
  Value<int?> width,
  Value<int?> height,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<int> rowid,
});

class $$NoteImagesTableFilterComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$NoteImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteImagesTable,
          NoteImage,
          $$NoteImagesTableFilterComposer,
          $$NoteImagesTableOrderingComposer,
          $$NoteImagesTableAnnotationComposer,
          $$NoteImagesTableCreateCompanionBuilder,
          $$NoteImagesTableUpdateCompanionBuilder,
          (
            NoteImage,
            BaseReferences<_$AppDatabase, $NoteImagesTable, NoteImage>,
          ),
          NoteImage,
          PrefetchHooks Function()
        > {
  $$NoteImagesTableTableManager(_$AppDatabase db, $NoteImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storagePath = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteImagesCompanion(
                id: id,
                storagePath: storagePath,
                byteSize: byteSize,
                width: width,
                height: height,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storagePath,
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteImagesCompanion.insert(
                id: id,
                storagePath: storagePath,
                byteSize: byteSize,
                width: width,
                height: height,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteImagesTable, NoteImage>(table),
                  BaseReferences<_$AppDatabase, $NoteImagesTable, NoteImage>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteImagesTable,
      NoteImage,
      $$NoteImagesTableFilterComposer,
      $$NoteImagesTableOrderingComposer,
      $$NoteImagesTableAnnotationComposer,
      $$NoteImagesTableCreateCompanionBuilder,
      $$NoteImagesTableUpdateCompanionBuilder,
      (NoteImage, BaseReferences<_$AppDatabase, $NoteImagesTable, NoteImage>),
      NoteImage,
      PrefetchHooks Function()
    >;
typedef $$NoteInksTableCreateCompanionBuilder = NoteInksCompanion Function({
  required String id,
  Value<String> strokes,
  Value<int> canvasWidth,
  Value<int> canvasHeight,
  Value<int> version,
  Value<int> baseVersion,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});
typedef $$NoteInksTableUpdateCompanionBuilder = NoteInksCompanion Function({
  Value<String> id,
  Value<String> strokes,
  Value<int> canvasWidth,
  Value<int> canvasHeight,
  Value<int> version,
  Value<int> baseVersion,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime?> deletedAt,
  Value<bool> dirty,
  Value<bool> isNew,
  Value<String?> lastDeviceId,
  Value<int> rowid,
});

class $$NoteInksTableFilterComposer
    extends Composer<_$AppDatabase, $NoteInksTable> {
  $$NoteInksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strokes => $composableBuilder(
    column: $table.strokes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteInksTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteInksTable> {
  $$NoteInksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strokes => $composableBuilder(
    column: $table.strokes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteInksTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteInksTable> {
  $$NoteInksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get strokes =>
      $composableBuilder(column: $table.strokes, builder: (column) => column);

  GeneratedColumn<int> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => column,
  );
}

class $$NoteInksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteInksTable,
          NoteInk,
          $$NoteInksTableFilterComposer,
          $$NoteInksTableOrderingComposer,
          $$NoteInksTableAnnotationComposer,
          $$NoteInksTableCreateCompanionBuilder,
          $$NoteInksTableUpdateCompanionBuilder,
          (NoteInk, BaseReferences<_$AppDatabase, $NoteInksTable, NoteInk>),
          NoteInk,
          PrefetchHooks Function()
        > {
  $$NoteInksTableTableManager(_$AppDatabase db, $NoteInksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteInksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteInksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteInksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> strokes = const Value.absent(),
                Value<int> canvasWidth = const Value.absent(),
                Value<int> canvasHeight = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteInksCompanion(
                id: id,
                strokes: strokes,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> strokes = const Value.absent(),
                Value<int> canvasWidth = const Value.absent(),
                Value<int> canvasHeight = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<String?> lastDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteInksCompanion.insert(
                id: id,
                strokes: strokes,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                version: version,
                baseVersion: baseVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                isNew: isNew,
                lastDeviceId: lastDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteInksTable, NoteInk>(table),
                  BaseReferences<_$AppDatabase, $NoteInksTable, NoteInk>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteInksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteInksTable,
      NoteInk,
      $$NoteInksTableFilterComposer,
      $$NoteInksTableOrderingComposer,
      $$NoteInksTableAnnotationComposer,
      $$NoteInksTableCreateCompanionBuilder,
      $$NoteInksTableUpdateCompanionBuilder,
      (NoteInk, BaseReferences<_$AppDatabase, $NoteInksTable, NoteInk>),
      NoteInk,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaEntriesTableCreateCompanionBuilder =
    SyncMetaEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetaEntriesTableUpdateCompanionBuilder =
    SyncMetaEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaEntriesTable> {
  $$SyncMetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaEntriesTable> {
  $$SyncMetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaEntriesTable> {
  $$SyncMetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaEntriesTable,
          SyncMetaEntry,
          $$SyncMetaEntriesTableFilterComposer,
          $$SyncMetaEntriesTableOrderingComposer,
          $$SyncMetaEntriesTableAnnotationComposer,
          $$SyncMetaEntriesTableCreateCompanionBuilder,
          $$SyncMetaEntriesTableUpdateCompanionBuilder,
          (
            SyncMetaEntry,
            BaseReferences<_$AppDatabase, $SyncMetaEntriesTable, SyncMetaEntry>,
          ),
          SyncMetaEntry,
          PrefetchHooks Function()
        > {
  $$SyncMetaEntriesTableTableManager(
    _$AppDatabase db,
    $SyncMetaEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaEntriesTable, SyncMetaEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncMetaEntriesTable,
                    SyncMetaEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaEntriesTable,
      SyncMetaEntry,
      $$SyncMetaEntriesTableFilterComposer,
      $$SyncMetaEntriesTableOrderingComposer,
      $$SyncMetaEntriesTableAnnotationComposer,
      $$SyncMetaEntriesTableCreateCompanionBuilder,
      $$SyncMetaEntriesTableUpdateCompanionBuilder,
      (
        SyncMetaEntry,
        BaseReferences<_$AppDatabase, $SyncMetaEntriesTable, SyncMetaEntry>,
      ),
      SyncMetaEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$NoteImagesTableTableManager get noteImages =>
      $$NoteImagesTableTableManager(_db, _db.noteImages);
  $$NoteInksTableTableManager get noteInks =>
      $$NoteInksTableTableManager(_db, _db.noteInks);
  $$SyncMetaEntriesTableTableManager get syncMetaEntries =>
      $$SyncMetaEntriesTableTableManager(_db, _db.syncMetaEntries);
}
