[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

function Write-Banner {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "      Saleblazers BepInEx 6 & ModLoader Uninstaller       " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Find-SaleblazersPath {
    $candidates = [System.Collections.Generic.List[string]]::new()

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

    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    foreach ($d in $drives) {
        $candidates.Add((Join-Path $d 'Program Files (x86)\Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Program Files\Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'SteamLibrary\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Steam\steamapps\common\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Games\Saleblazers\Default'))
        $candidates.Add((Join-Path $d 'Games\Steam\steamapps\common\Saleblazers\Default'))
    }

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

Write-Host "Поиск установленной игры..." -ForegroundColor White
$gamePath = Find-SaleblazersPath

if (-not $gamePath) {
    Write-Host "Укажите путь к папке игры (где находится Saleblazers.exe):" -ForegroundColor Yellow
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
    Write-Host "[ОШИБКА] Папка игры не найдена." -ForegroundColor Red
    exit 1
}

Write-Host "Найдена игра: $gamePath" -ForegroundColor Green
Write-Host ""

$winHttp = Join-Path $gamePath 'winhttp.dll'
$doorstopCfg = Join-Path $gamePath 'doorstop_config.ini'
$dotnetDir = Join-Path $gamePath 'dotnet'
$bepDir = Join-Path $gamePath 'BepInEx'

if (-not (Test-Path $winHttp) -and -not (Test-Path $bepDir)) {
    Write-Host "Модлоадер BepInEx 6 не обнаружен в данной папке. Игра уже чистая." -ForegroundColor Yellow
    exit 0
}

Write-Host "Выберите вариант удаления:" -ForegroundColor Yellow
Write-Host "  [1] Отключить модлоадер (удалить Doorstop и Mod Menu, сохранив ваши моды в plugins)" -ForegroundColor White
Write-Host "  [2] Полное удаление (стереть BepInEx, dotnet и загрузчик полностью)" -ForegroundColor White
Write-Host "  [0] Отмена" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Ваш выбор (1, 2 или 0)"

if ($choice -eq '1') {
    Write-Host "Отключение модлоадера..." -ForegroundColor White
    if (Test-Path $winHttp) { Remove-Item $winHttp -Force; Write-Host "  * winhttp.dll удален" -ForegroundColor Gray }
    if (Test-Path $doorstopCfg) { Remove-Item $doorstopCfg -Force; Write-Host "  * doorstop_config.ini удален" -ForegroundColor Gray }
    if (Test-Path (Join-Path $bepDir 'plugins\Saleblazers.ModMenu.dll')) {
        Remove-Item (Join-Path $bepDir 'plugins\Saleblazers.ModMenu.dll') -Force
        Write-Host "  * Saleblazers.ModMenu.dll удален" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Модлоадер успешно отключен! Игра вернулась к ванильному состоянию." -ForegroundColor Green
    Write-Host "Ваши пользовательские моды и конфиги сохранены в папке BepInEx." -ForegroundColor Gray
} elseif ($choice -eq '2') {
    Write-Host "Полное удаление BepInEx..." -ForegroundColor White
    if (Test-Path $winHttp) { Remove-Item $winHttp -Force }
    if (Test-Path $doorstopCfg) { Remove-Item $doorstopCfg -Force }
    if (Test-Path $dotnetDir) { Remove-Item $dotnetDir -Recurse -Force }
    if (Test-Path $bepDir) { Remove-Item $bepDir -Recurse -Force }
    Write-Host ""
    Write-Host "Все файлы модов и BepInEx полностью удалены! Игра полностью чистая." -ForegroundColor Green
} else {
    Write-Host "Удаление отменено." -ForegroundColor Yellow
}
Write-Host ""
