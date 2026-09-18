import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'remote_api.dart';

/// Supabase 实现：REST 读写走 PostgREST，实时推送走 Realtime，
/// 图片字节走 Storage。
class SupabaseRemoteApi implements RemoteApi {
  SupabaseRemoteApi(this._client);

  static const String _notes = 'notes';
  static const String _folders = 'folders';
  static const String _images = 'note_images';
  static const String _imageBucket = 'note-images';

  /// 单次拉取的条数上限。个人笔记量远达不到这个量级，
  /// 真到了就说明该做分页了。
  static const int _pageSize = 5000;

  final SupabaseClient _client;

  StreamController<RemoteNote>? _noteChanges;
  StreamController<RemoteFolder>? _folderChanges;
  RealtimeChannel? _noteChannel;
  RealtimeChannel? _folderChannel;

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------
  // 笔记
  // ---------------------------------------------------------------------

  @override
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since) async {
    try {
      final base = _client.from(_notes).select();
      final filtered = since == null
          ? base
          : base.gte('updated_at', since.toUtc().toIso8601String());
      final rows = await filtered
          .order('updated_at', ascending: true)
          .limit(_pageSize);
      return rows.map(RemoteNote.fromJson).toList();
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('拉取笔记失败', cause: error);
    }
  }

  @override
  Future<RemoteNote?> fetchById(String id) async {
    try {
      final rows = await _client
          .from(_notes)
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isEmpty) return null;
      return RemoteNote.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('读取单条笔记失败', cause: error);
    }
  }

  /// 用 upsert 而不是纯 insert：上传成功但回包丢失时，重试仍然能落到同一行，
  /// 不会因为主键冲突把这条笔记永远卡在待推送状态。
  @override
  Future<RemoteNote> insert({
    required String id,
    required NotePayload payload,
    String? lastDeviceId,
  }) async {
    try {
      final rows = await _client
          .from(_notes)
          .upsert({
            'id': id,
            ..._noteColumns(payload),
            'last_device_id': lastDeviceId,
          })
          .select();
      if (rows.isEmpty) {
        throw const RemoteApiException('上传后服务端没有返回记录');
      }
      return RemoteNote.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('上传笔记失败', cause: error);
    }
  }

  @override
  Future<RemoteNote?> updateIfVersion({
    required String id,
    required NotePayload payload,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    try {
      // 版本号作为 where 条件参与匹配，是这套乐观锁的关键：
      // 期间被别的设备改过就匹配不到行，返回空表示冲突。
      final rows = await _client
          .from(_notes)
          .update({
            ..._noteColumns(payload),
            'version': expectedVersion + 1,
            'last_device_id': lastDeviceId,
            'deleted_at': deletedAt?.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('version', expectedVersion)
          .select();
      if (rows.isEmpty) return null;
      return RemoteNote.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('更新笔记失败', cause: error);
    }
  }

  Map<String, dynamic> _noteColumns(NotePayload payload) => {
    'body': payload.body,
    'folder_id': payload.folderId,
    'locked': payload.locked,
    'passphrase_hash': payload.passphraseHash,
    'passphrase_salt': payload.passphraseSalt,
  };

  // ---------------------------------------------------------------------
  // 目录
  // ---------------------------------------------------------------------

  @override
  Future<List<RemoteFolder>> fetchFoldersChangedSince(DateTime? since) async {
    try {
      final base = _client.from(_folders).select();
      final filtered = since == null
          ? base
          : base.gte('updated_at', since.toUtc().toIso8601String());
      final rows = await filtered
          .order('updated_at', ascending: true)
          .limit(_pageSize);
      return rows.map(RemoteFolder.fromJson).toList();
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('拉取目录失败', cause: error);
    }
  }

  @override
  Future<RemoteFolder?> fetchFolderById(String id) async {
    try {
      final rows = await _client
          .from(_folders)
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isEmpty) return null;
      return RemoteFolder.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('读取目录失败', cause: error);
    }
  }

  @override
  Future<RemoteFolder> insertFolder({
    required String id,
    required String name,
    String? lastDeviceId,
  }) async {
    try {
      final rows = await _client
          .from(_folders)
          .upsert({
            'id': id,
            'name': name,
            'last_device_id': lastDeviceId,
          })
          .select();
      if (rows.isEmpty) {
        throw const RemoteApiException('上传后服务端没有返回记录');
      }
      return RemoteFolder.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('上传目录失败', cause: error);
    }
  }

  @override
  Future<RemoteFolder?> updateFolderIfVersion({
    required String id,
    required String name,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    try {
      final rows = await _client
          .from(_folders)
          .update({
            'name': name,
            'version': expectedVersion + 1,
            'last_device_id': lastDeviceId,
            'deleted_at': deletedAt?.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('version', expectedVersion)
          .select();
      if (rows.isEmpty) return null;
      return RemoteFolder.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('更新目录失败', cause: error);
    }
  }

  // ---------------------------------------------------------------------
  // 图片
  // ---------------------------------------------------------------------

  @override
  Future<List<RemoteImage>> fetchImagesChangedSince(DateTime? since) async {
    try {
      final base = _client.from(_images).select();
      final filtered = since == null
          ? base
          : base.gte('updated_at', since.toUtc().toIso8601String());
      final rows = await filtered
          .order('updated_at', ascending: true)
          .limit(_pageSize);
      return rows.map(RemoteImage.fromJson).toList();
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('拉取图片列表失败', cause: error);
    }
  }

  @override
  Future<RemoteImage> upsertImage({
    required String id,
    required String storagePath,
    required int byteSize,
    int? width,
    int? height,
    DateTime? deletedAt,
  }) async {
    try {
      final rows = await _client
          .from(_images)
          .upsert({
            'id': id,
            'storage_path': storagePath,
            'byte_size': byteSize,
            'width': width,
            'height': height,
            'deleted_at': deletedAt?.toUtc().toIso8601String(),
          })
          .select();
      if (rows.isEmpty) {
        throw const RemoteApiException('上传后服务端没有返回记录');
      }
      return RemoteImage.fromJson(rows.first);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('更新图片记录失败', cause: error);
    }
  }

  @override
  Future<void> uploadImage(String storagePath, List<int> bytes) async {
    try {
      await _client.storage
          .from(_imageBucket)
          .uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('上传图片失败', cause: error);
    }
  }

  @override
  Future<List<int>> downloadImage(String storagePath) async {
    try {
      final bytes = await _client.storage
          .from(_imageBucket)
          .download(storagePath);
      return bytes;
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('下载图片失败', cause: error);
    }
  }

  @override
  Future<void> deleteImageObject(String storagePath) async {
    try {
      await _client.storage.from(_imageBucket).remove([storagePath]);
    } on RemoteApiException {
      rethrow;
    } catch (error) {
      throw RemoteApiException('删除图片文件失败', cause: error);
    }
  }

  // ---------------------------------------------------------------------
  // 实时
  // ---------------------------------------------------------------------

  @override
  Stream<RemoteNote> watchChanges() {
    final existing = _noteChanges;
    if (existing != null) return existing.stream;

    final controller = StreamController<RemoteNote>.broadcast();
    _noteChanges = controller;
    _noteChannel = _subscribe<RemoteNote>(
      table: _notes,
      channelName: 'notes-changes',
      onRecord: (record, payload) {
        var note = RemoteNote.fromJson(record);
        // 删除事件的正文只在 oldRecord 里，需要服务端开启 replica identity full。
        if (payload.eventType == PostgresChangeEvent.delete &&
            note.deletedAt == null) {
          final now = DateTime.now().toUtc();
          note = RemoteNote(
            id: note.id,
            body: note.body,
            version: note.version,
            createdAt: note.createdAt,
            updatedAt: now,
            folderId: note.folderId,
            locked: note.locked,
            passphraseHash: note.passphraseHash,
            passphraseSalt: note.passphraseSalt,
            deletedAt: now,
            lastDeviceId: note.lastDeviceId,
          );
        }
        return note;
      },
      controller: controller,
    );
    return controller.stream;
  }

  @override
  Stream<RemoteFolder> watchFolderChanges() {
    final existing = _folderChanges;
    if (existing != null) return existing.stream;

    final controller = StreamController<RemoteFolder>.broadcast();
    _folderChanges = controller;
    _folderChannel = _subscribe<RemoteFolder>(
      table: _folders,
      channelName: 'folders-changes',
      onRecord: (record, payload) {
        var folder = RemoteFolder.fromJson(record);
        if (payload.eventType == PostgresChangeEvent.delete &&
            folder.deletedAt == null) {
          final now = DateTime.now().toUtc();
          folder = RemoteFolder(
            id: folder.id,
            name: folder.name,
            version: folder.version,
            createdAt: folder.createdAt,
            updatedAt: now,
            deletedAt: now,
            lastDeviceId: folder.lastDeviceId,
          );
        }
        return folder;
      },
      controller: controller,
    );
    return controller.stream;
  }

  RealtimeChannel _subscribe<T>({
    required String table,
    required String channelName,
    required T Function(Map<String, dynamic> record, PostgresChangePayload payload)
    onRecord,
    required StreamController<T> controller,
  }) {
    final userId = _userId;
    var channel = _client.channel(channelName);
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: userId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
      callback: (payload) {
        try {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isEmpty) return;
          controller.add(onRecord(Map<String, dynamic>.from(record), payload));
        } catch (_) {
          // 单条事件解析失败不该拖垮整条通道，下一轮全量对账会补上。
        }
      },
    );
    return channel.subscribe();
  }

  @override
  Future<void> dispose() async {
    final channels = [_noteChannel, _folderChannel];
    _noteChannel = null;
    _folderChannel = null;
    for (final channel in channels) {
      if (channel != null) await _client.removeChannel(channel);
    }
    await _noteChanges?.close();
    await _folderChanges?.close();
    _noteChanges = null;
    _folderChanges = null;
  }
}
