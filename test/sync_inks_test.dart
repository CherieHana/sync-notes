import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';

import 'support/fake_store.dart';

void main() {
  // 正文里的引用标记必须是合法 uuid 才会被认出来，所以测试里也得用真的。
  const inkId = '44444444-4444-4444-4444-444444444444';

  late FakeLocalStore local;
  late FakeRemoteApi remote;
  late DateTime now;
  late SyncEngine engine;

  setUp(() {
    local = FakeLocalStore();
    remote = FakeRemoteApi();
    now = DateTime.utc(2026, 6, 1, 12);
    engine = SyncEngine(local: local, remote: remote, clock: () => now);
  });

  test('新建的手写画布会上传，本地转干净', () async {
    // 得有一篇笔记引用它，否则同步末尾的回收逻辑会把它当孤儿删掉。
    local.notes['n1'] = localNote(
      id: 'n1',
      body: '看图\n[[ink:$inkId]]',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    local.inks[inkId] = localInk(id: inkId, strokes: '[[1]]', isNew: true);

    final report = await engine.syncNow();

    expect(report.pushed, 1);
    expect(remote.inks[inkId]!.strokes, '[[1]]');
    expect(local.inks[inkId]!.dirty, isFalse);
    expect(local.inks[inkId]!.baseVersion, 1);
  });

  test('改了笔迹会带版本号上传', () async {
    local.notes['n1'] = localNote(
      id: 'n1',
      body: '看图\n[[ink:$inkId]]',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    local.inks[inkId] = localInk(
      id: inkId,
      strokes: '[]',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    remote.seedInk(remoteInk(id: inkId, strokes: '[]'));

    await local.updateInkStrokes(id: inkId, strokes: '[新笔迹]', now: now);
    await engine.syncNow();

    expect(remote.inks[inkId]!.strokes, '[新笔迹]');
    expect(remote.inks[inkId]!.version, 2);
  });

  test('两端同时改一幅画时以本地为准，不生成副本', () async {
    local.notes['n1'] = localNote(
      id: 'n1',
      body: '看图\n[[ink:$inkId]]',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    local.inks[inkId] = localInk(
      id: inkId,
      strokes: '我这边画的',
      version: 1,
      baseVersion: 1,
    );
    remote.seedInk(remoteInk(id: inkId, strokes: '别人画的', version: 2));

    await engine.syncNow();

    // 一幅画没法自动合并，也不值得留两份手写，直接覆盖过去。
    expect(remote.inks[inkId]!.strokes, '我这边画的');
    expect(remote.inks, hasLength(1));
    expect(local.inks[inkId]!.dirty, isFalse);
  });

  test('另一端能拉到笔迹', () async {
    remote.seed(remoteNote(id: 'n1', body: '看图\n[[ink:$inkId]]'));
    remote.seedInk(remoteInk(id: inkId, strokes: '[画的东西]'));

    final other = FakeLocalStore()..device = 'other-device';
    await SyncEngine(local: other, remote: remote).syncNow();

    expect(other.inks[inkId]!.strokes, '[画的东西]');
    expect(other.inks[inkId]!.dirty, isFalse);
  });

  test('没人引用的画布会被回收，还在用的不动', () async {
    final old = now.subtract(const Duration(days: 3));

    local.notes['n1'] = localNote(
      id: 'n1',
      body: '正文\n[[ink:11111111-1111-1111-1111-111111111111]]',
      version: 1,
      baseVersion: 1,
      dirty: false,
    );
    local.inks['11111111-1111-1111-1111-111111111111'] = localInk(
      id: '11111111-1111-1111-1111-111111111111',
      createdAt: old,
      dirty: false,
    );
    local.inks['22222222-2222-2222-2222-222222222222'] = localInk(
      id: '22222222-2222-2222-2222-222222222222',
      createdAt: old,
      dirty: false,
    );

    await engine.syncNow();

    expect(
      local.inks['11111111-1111-1111-1111-111111111111']!.isDeleted,
      isFalse,
      reason: '还在正文里引用着',
    );
    expect(
      local.inks['22222222-2222-2222-2222-222222222222']!.isDeleted,
      isTrue,
    );
  });
}
