<#
同步备忘录的开发脚本。

用法（在项目根目录执行）：
    .\tool\dev.ps1 gen        生成本地数据库代码（改过 database.dart 后要跑）
    .\tool\dev.ps1 analyze    静态检查
    .\tool\dev.ps1 test       跑单元测试
    .\tool\dev.ps1 apk        打 Android 安装包
    .\tool\dev.ps1 win        打 Windows 桌面版
    .\tool\dev.ps1 run        在当前设备上直接运行

为什么要绕这么一圈：
1. Dart 的 AOT 编译器（build_runner 和 flutter analyze 都会用到）写不了含非 ASCII
   字符的路径，而本机用户名是中文。所以脚本会建一个纯英文的目录联接
   D:\work\mod 指向本目录，所有工具都从那里执行。
2. Flutter/Gradle/Android 的缓存和临时目录统一放到 D 盘，避免占用 C 盘。
#>

param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$asciiRoot = 'D:\work\mod'
$flutter = 'D:\flutter\bin\flutter.bat'
$dart = 'D:\flutter\bin\dart.bat'

# --- 1. 确保纯英文路径可用 -------------------------------------------------
if (-not (Test-Path $asciiRoot)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $asciiRoot) | Out-Null
    New-Item -ItemType Junction -Path $asciiRoot -Target $projectRoot | Out-Null
}

# --- 2. 环境变量：缓存和临时文件都指向 D 盘 --------------------------------
$env:PUB_CACHE = 'D:\pub-cache'
$env:ANDROID_HOME = 'D:\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'D:\Android\Sdk'
$env:GRADLE_USER_HOME = 'D:\gradle'
$env:JAVA_HOME = 'D:\java17'
if (-not (Test-Path 'D:\temp')) { New-Item -ItemType Directory -Force -Path 'D:\temp' | Out-Null }
$env:TEMP = 'D:\temp'
$env:TMP = 'D:\temp'

# 国内镜像，直连官方源基本下不动
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'

Set-Location $asciiRoot

# --- 3. 预置 sqlite3 的原生库 ----------------------------------------------
#
# sqlite3 包通过 Dart 的 build hook 从 GitHub Releases 下载 .so/.dll，
# 而 GitHub 主站在国内直连不通，构建会卡在下载上。这里提前用镜像拉好，
# 校验官方 SHA-256 之后放进 hook 的缓存目录；hook 发现文件已存在且哈希
# 对得上就会直接复用，不再联网。
#
# 这些文件放在 .dart_tool 下，flutter clean 会清掉，所以每次跑命令都检查一遍。
function Ensure-SqliteNativeAssets {
    $release = 'sqlite3-3.6.0'
    $cache = Join-Path $asciiRoot '.dart_tool\hooks_runner\shared\sqlite3\build'
    $assets = @(
        @{ Dir = 'download-0c2d3bfc'; Src = 'libsqlite3.arm64.android.so'; Dst = 'libsqlite3.so'
           Sha = '0c2d3bfc8c87abceb21ed72a4bb49964121c5fe1a8ef3848d83ba907d01b6161' },
        @{ Dir = 'download-a42fa9d0'; Src = 'libsqlite3.arm.android.so';   Dst = 'libsqlite3.so'
           Sha = 'a42fa9d0f5c006d30b000d4904bc497705191c5d7330b178618546004295bb49' },
        @{ Dir = 'download-949965f0'; Src = 'libsqlite3.x64.android.so';   Dst = 'libsqlite3.so'
           Sha = '949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772' },
        @{ Dir = 'download-c5a4ebf9'; Src = 'sqlite3.x64.windows.dll';     Dst = 'sqlite3.dll'
           Sha = 'c5a4ebf9922c63fa252a01c4679992f1fbaa2762b962b78ba6cbdc5cbf7ca91c' }
    )

    foreach ($asset in $assets) {
        $dir = Join-Path $cache $asset.Dir
        $dest = Join-Path $dir $asset.Dst
        if (Test-Path $dest) {
            $current = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
            if ($current -eq $asset.Sha) { continue }
        }

        Write-Host "准备原生库 $($asset.Src) ..." -ForegroundColor DarkGray
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $tmp = Join-Path $env:TEMP $asset.Src
        $url = "https://ghproxy.net/https://github.com/simolus3/sqlite3.dart/releases/download/$release/$($asset.Src)"
        & curl.exe -L -sS --max-time 300 -o $tmp $url

        $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $asset.Sha) {
            throw "原生库 $($asset.Src) 校验失败（实际 $actual）。下载通道可能被拦截，请关掉再试。"
        }
        Copy-Item $tmp -Destination $dest -Force
    }
}

function Invoke-Flutter {
    param([string[]]$Arguments)
    & $flutter @Arguments
    exit $LASTEXITCODE
}

function Invoke-Dart {
    param([string[]]$Arguments)
    & $dart @Arguments
    exit $LASTEXITCODE
}

function Assert-Config {
    if (-not (Test-Path (Join-Path $asciiRoot 'config.json'))) {
        Write-Host '还没有 config.json，先照着 config.example.json 填好 Supabase 的地址和 Key。' -ForegroundColor Yellow
        exit 1
    }
}

if ($Command -notin @('help', '')) {
    Ensure-SqliteNativeAssets
}

switch ($Command) {
    'gen' {
        Invoke-Dart @('run', 'build_runner', 'build')
    }
    'analyze' {
        Invoke-Flutter @('analyze')
    }
    'test' {
        Invoke-Flutter @('test')
    }
    'apk' {
        Assert-Config
        Invoke-Flutter @('build', 'apk', '--release', '--dart-define-from-file=config.json')
    }
    'win' {
        Assert-Config
        Invoke-Flutter @('build', 'windows', '--release', '--dart-define-from-file=config.json')
    }
    'run' {
        Assert-Config
        Invoke-Flutter (@('run', '--dart-define-from-file=config.json') + $Rest)
    }
    'get' {
        Invoke-Flutter @('pub', 'get')
    }
    default {
        Write-Host '用法：.\tool\dev.ps1 <gen|analyze|test|apk|win|run|get>' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  gen      生成本地数据库代码'
        Write-Host '  analyze  静态检查'
        Write-Host '  test     跑单元测试'
        Write-Host '  apk      打 Android 安装包'
        Write-Host '  win      打 Windows 桌面版'
        Write-Host '  run      直接运行（可追加设备参数，如 run -d windows）'
        Write-Host '  get      拉取依赖'
    }
}
