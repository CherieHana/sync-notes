import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';

import 'support/fake_store.dart';

void main() {
  late FakeLocalStore local;
  late FakeRemoteApi remote;
  late SyncEngine engine;

  setUp(() {
    local = FakeLocalStore();
    remote = FakeRemoteApi();
    engine = SyncEngine(local: local, remote: remote);
  });

  test('本地新建的笔记会被上传，随后本地转为干净状态', () async {
    local.notes['a'] = localNote(id: 'a', body: '买菜', isNew: true);

    final report = await engine.syncNow();

    expect(report.pushed, 1);
    expect(report.offline, isFalse);
    expect(remote.notes['a']!.body, '买菜');
    expect(local.notes['a']!.dirty, isFalse);
    expect(local.notes['a']!.isNew, isFalse);
    expect(local.notes['a']!.baseVersion, 1);
  });

  test('已同步笔记的修改会带上版本号上传并递增版本', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '旧内容',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    remote.seed(remoteNote(id: 'a', body: '旧内容', version: 1));

    await local.updateBody(id: 'a', body: '新内容', now: DateTime.utc(2026, 2));
    final report = await engine.syncNow();

    expect(report.pushed, 1);
    expect(remote.notes['a']!.body, '新内容');
    expect(remote.notes['a']!.version, 2);
    expect(local.notes['a']!.baseVersion, 2);
    expect(local.notes['a']!.dirty, isFalse);
  });

  test('本地删除推成服务端软删除，另一端同步后即消失', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '要删掉的',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    remote.seed(remoteNote(id: 'a', body: '要删掉的', version: 1));

    await local.softDelete(id: 'a', now: DateTime.utc(2026, 2));
    await engine.syncNow();

    expect(remote.notes['a']!.deletedAt, isNotNull);
    expect(local.notes['a']!.isDeleted, isTrue);
    expect(local.notes['a']!.dirty, isFalse);
  });

  test('版本冲突时本地内容留成冲突副本，原笔记采用远端版本', () async {
    // 本地基于版本 1 改了内容，但远端已经被别的设备改到了版本 2。
    local.notes['a'] = localNote(
      id: 'a',
      body: '我在手机上写的内容',
      version: 1,
      baseVersion: 1,
      dirty: true,
    );
    remote.seed(
      remoteNote(id: 'a', body: '我在电脑上写的内容', version: 2),
    );

    final report = await engine.syncNow();

    expect(report.conflicts, 1);
    // 原笔记保留远端那份。
    expect(remote.notes['a']!.body, '我在电脑上写的内容');
    // 本地这份被另存成冲突副本。
    final copies = remote.notes.values
        .where((n) => n.body.contains('冲突副本'))
        .toList();
    expect(copies, hasLength(1));
    expect(copies.single.body, startsWith('我在手机上写的内容（冲突副本 '));
    // 本地不再处于待推送状态。
    expect(local.notes['a']!.dirty, isFalse);
  });

  test('本地删除与远端修改撞上时，两边内容都保留', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '本地还留着的正文',
      version: 1,
      baseVersion: 1,
      deletedAt: DateTime.utc(2026, 2),
      dirty: true,
    );
    remote.seed(remoteNote(id: 'a', body: '远端改过的正文', version: 2));

    final report = await engine.syncNow();

    expect(report.conflicts, 1);
    // 删除生效。
    expect(remote.notes['a']!.deletedAt, isNotNull);
    // 远端那一版被留成副本，没有丢。
    final copies = remote.notes.values.where(
      (n) => n.id != 'a' && n.body.startsWith('远端改过的正文'),
    );
    expect(copies, hasLength(1));
    expect(copies.first.deletedAt, isNull);
  });

  test('拉取会把远端新增的笔记写进本地', () async {
    remote.seed(
      remoteNote(
        id: 'remote-1',
        body: '电脑上写的',
        version: 1,
        updatedAt: DateTime.utc(2026, 3),
      ),
    );

    final report = await engine.syncNow();

    expect(report.pulled, 1);
    expect(local.notes['remote-1']!.body, '电脑上写的');
    expect(local.notes['remote-1']!.dirty, isFalse);
    expect(local.lastPulledAt, DateTime.utc(2026, 3));
  });

  test('实时推送不会覆盖本地未推送的改动', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '我正在打的内容',
      version: 1,
      baseVersion: 1,
      dirty: true,
    );

    final applied = await engine.applyRealtime(
      remoteNote(id: 'a', body: '远端的新内容', version: 2),
    );

    expect(applied, isFalse);
    expect(local.notes['a']!.body, '我正在打的内容');
  });

  test('实时推送里的过期版本不会把本地内容回退', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '已经是最新的',
      version: 3,
      baseVersion: 3,
      dirty: false,
    );

    final applied = await engine.applyRealtime(
      remoteNote(id: 'a', body: '旧内容', version: 2),
    );

    expect(applied, isFalse);
    expect(local.notes['a']!.body, '已经是最新的');
  });

  test('实时推送会写入别的设备新建的笔记', () async {
    final applied = await engine.applyRealtime(
      remoteNote(
        id: 'b',
        body: '别的设备写的',
        version: 1,
        lastDeviceId: 'other-device',
      ),
    );

    expect(applied, isTrue);
    expect(local.notes['b']!.body, '别的设备写的');
  });

  test('断网时中断这一轮，待推送的改动留在本地', () async {
    local.notes['a'] = localNote(id: 'a', body: '地铁上写的', isNew: true);
    remote.offline = true;

    final report = await engine.syncNow();

    expect(report.offline, isTrue);
    expect(report.pushed, 0);
    expect(local.notes['a']!.dirty, isTrue);
    expect(remote.notes, isEmpty);
  });

  test('新建后还没上传就被删掉的笔记不会在服务端留下记录', () async {
    local.notes['a'] = localNote(
      id: 'a',
      body: '',
      isNew: true,
      deletedAt: DateTime.utc(2026, 2),
    );

    await engine.syncNow();

    expect(local.notes.containsKey('a'), isFalse);
    expect(remote.notes, isEmpty);
  });
}
