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

Write-Host "[1/3] Detecting Saleblazers game folder..." -ForegroundColor White
$gamePath = Find-SaleblazersPath

if (-not $gamePath) {
    Write-Host "Could not automatically locate the game folder." -ForegroundColor Yellow
    Write-Host "Please specify the path to your Saleblazers folder (where Saleblazers.exe is located):" -ForegroundColor Yellow
    Write-Host "Example: C:\Program Files (x86)\Steam\steamapps\common\Saleblazers\Default" -ForegroundColor Gray
    Write-Host ""
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
    Write-Host ""
    Write-Host "[ERROR] Saleblazers installation not found or folder does not contain Saleblazers.exe." -ForegroundColor Red
    exit 1
}

Write-Host "Game folder found: $gamePath" -ForegroundColor Green
Write-Host ""

Write-Host "[2/3] Installing BepInEx 6 CoreCLR, Doorstop, and Mod Loader..." -ForegroundColor White
$srcDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($srcDir)) { $srcDir = (Get-Location).Path }

# Ensure essential files exist in source
$requiredSourceFiles = @('winhttp.dll', 'doorstop_config.ini')
foreach ($f in $requiredSourceFiles) {
    if (-not (Test-Path (Join-Path $srcDir $f))) {
        Write-Host "[ERROR] Essential file $f is missing in installer directory!" -ForegroundColor Red
        exit 1
    }
}

# 1. Doorstop loader
Copy-Item (Join-Path $srcDir 'winhttp.dll') (Join-Path $gamePath 'winhttp.dll') -Force
Copy-Item (Join-Path $srcDir 'doorstop_config.ini') (Join-Path $gamePath 'doorstop_config.ini') -Force
Write-Host "  * Installed Doorstop loader (winhttp.dll)." -ForegroundColor Gray

# 2. .NET 6 Runtime
if (Test-Path (Join-Path $srcDir 'dotnet')) {
    $destDotnet = Join-Path $gamePath 'dotnet'
    Copy-Item (Join-Path $srcDir 'dotnet') $destDotnet -Recurse -Force
    Write-Host "  * Installed .NET 6 CoreCLR runtime." -ForegroundColor Gray
}

# 3. BepInEx directories
$destBep = Join-Path $gamePath 'BepInEx'
New-Item -ItemType Directory -Path $destBep -Force | Out-Null

if (Test-Path (Join-Path $srcDir 'BepInEx\core')) {
    Copy-Item (Join-Path $srcDir 'BepInEx\core') (Join-Path $destBep 'core') -Recurse -Force
    Write-Host "  * Installed BepInEx 6 IL2CPP core." -ForegroundColor Gray
}

if (Test-Path (Join-Path $srcDir 'BepInEx\interop')) {
    Copy-Item (Join-Path $srcDir 'BepInEx\interop') (Join-Path $destBep 'interop') -Recurse -Force
    Write-Host "  * Installed Unity 6 interop assemblies." -ForegroundColor Gray
}

# 4. Plugins (Mod Menu)
$destPlugins = Join-Path $destBep 'plugins'
New-Item -ItemType Directory -Path $destPlugins -Force | Out-Null

$modMenuSrc = Join-Path $srcDir 'BepInEx\plugins\Saleblazers.ModMenu.dll'
if (Test-Path $modMenuSrc) {
    Copy-Item $modMenuSrc (Join-Path $destPlugins 'Saleblazers.ModMenu.dll') -Force
    Write-Host "  * Installed built-in Mod Loader (Saleblazers.ModMenu.dll)." -ForegroundColor Gray
}

# 5. Config (if present)
if (Test-Path (Join-Path $srcDir 'BepInEx\config')) {
    $destCfg = Join-Path $destBep 'config'
    New-Item -ItemType Directory -Path $destCfg -Force | Out-Null
    Copy-Item (Join-Path $srcDir 'BepInEx\config\*') $destCfg -Recurse -Force
}

Write-Host ""
Write-Host "[3/3] Installation completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "What is ready in-game:" -ForegroundColor Yellow
Write-Host "  * Main menu shows the [MODS] button and active mods list." -ForegroundColor White
Write-Host "  * Bottom corner shows the [Modded] version tag." -ForegroundColor White
Write-Host "  * Toggle and configure mods directly from the menu." -ForegroundColor White
Write-Host ""
Write-Host "To install any additional mods (like JEI), place their .dll in:" -ForegroundColor Cyan
Write-Host "  $destPlugins" -ForegroundColor Gray
Write-Host ""
