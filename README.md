# 跨端同步备忘录

手机（Android）和电脑（Windows）用同一个账号登录，笔记双向同步的纯文本备忘录。
没网也能正常看和写，联网后自动上传并对账；两边同时改同一篇时不会丢内容，
而是生成一份「冲突副本」让你自己合并。

技术栈：Flutter（一套代码出两端） + Supabase（登录、数据库、实时推送） + SQLite（本地离线副本）。

## 你需要做的三件事

### 1. 建一个 Supabase 项目

到 [supabase.com](https://supabase.com) 注册（免费），新建一个项目。
建好后在 **Settings → API** 里找到两个值：

- `Project URL`，形如 `https://abcdefgh.supabase.co`
- `anon public` key，一长串 `eyJ...` 开头的字符串

anon key 是设计上可以放进客户端的公开密钥，真正的安全靠数据库的行级权限
（`supabase/schema.sql` 里已经配好：每个账号只能读写自己的笔记）。

### 2. 建表

打开项目的 **SQL Editor → New query**，把 [`supabase/schema.sql`](supabase/schema.sql)
全文粘贴进去，点 **Run**。脚本可以重复执行，不会破坏已有数据。

它做了四件事：建 `notes` 表、开启行级权限、把更新时间交给服务端时钟、把表加入实时推送。

### 3. 填配置

把根目录的 `config.example.json` 复制一份改名成 `config.json`，填入上面拿到的两个值：

```json
{
  "SUPABASE_URL": "https://abcdefgh.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi..."
}
```

`config.json` 已经在 `.gitignore` 里，不会进版本库。

> 顺带一提：Supabase 默认要求注册后去邮箱点确认链接。想省掉这一步，
> 到 **Authentication → Providers → Email** 把 **Confirm email** 关掉。

## 开发运行

日常操作都走项目里的脚本，它会自动处理好环境变量和路径问题：

```powershell
.\tool\dev.ps1 get        # 拉依赖
.\tool\dev.ps1 gen        # 生成本地数据库代码（改了 database.dart 后要重跑）
.\tool\dev.ps1 analyze    # 静态检查，应当零问题
.\tool\dev.ps1 test       # 跑单元测试
.\tool\dev.ps1 run -d windows   # 在电脑上直接跑
.\tool\dev.ps1 run              # 自动选设备
```

脚本存在的理由有两个，都不是可选项：

- **路径**：本机用户名是中文，而 Dart 的 AOT 编译器（`build_runner` 和
  `flutter analyze` 都会用到）写不了含非 ASCII 字符的路径，直接跑会报
  `Unable to write file`。脚本会建一个纯英文的目录联接 `D:\work\mod`
  指向本目录，所有工具从那里执行。
- **缓存位置**：Flutter、pub、Gradle、Android SDK 的缓存和临时目录统一指向
  D 盘，不占 C 盘。
- **原生库**：`sqlite3` 包会在构建时从 GitHub Releases 下载 .so/.dll，
  而 GitHub 主站在国内直连不通。脚本会先用镜像把这些文件下好、按官方
  SHA-256 校验后放进构建缓存，构建阶段就直接复用，不再联网。

### 本机已装好的环境

| 组件 | 位置 |
| --- | --- |
| Flutter SDK（含 Dart） | `D:\flutter` |
| pub 包缓存 | `D:\pub-cache` |
| Android SDK | `D:\Android\Sdk`（platform-tools 37、build-tools 36.0.0、android-36、NDK r28c） |
| Gradle 缓存 | `D:\gradle` |
| 临时目录 | `D:\temp` |
| JDK | `D:\java17`（已有，复用） |
| Visual Studio C++ 工具链安装包 | `D:\VSBuildTools\vs_BuildTools.exe`（还没装，见下） |

另外设了用户级环境变量 `FLUTTER_STORAGE_BASE_URL` 和 `PUB_HOSTED_URL` 指向国内镜像，
否则从官方源下载基本会超时；Gradle 发行包也换成了腾讯云镜像，并用官方公布的
SHA-256 校验完整性（见 `android/gradle/wrapper/gradle-wrapper.properties`）。

### 下载慢的话

Flutter 和 pub 的官方源在国内可能很慢，可以先设这两个环境变量再执行：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
```

## 打包

### Android

```powershell
.\tool\dev.ps1 apk
```

产物：`build\app\outputs\flutter-apk\app-release.apk`。传到手机上，在设置里允许
「安装未知来源的应用」后点开安装即可。

> 这个安装包用调试密钥签名，够自己用；要上架应用商店需要另外配置正式签名。

### Windows

```powershell
.\tool\dev.ps1 win
```

产物：`build\windows\x64\runner\Release\` 整个文件夹（exe 和依赖的 dll 必须放在一起），
压缩后拷到别的电脑解压双击即可。没做代码签名，首次运行 Windows SmartScreen 会拦一下，
选「更多信息 → 仍要运行」。

**这一步现在会失败**，因为 Windows 原生构建依赖 Visual Studio 的 C++ 工具链，
而安装它需要管理员权限。用管理员身份打开 PowerShell 执行（约 7GB，装到 D 盘）：

```powershell
D:\VSBuildTools\vs_BuildTools.exe --quiet --wait --norestart `
  --installPath "D:\VSBuildTools" `
  --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
```

还有一件事同样需要管理员：Windows 上 Flutter 加载插件需要创建符号链接，
要打开系统的**开发者模式**（设置 → 系统 → 开发者选项）。命令行方式也可以：

```powershell
Start-Process ms-settings:developers
```

这两步做完，`flutter doctor` 里 Windows 那项会变成绿色，`.\tool\dev.ps1 win` 就能跑通。

希望 C 盘一个字节都不占的话，把 `--quiet` 去掉改成图形界面安装，在
**安装位置** 页把「共享组件、工具和 SDK」也指到 D 盘（Windows SDK 那部分约 2-3GB
默认会落在 `C:\Program Files (x86)\Windows Kits`）。

## 同步是怎么工作的

客户端分三层，界面层只读本地库，不直接碰网络。这是断网可用、以及同步逻辑能被
单独测试的前提。

| 层 | 位置 | 职责 |
| --- | --- | --- |
| 本地库 | `lib/data/local/` | SQLite 存一份完整镜像，多记 `baseVersion` 和脏标记 |
| 远端 | `lib/data/remote/` | Supabase 的读写和实时订阅 |
| 同步引擎 | `lib/data/sync/` | 推送、拉取、冲突判定，纯逻辑，可单测 |

每轮同步固定「先推后拉」：

1. **推送**：把本地所有带脏标记的笔记按修改时间顺序上传。更新语句带条件
   `version = 上次同步成功时的版本号`，这是乐观锁——匹配不到行就说明期间被别人改过。
2. **冲突**：本地这份内容另存成一条新笔记，标题后加「（冲突副本 2026-09-18 14:30）」；
   原笔记接受服务端的最新版本。两边内容都在，你自己决定怎么合。
   如果撞车的是「本地删、远端改」，则反过来把远端那份留成副本，删除照常生效。
3. **拉取**：按更新时间增量拉，逐条比版本号写入本地。本地还有没推上去的改动就先跳过，
   留给下一轮推送处理，绝不会把刚写的内容盖掉。
4. **实时**：App 在前台时订阅服务端推送，通常 1-2 秒就能看到另一端的改动；
   推送事件带设备标识，自己刚写的那条会被过滤掉，不做无谓的重写。

同步的触发时机：App 启动、从后台切回前台、网络恢复时各拉一次，前台的另一层保险是
每 60 秒兜底跑一轮，防止实时通道静默断开后长时间不同步。

所有时间戳都由数据库触发器用服务端时间生成，手机和电脑的系统时间不一致也不会
影响增量同步的正确性。

## 测试

```powershell
flutter test
```

同步引擎的分支用内存版的本地库和远端来测，覆盖新建上传、正常更新、软删除、
两种冲突场景、增量拉取、实时推送过滤、断网中断等路径，不依赖网络。

## 现在的范围和限制

已实现：纯文本笔记的增删改查、搜索、双端双向同步、离线可用、冲突副本。

还没做（属于后续可加的功能）：富文本、图片附件、文件夹和标签、手写、分享协作、
与本地 `.md` 文件互通、端到端加密（服务端目前是明文存储，靠行级权限隔离）。

另外两点要知道：

- Supabase 免费项目连续 7 天没有任何访问会被自动暂停，到面板点一下就能恢复。
- 手机端只在 App 打开或切回前台时同步，没有做后台常驻推送和通知。
