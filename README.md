# sync-notes

手机和电脑双向同步的纯文本备忘录。Android 和 Windows 用同一个账号登录，
在任何一端写下的内容，另一端几秒内就能看到；断网时照常读写，联网后自动补齐。

Flutter 一套代码出两端，Supabase 负责登录、存储和实时推送，本地 SQLite 存一份离线副本。

<p align="center">
  <img src="docs/notes-list.png" width="330" alt="笔记列表">
  <img src="docs/note-edit.png" width="330" alt="编辑页">
</p>

## 能做到什么

- Android 和 Windows 共用一套代码，同一账号登录即同步
- 本地存完整副本，没网也能看和写，联网后自动上传对账
- 单层目录分类，顶部标签一键切换，长按笔记可移动归类
- 笔记里能插图片，图片在文字之间直接显示，两端都能看到
- 桌面端可以直接把剪切板里的图片粘进笔记（右键菜单里选「粘贴图片」）
- 可以一次导入多个 txt / markdown 文件，每个文件生成一篇笔记
- 编辑时能一键撤回，误删一段话不用重新打；列表里误删整篇也能撤销
- 单篇笔记可以加口令，忘了口令用登录密码就能关掉加密
- 两端同时改同一篇笔记时保留两份内容，生成带时间戳的「冲突副本」，不互相覆盖
- App 在前台时收到服务端推送，另一端一两秒内出现改动
- 时间戳由服务端生成，设备时钟不准也不影响增量同步
- Postgres 行级权限隔离，每个账号只能读写自己的笔记

还没做的：富文本、二级以上目录、手写、分享协作、端到端加密。

**关于加锁**：锁只是应用层的一道门。正文和图片在 Supabase 上仍是明文，
任何拿到你账号的人（或能读数据库的人）都能看到内容。它挡的是「手机被别人拿到、
App 又正好登录着」这种情况。要真正连服务端都读不到的加密，是另一套设计。

## 快速开始

需要 Flutter 3.47 / Dart 3.13 以上，以及一个 Supabase 项目（免费额度足够自用）。

### 1. 建 Supabase 项目

到 [supabase.com](https://supabase.com) 注册并新建项目，然后在
**Settings → API** 拿到两个值：`Project URL`（形如 `https://xxxx.supabase.co`）
和 `anon public` key。

anon key 设计上就是给客户端用的，不是秘密。真正的隔离靠数据库行级权限，
建表脚本里已经配好。

### 2. 建表

打开项目的 **SQL Editor**，新建一个查询，把 [`supabase/schema.sql`](supabase/schema.sql)
全文粘进去执行。脚本可以重复跑，不会破坏已有数据。

它会建 `notes`、`folders`、`note_images` 三张表，打开行级权限，
装一个把更新时间交给服务端时钟的触发器，把前两张表加进实时推送，
再建一个私有的 `note-images` 存储桶并配好归属策略。

> **已经在用的项目**：加了目录、图片、加锁之后服务端结构变了，
> 需要把这份脚本**再执行一次**。脚本是幂等的，老数据不受影响。
> 不执行的话，客户端同步会因为缺列而报错。

### 3. 填配置

把 `config.example.json` 复制一份改名成 `config.json`，填入上面拿到的两个值：

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi..."
}
```

`config.json` 已经在 `.gitignore` 里，不会进版本库。

Supabase 默认要求注册后去邮箱点确认链接才能登录。自己用的话可以到
**Authentication → Sign In / Providers → Email** 把 **Confirm email** 关掉，
省掉这一步。

### 4. 跑起来

```bash
flutter pub get
dart run build_runner build      # 生成本地数据库代码
flutter run -d windows --dart-define-from-file=config.json
flutter run --dart-define-from-file=config.json   # 或者自动选设备
```

改了 `lib/data/local/database.dart` 的表结构之后，要重新跑一次 `build_runner`。

## 构建安装包

Android：

```bash
flutter build apk --release --dart-define-from-file=config.json
```

产物在 `build/app/outputs/flutter-apk/app-release.apk`，用调试密钥签名，适合自己装。
要上架应用商店得另外配正式签名。

Windows：

```bash
flutter build windows --release --dart-define-from-file=config.json
```

产物在 `build/windows/x64/runner/Release/`，是整个文件夹。exe 不能单独拷出来，
它需要同目录的 dll 和 `data` 文件夹。没有代码签名，拷到别的电脑首次运行会被
SmartScreen 拦一下，点「更多信息 → 仍要运行」。

打 Windows 包还需要两个前提，都要管理员权限：Visual Studio 的
「使用 C++ 的桌面开发」工作负载（约 7GB），以及打开系统设置里的开发者模式
（Flutter 创建插件符号链接需要）。装完 `flutter doctor` 里 Visual Studio 那项变成绿色就行。

## 同步是怎么做的

客户端分三层，界面只读本地数据库，不碰网络。断网可用和同步逻辑可测试，都建立在这个前提上。

| 层 | 位置 | 职责 |
| --- | --- | --- |
| 本地库 | `lib/data/local/` | SQLite 存完整镜像，记 `baseVersion` 和脏标记 |
| 远端 | `lib/data/remote/` | Supabase 读写与实时订阅 |
| 同步引擎 | `lib/data/sync/` | 推送、拉取、冲突判定，纯逻辑可单测 |

一轮同步固定「先推后拉」：

1. 把本地带脏标记的笔记按修改时间顺序上传。更新语句带条件
   `version = 上次同步成功时的版本号`，这就是乐观锁，匹配不到行说明期间被别人改过。
2. 匹配不到就转入冲突流程。本地这份内容另存成一条新笔记，标题后加
   「（冲突副本 2026-09-18 14:30）」，原笔记接受服务端的最新版本。两份都留着，
   怎么合并由用户决定。如果撞上的是「本地删、远端改」，则反过来把远端那份留成副本，
   删除照常生效。
3. 拉取按更新时间增量进行，逐条比版本号写入本地。本地还有没推上去的改动就先跳过，
   留给下一轮推送处理，避免把刚写的内容盖掉。
4. App 在前台时订阅服务端推送事件。事件里带设备标识，自己刚写的那条会被过滤掉，
   不做多余的重写。

同步在四个时机触发：App 启动、从后台切回前台、网络恢复，以及前台每 60 秒兜底跑一轮。
最后一条是为了防止实时通道静默断开后长时间不同步。

所有时间戳都由数据库触发器用服务端时间生成，手机和电脑的系统时间不一致也不会
影响增量同步的正确性。

### 目录与图片

推送顺序固定为**目录 → 笔记 → 图片**：笔记带着所属目录的 id，目录得先在服务端存在。
目录没有正文可丢，所以撞车时以本地这次改动为准重试一次，不像笔记那样生成冲突副本。

图片文件走 Supabase Storage 的私有桶，路径第一段是用户 id，策略据此判断归属。
元数据在 `note_images` 表里，内容不可变，所以按 id upsert 就行，不需要乐观锁。

没人引用的图片会回收，分两步走：先挂起 24 小时再标记删除，标记之后再过 7 天
才真正删掉存储桶里的文件。中间的等待是为了躲开同步时序——某个设备刚删掉图片标记，
另一个设备还没拉到那次修改，这时就把文件删了会让人家的图片变成裂图。

## 目录结构

```
lib/data/local/      本地 SQLite 副本（drift）
lib/data/remote/     Supabase 读写与实时订阅
lib/data/sync/       同步引擎与调度
lib/ui/              界面（列表页、编辑页、登录页）
supabase/schema.sql  服务端建表脚本
tool/dev.ps1         开发脚本
test/                测试
```

## 更新日志

**1.0.2** 修掉插入图片后显示成「OBJ」方块的问题；桌面端支持从剪切板粘贴图片。

**1.0.1** 新增单层目录、图片插入、txt/markdown 导入、编辑撤回、单篇加锁。
服务端脚本需要重新执行一次。

**1.0.0** 首个版本：纯文本笔记的双端双向同步。

版本号写在 `pubspec.yaml` 里，格式是 `1.0.1+2`。加号前面是给人看的，
加号后面是构建号。**每次发版两个都往后加一**（`1.0.1+2` → `1.0.2+3`），
Android 就是靠构建号判断这是不是新版本，只改前面它不会认。

## 测试

```bash
flutter test
```

66 个测试，另外 1 个真实后端联调测试默认跳过。同步引擎用内存版的本地库和远端来测，
不依赖网络，覆盖笔记的增删改与冲突副本、目录的增删改与归属迁移、图片上传下载与回收、
导入的编码识别、口令派生与校验、撤回的编辑段合并，以及界面层的目录切换、误删撤销
和加锁解锁流程。

`test/live_backend_test.dart` 是可选的真实后端联调测试，会真的建两台模拟设备跑一遍
完整同步，包括跨账号隔离。需要显式开启并传入一个专用测试账号（不要用自己日常的账号，
测试结束会清空该账号的笔记）：

```bash
flutter test test/live_backend_test.dart \
  --dart-define=LIVE=true \
  --dart-define-from-file=config.json \
  --dart-define=LIVE_EMAIL=测试邮箱 \
  --dart-define=LIVE_PASSWORD=测试密码
```

## 关于 tool/dev.ps1

项目带了一个 PowerShell 脚本，把依赖、代码生成、检查、打包几条命令包了一遍：

```powershell
.\tool\dev.ps1 get        # 拉依赖
.\tool\dev.ps1 gen        # 生成本地数据库代码
.\tool\dev.ps1 analyze    # 静态检查
.\tool\dev.ps1 test       # 跑测试
.\tool\dev.ps1 apk        # 打 Android 包
.\tool\dev.ps1 win        # 打 Windows 包
.\tool\dev.ps1 run -d windows
```

它是为了绕开开发机上的两个具体问题，普通机器上不需要，直接用上面那些 `flutter` 命令即可。

一是用户名是中文。Dart 的 AOT 编译器（`build_runner` 和 `flutter analyze` 都会用到）
写不了含非 ASCII 字符的路径，会报 `Unable to write file`。脚本建了一个纯英文的目录联接
`D:\work\mod` 指向项目，所有工具从这个路径执行。

二是 `sqlite3` 包在构建时要从 GitHub Releases 下载 .so 和 .dll，国内直连不通。
脚本改用镜像拉取，按官方 SHA-256 校验后放进构建缓存，构建阶段直接复用，不再联网。

脚本开头写死了这台机器的安装位置（Flutter 在 `D:\flutter`、Android SDK 在
`D:\Android\Sdk`），换机器要改那几个变量。

## 其它

Supabase 免费项目连续 7 天没有任何访问会被自动暂停，到面板点一下就能恢复。

手机端只在 App 打开或切回前台时同步，没有做后台常驻推送和通知。

## 许可

MIT，全文见 [LICENSE](LICENSE)。
