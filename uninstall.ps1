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

Write-Host "Detecting Saleblazers game folder..." -ForegroundColor White
$gamePath = Find-SaleblazersPath

if (-not $gamePath) {
    Write-Host "Please specify your Saleblazers folder (where Saleblazers.exe is located):" -ForegroundColor Yellow
    $userInput = Read-Host "Game Path"
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
    Write-Host "[ERROR] Saleblazers game folder not found." -ForegroundColor Red
    exit 1
}

Write-Host "Game folder found: $gamePath" -ForegroundColor Green
Write-Host ""

$winHttp = Join-Path $gamePath 'winhttp.dll'
$doorstopCfg = Join-Path $gamePath 'doorstop_config.ini'
$dotnetDir = Join-Path $gamePath 'dotnet'
$bepDir = Join-Path $gamePath 'BepInEx'

if (-not (Test-Path $winHttp) -and -not (Test-Path $bepDir)) {
    Write-Host "BepInEx 6 modloader was not found in this folder. The game is already clean." -ForegroundColor Yellow
    exit 0
}

Write-Host "Select an uninstallation option:" -ForegroundColor Yellow
Write-Host "  [1] Disable mod loader (removes Doorstop and Mod Menu, keeps your custom mods in plugins)" -ForegroundColor White
Write-Host "  [2] Complete uninstall (completely removes BepInEx, dotnet, and Doorstop)" -ForegroundColor White
Write-Host "  [0] Cancel" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Your choice (1, 2, or 0)"

switch ($choice) {
    '1' {
        Write-Host ""
        Write-Host "Disabling mod loader..." -ForegroundColor White
        if (Test-Path $winHttp) { Remove-Item $winHttp -Force; Write-Host "  * Removed winhttp.dll" -ForegroundColor Gray }
        if (Test-Path $doorstopCfg) { Remove-Item $doorstopCfg -Force; Write-Host "  * Removed doorstop_config.ini" -ForegroundColor Gray }
        $menuDll = Join-Path $bepDir 'plugins\Saleblazers.ModMenu.dll'
        if (Test-Path $menuDll) { Remove-Item $menuDll -Force; Write-Host "  * Removed Saleblazers.ModMenu.dll" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "Done! The game will now launch in clean vanilla mode." -ForegroundColor Green
        Write-Host "To re-enable, run install.bat again." -ForegroundColor Cyan
    }
    '2' {
        Write-Host ""
        Write-Host "Performing complete uninstall..." -ForegroundColor White
        if (Test-Path $winHttp) { Remove-Item $winHttp -Force; Write-Host "  * Removed winhttp.dll" -ForegroundColor Gray }
        if (Test-Path $doorstopCfg) { Remove-Item $doorstopCfg -Force; Write-Host "  * Removed doorstop_config.ini" -ForegroundColor Gray }
        if (Test-Path $dotnetDir) { Remove-Item $dotnetDir -Recurse -Force; Write-Host "  * Removed dotnet folder" -ForegroundColor Gray }
        if (Test-Path $bepDir) { Remove-Item $bepDir -Recurse -Force; Write-Host "  * Removed BepInEx folder" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "Done! All modloader files have been completely removed." -ForegroundColor Green
    }
    default {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}
