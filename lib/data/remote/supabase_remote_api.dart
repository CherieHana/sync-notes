import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'remote_api.dart';

/// Supabase 实现：REST 读写走 PostgREST，实时推送走 Realtime。
class SupabaseRemoteApi implements RemoteApi {
  SupabaseRemoteApi(this._client);

  static const String _table = 'notes';

  /// 单次拉取的条数上限。个人笔记量远达不到这个量级，
  /// 真到了就说明该做分页了。
  static const int _pageSize = 5000;

  final SupabaseClient _client;

  StreamController<RemoteNote>? _changes;
  RealtimeChannel? _channel;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since) async {
    try {
      final base = _client.from(_table).select();
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
          .from(_table)
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
    required String body,
    String? lastDeviceId,
  }) async {
    try {
      final rows = await _client
          .from(_table)
          .upsert({
            'id': id,
            'body': body,
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
    required String body,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    try {
      // 版本号作为 where 条件参与匹配，是这套乐观锁的关键：
      // 期间被别的设备改过就匹配不到行，返回空表示冲突。
      final rows = await _client
          .from(_table)
          .update({
            'body': body,
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

  @override
  Stream<RemoteNote> watchChanges() {
    final existing = _changes;
    if (existing != null) return existing.stream;

    final controller = StreamController<RemoteNote>.broadcast();
    _changes = controller;
    _subscribe(controller);
    return controller.stream;
  }

  void _subscribe(StreamController<RemoteNote> controller) {
    final userId = _userId;
    var channel = _client.channel('notes-changes');
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: _table,
      filter: userId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
      callback: (payload) {
        try {
          // 删除事件的正文只在 oldRecord 里，需要服务端开启 replica identity full。
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isEmpty) return;

          var note = RemoteNote.fromJson(Map<String, dynamic>.from(record));
          if (payload.eventType == PostgresChangeEvent.delete &&
              note.deletedAt == null) {
            note = RemoteNote(
              id: note.id,
              body: note.body,
              version: note.version,
              createdAt: note.createdAt,
              updatedAt: DateTime.now().toUtc(),
              deletedAt: DateTime.now().toUtc(),
              lastDeviceId: note.lastDeviceId,
            );
          }
          controller.add(note);
        } catch (_) {
          // 单条事件解析失败不该拖垮整条通道，下一轮全量对账会补上。
        }
      },
    );
    _channel = channel.subscribe();
  }

  @override
  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
    await _changes?.close();
    _changes = null;
  }
}
