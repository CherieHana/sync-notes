import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';

import 'support/fake_store.dart';

void main() {
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

  group('目录', () {
    test('新建的目录会上传，本地转干净', () async {
      local.folders['f1'] = localFolder(id: 'f1', name: '工作', isNew: true);

      final report = await engine.syncNow();

      expect(report.pushed, 1);
      expect(remote.folders['f1']!.name, '工作');
      expect(local.folders['f1']!.dirty, isFalse);
      expect(local.folders['f1']!.baseVersion, 1);
    });

    test('改名会带版本号上传', () async {
      local.folders['f1'] = localFolder(
        id: 'f1',
        name: '旧名字',
        version: 1,
        baseVersion: 1,
        dirty: false,
      );
      remote.seedFolder(remoteFolder(id: 'f1', name: '旧名字'));

      await local.renameFolder(id: 'f1', name: '新名字', now: now);
      await engine.syncNow();

      expect(remote.folders['f1']!.name, '新名字');
      expect(remote.folders['f1']!.version, 2);
    });

    test('目录撞车时以本地这次改动为准重试', () async {
      // 本地基于版本 1 改名，远端已经涨到版本 2。
      local.folders['f1'] = localFolder(
        id: 'f1',
        name: '我改的名字',
        version: 1,
        baseVersion: 1,
      );
      remote.seedFolder(
        remoteFolder(id: 'f1', name: '别人改的名字', version: 2),
      );

      await engine.syncNow();

      // 目录没有正文可丢，不存在冲突副本，直接覆盖过去。
      expect(remote.folders['f1']!.name, '我改的名字');
      expect(local.folders['f1']!.dirty, isFalse);
    });

    test('删除目录时里面的笔记回到未分类，两端一致', () async {
      remote.seedFolder(remoteFolder(id: 'f1', name: '工作'));
      remote.seed(remoteNote(id: 'n1', body: '一篇笔记', folderId: 'f1'));
      local.folders['f1'] = localFolder(
        id: 'f1',
        name: '工作',
        version: 1,
        baseVersion: 1,
        dirty: false,
      );
      local.notes['n1'] = localNote(
        id: 'n1',
        body: '一篇笔记',
        version: 1,
        baseVersion: 1,
        folderId: 'f1',
        dirty: false,
      );

      await local.softDeleteFolder(id: 'f1', now: now);
      expect(local.notes['n1']!.folderId, isNull);

      await engine.syncNow();

      expect(remote.folders['f1']!.deletedAt, isNotNull);
      expect(remote.notes['n1']!.folderId, isNull);
      expect(local.notes['n1']!.dirty, isFalse);
    });

    test('笔记的目录归属会同步到另一端', () async {
      remote.seedFolder(remoteFolder(id: 'f1', name: '生活'));
      local.notes['n1'] = localNote(
        id: 'n1',
        body: '买菜清单',
        folderId: 'f1',
        isNew: true,
      );

      await engine.syncNow();

      expect(remote.notes['n1']!.folderId, 'f1');

      // 换一台设备拉取，归属也要跟着过来。
      final other = FakeLocalStore()..device = 'other-device';
      await SyncEngine(local: other, remote: remote).syncNow();
      expect(other.notes['n1']!.folderId, 'f1');
      expect(other.folders['f1']!.name, '生活');
    });

    test('实时收到目录删除时，本地挂着的笔记回到未分类', () async {
      local.folders['f1'] = localFolder(
        id: 'f1',
        name: '工作',
        version: 1,
        baseVersion: 1,
        dirty: false,
      );
      local.notes['n1'] = localNote(
        id: 'n1',
        body: '笔记',
        version: 1,
        baseVersion: 1,
        folderId: 'f1',
        dirty: false,
      );

      await engine.applyFolderRealtime(
        remoteFolder(
          id: 'f1',
          name: '工作',
          version: 2,
          deletedAt: now,
          lastDeviceId: 'other-device',
        ),
      );

      expect(local.notes['n1']!.folderId, isNull);
    });
  });

  group('冲突副本', () {
    test('副本继承原笔记的目录和加锁状态', () async {
      local.notes['n1'] = localNote(
        id: 'n1',
        body: '我在手机上写的内容',
        version: 1,
        baseVersion: 1,
        folderId: 'f1',
        locked: true,
        passphraseHash: 'hash',
        passphraseSalt: 'salt',
      );
      remote.seed(
        remoteNote(
          id: 'n1',
          body: '我在电脑上写的内容',
          version: 2,
          folderId: 'f1',
        ),
      );

      final report = await engine.syncNow();
      expect(report.conflicts, 1);

      final copy = remote.notes.values.firstWhere(
        (n) => n.body.contains('冲突副本'),
      );
      expect(copy.folderId, 'f1');
      expect(copy.locked, isTrue);
      expect(copy.passphraseHash, 'hash');
      expect(copy.passphraseSalt, 'salt');
    });
  });

  group('图片', () {
    // 引用标记必须是合法 uuid 才会被认出来，所以测试里也得用真的 uuid。
    const imageId = '44444444-4444-4444-4444-444444444444';

    test('先把文件传上去，再写记录', () async {
      // 得有一篇笔记引用它，否则同步末尾的回收逻辑会把它当孤儿图删掉。
      local.notes['n1'] = localNote(
        id: 'n1',
        body: '看图\n[[img:$imageId]]',
        version: 1,
        baseVersion: 1,
        dirty: false,
      );
      local.images[imageId] = localImage(
        id: imageId,
        storagePath: 'u/$imageId.jpg',
      );
      local.files[imageId] = [1, 2, 3, 4];

      final report = await engine.syncNow();

      expect(report.pushed, 1);
      expect(remote.storage['u/$imageId.jpg'], [1, 2, 3, 4]);
      expect(remote.images[imageId]!.byteSize, 4);
      expect(local.images[imageId]!.dirty, isFalse);
    });

    test('本地文件丢了就标记删除，而不是卡在待推送', () async {
      local.images[imageId] = localImage(id: imageId);
      // 故意不放 local.files

      await engine.syncNow();

      expect(local.images[imageId]!.deletedAt, isNotNull);
      expect(remote.storage, isEmpty);
    });

    test('另一端会拉到记录并把文件下回来', () async {
      remote.seed(remoteNote(id: 'n1', body: '看图\n[[img:$imageId]]'));
      remote.images[imageId] = remoteImageRecord(
        id: imageId,
        storagePath: 'u/$imageId.jpg',
        byteSize: 3,
      );
      remote.storage['u/$imageId.jpg'] = [9, 8, 7];

      final other = FakeLocalStore()..device = 'other-device';
      await SyncEngine(local: other, remote: remote).syncNow();

      expect(other.images[imageId], isNotNull);
      expect(other.files[imageId], [9, 8, 7]);
      expect(other.images[imageId]!.dirty, isFalse);
    });
  });

  group('孤儿图回收', () {
    test('没被引用且过了宽限期的图片才标记删除', () async {
      final old = now.subtract(const Duration(hours: 48));
      final fresh = now.subtract(const Duration(hours: 1));

      local.notes['n1'] = localNote(
        id: 'n1',
        body: '正文\n[[img:11111111-1111-1111-1111-111111111111]]',
        version: 1,
        baseVersion: 1,
        dirty: false,
      );
      local.images['11111111-1111-1111-1111-111111111111'] = localImage(
        id: '11111111-1111-1111-1111-111111111111',
        createdAt: old,
        dirty: false,
      );
      local.images['22222222-2222-2222-2222-222222222222'] = localImage(
        id: '22222222-2222-2222-2222-222222222222',
        createdAt: old,
        dirty: false,
      );
      local.images['33333333-3333-3333-3333-333333333333'] = localImage(
        id: '33333333-3333-3333-3333-333333333333',
        createdAt: fresh,
        dirty: false,
      );

      await engine.syncNow();

      // 还在被引用，留着。
      expect(local.images['11111111-1111-1111-1111-111111111111']!.isDeleted, isFalse);
      // 没人引用且够旧，标记删除。
      expect(local.images['22222222-2222-2222-2222-222222222222']!.isDeleted, isTrue);
      // 虽然没人引用，但刚插入不久，再等等。
      expect(local.images['33333333-3333-3333-3333-333333333333']!.isDeleted, isFalse);
    });

    test('墓碑放够久之后才删文件和记录', () async {
      final deletedLongAgo = now.subtract(const Duration(days: 8));
      local.images['i1'] = localImage(
        id: 'i1',
        storagePath: 'u/i1.jpg',
        deletedAt: deletedLongAgo,
        dirty: false,
      );
      local.files['i1'] = [1, 2, 3];
      remote.storage['u/i1.jpg'] = [1, 2, 3];

      await engine.syncNow();

      expect(remote.storage.containsKey('u/i1.jpg'), isFalse);
      expect(local.files.containsKey('i1'), isFalse);
      expect(local.images.containsKey('i1'), isFalse);
    });

    test('刚标记删除的图片先不动文件，等同步传到另一端', () async {
      local.images['i1'] = localImage(
        id: 'i1',
        storagePath: 'u/i1.jpg',
        deletedAt: now,
        dirty: false,
      );
      local.files['i1'] = [1, 2, 3];
      remote.storage['u/i1.jpg'] = [1, 2, 3];

      await engine.syncNow();

      expect(remote.storage.containsKey('u/i1.jpg'), isTrue);
      expect(local.files.containsKey('i1'), isTrue);
    });
  });
}
