[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

function Write-Banner {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "   Saleblazers BepInEx 6 & ModLoader Auto-Installer       " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Find-SaleblazersPath {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # 1. Check Steam Registry and libraryfolders.vdf
    try {
        $steamKey = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
        if ($steamKey -and $steamKey.SteamPath) {
            $steamPath = $steamKey.SteamPath.Replace('/', '\')
            $candidates.Add((Join-Path $steamPath 'steamapps\common\Saleblazers\Default'))
            $candidates.Add((Join-Path $steamPath 'steamapps\common\Saleblazers'))

            $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
            if (Test-Path $vdfPath) {
                $lines = Get-Content $vdfPath -Encoding UTF8 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -match '"path"\s+"([^"]+)"') {
                        $lib = $matches[1].Replace('\\', '\')
                        $candidates.Add((Join-Path $lib 'steamapps\common\Saleblazers\Default'))
                        $candidates.Add((Join-Path $lib 'steamapps\common\Saleblazers'))
                    }
                }
            }
        }
    } catch {}

    # 2. Check common drives
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    foreach ($d in $drives) {
        $candidates.Add((Join-Path $d 'Program Files (x86)\Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Program Files\Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'SteamLibrary\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Games\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Games\Steam\steamapps\common\Saleblazers\Default'))
    }

    # 3. Test each candidate for Saleblazers.exe
    foreach ($cand in $candidates) {
        if ([string]::IsNullOrWhiteSpace($cand)) { continue }
        $exe = Join-Path $cand 'Saleblazers.exe'
        if (Test-Path $exe) {
            return $cand
        }
    }

    return $null
}

Write-Banner

Write-Host "[1/3] Поиск папки игры Saleblazers..." -ForegroundColor White
$gamePath = Find-SaleblazersPath

if (-not $gamePath) {
    Write-Host "Не удалось автоматически определить папку с игрой." -ForegroundColor Yellow
    Write-Host "Пожалуйста, укажите путь к папке игры (где находится Saleblazers.exe):" -ForegroundColor Yellow
    Write-Host "Пример: C:\Program Files (x86)\Steam\steamapps\common\Saleblazers\Default" -ForegroundColor Gray
    Write-Host ""
    $userInput = Read-Host "Путь к игре"
    if ($userInput) {
        $clean = $userInput.Trim('"').Trim()
        if (Test-Path (Join-Path $clean 'Saleblazers.exe')) {
            $gamePath = $clean
        } elseif (Test-Path (Join-Path $clean 'Default\Saleblazers.exe')) {
            $gamePath = Join-Path $clean 'Default'
        }
    }
}

if (-not $gamePath -or -not (Test-Path (Join-Path $gamePath 'Saleblazers.exe'))) {
    Write-Host ""
    Write-Host "[ОШИБКА] Папка игры не найдена или не содержит Saleblazers.exe." -ForegroundColor Red
    exit 1
}

Write-Host "Папка игры найдена: $gamePath" -ForegroundColor Green
Write-Host ""

Write-Host "[2/3] Копирование компонентов BepInEx 6, Doorstop и Mod Menu..." -ForegroundColor White
$srcDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($srcDir)) { $srcDir = (Get-Location).Path }

# Ensure essential files exist in source
$requiredSourceFiles = @('winhttp.dll', 'doorstop_config.ini')
foreach ($f in $requiredSourceFiles) {
    if (-not (Test-Path (Join-Path $srcDir $f))) {
        Write-Host "[ОШИБКА] Файл $f отсутствует в папке установщика!" -ForegroundColor Red
        exit 1
    }
}

# 1. Doorstop loader
Copy-Item (Join-Path $srcDir 'winhttp.dll') (Join-Path $gamePath 'winhttp.dll') -Force
Copy-Item (Join-Path $srcDir 'doorstop_config.ini') (Join-Path $gamePath 'doorstop_config.ini') -Force
Write-Host "  * Загрузчик Doorstop (winhttp.dll) установлен." -ForegroundColor Gray

# 2. .NET 6 Runtime
if (Test-Path (Join-Path $srcDir 'dotnet')) {
    $destDotnet = Join-Path $gamePath 'dotnet'
    Copy-Item (Join-Path $srcDir 'dotnet') $destDotnet -Recurse -Force
    Write-Host "  * Среда .NET 6 CoreCLR установлена." -ForegroundColor Gray
}

# 3. BepInEx directories
$destBep = Join-Path $gamePath 'BepInEx'
New-Item -ItemType Directory -Path $destBep -Force | Out-Null

if (Test-Path (Join-Path $srcDir 'BepInEx\core')) {
    Copy-Item (Join-Path $srcDir 'BepInEx\core') (Join-Path $destBep 'core') -Recurse -Force
    Write-Host "  * Ядро BepInEx 6 IL2CPP скопировано." -ForegroundColor Gray
}

if (Test-Path (Join-Path $srcDir 'BepInEx\interop')) {
    Copy-Item (Join-Path $srcDir 'BepInEx\interop') (Join-Path $destBep 'interop') -Recurse -Force
    Write-Host "  * Интероп-библиотеки Unity 6 скопированы." -ForegroundColor Gray
}

# 4. Plugins (Mod Menu)
$destPlugins = Join-Path $destBep 'plugins'
New-Item -ItemType Directory -Path $destPlugins -Force | Out-Null

$modMenuSrc = Join-Path $srcDir 'BepInEx\plugins\Saleblazers.ModMenu.dll'
if (Test-Path $modMenuSrc) {
    Copy-Item $modMenuSrc (Join-Path $destPlugins 'Saleblazers.ModMenu.dll') -Force
    Write-Host "  * Встроенный менеджер модов (Saleblazers.ModMenu.dll) установлен." -ForegroundColor Gray
}

# 5. Config (if present)
if (Test-Path (Join-Path $srcDir 'BepInEx\config')) {
    $destCfg = Join-Path $destBep 'config'
    New-Item -ItemType Directory -Path $destCfg -Force | Out-Null
    Copy-Item (Join-Path $srcDir 'BepInEx\config\*') $destCfg -Recurse -Force
}

Write-Host ""
Write-Host "[3/3] Установка успешно завершена!" -ForegroundColor Green
Write-Host ""
Write-Host "Что теперь доступно в игре:" -ForegroundColor Yellow
Write-Host "  * В главном меню появится нативная кнопка [МОДЫ]." -ForegroundColor White
Write-Host "  * Рядом с версией игры в углу отображается метка [Modded]." -ForegroundColor White
Write-Host "  * Включать и отключать моды можно прямо в меню игры." -ForegroundColor White
Write-Host "  * Редактировать настройки (.cfg) можно прямо в игре на лету." -ForegroundColor White
Write-Host ""
Write-Host "Чтобы установить любые другие моды (например, JEI), просто кладите их .dll в:" -ForegroundColor Cyan
Write-Host "  $destPlugins" -ForegroundColor Gray
Write-Host ""
