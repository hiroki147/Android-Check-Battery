# UTF-8対応
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host "        🔋 Android Battery Health Checker"
Write-Host "=============================================="

# ==============================================
# 1. ADBの自動セットアップ
# ==============================================

$WorkDir = Join-Path $env:TEMP "adb_temp"
$AdbZip = Join-Path $WorkDir "platform-tools.zip"
$AdbExe = Join-Path $WorkDir "platform-tools\adb.exe"

if (-not (Test-Path $AdbExe)) {

    Write-Host "📦 ADBをダウンロード中..." -ForegroundColor Cyan

    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

    $AdbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

    Invoke-WebRequest `
        -Uri $AdbUrl `
        -OutFile $AdbZip

    Write-Host "📂 展開中..." -ForegroundColor Cyan

    Expand-Archive `
        -Path $AdbZip `
        -DestinationPath $WorkDir `
        -Force

    Remove-Item $AdbZip -Force
}

# ==============================================
# 2. ADBサーバー起動
# ==============================================

$null = & $AdbExe start-server 2>&1

# ==============================================
# 3. Android端末取得
# ==============================================

$devices = & $AdbExe devices |
    Select-String -Pattern "\tdevice$" |
    ForEach-Object {
        ($_ -split "\s+")[0]
    }

if (-not $devices) {

    Write-Host ""
    Write-Host "❌ Android端末が接続されていません。" -ForegroundColor Red
    Write-Host "   USBデバッグがONになっているか確認してください。"
    Write-Host ""

    Read-Host "Enterキーで終了"
    exit 1
}

# ==============================================
# 4. 接続端末ごとに処理
# ==============================================

foreach ($serial in $devices) {

    $model = (& $AdbExe -s $serial shell getprop ro.product.model).Trim()
    $brand = (& $AdbExe -s $serial shell getprop ro.product.brand).Trim()

    Write-Host ""
    Write-Host "📱 $brand $model"
    Write-Host "   Serial: $serial"
    Write-Host "----------------------------------------------"

    # ==========================================
    # 公称容量
    # ==========================================

    $designMah = $null

    if ($model -like "XIG03*" -or $model -like "Redmi*") {
        $designMah = 5000
    }
    elseif ($model -like "P780*") {
        $designMah = 2630
    }

    # ==========================================
    # バッテリー情報
    # ==========================================

    $battery = & $AdbExe -s $serial shell dumpsys battery

    $level = (
        $battery |
        Select-String "level:" |
        ForEach-Object {
            ($_ -split ":\s*")[1]
        }
    ) -replace '\r',''

    $voltageRaw = (
        $battery |
        Select-String "voltage:" |
        ForEach-Object {
            ($_ -split ":\s*")[1]
        }
    ) -replace '\r',''

    $tempRaw = (
        $battery |
        Select-String "temperature:" |
        ForEach-Object {
            ($_ -split ":\s*")[1]
        }
    ) -replace '\r',''

    $counterRaw = (
        $battery |
        Select-String "Charge counter:" |
        ForEach-Object {
            ($_ -split ":\s*")[1]
        }
    ) -replace '\r',''

    Write-Host "🔋 残量     : $(if ($level) { $level } else { '?' })%"

    if ($voltageRaw) {
        Write-Host "⚡ 電圧     : $([math]::Round([double]$voltageRaw / 1000, 3)) V"
    }

    if ($tempRaw) {
        Write-Host "🌡️ 温度     : $([math]::Round([double]$tempRaw / 10, 1)) °C"
    }

    if ($counterRaw -match '^\d+$') {
        Write-Host "📊 残量推定 : $([math]::Floor([double]$counterRaw / 1000)) mAh"
    }

    # ==========================================
    # Android学習容量
    # ==========================================

    Write-Host ""
    Write-Host "🔎 Android学習容量を取得中..."

    $stats = & $AdbExe -s $serial shell dumpsys batterystats 2>$null

    function Get-Capacity ($pattern) {

        $matches = $stats | Select-String -Pattern $pattern

        if ($matches) {

            $lastLine = $matches[-1].Line

            if ($lastLine -match ':\s*(\d+)') {
                return [int]$Matches[1]
            }
        }

        return $null
    }

    $est  = Get-Capacity "Estimated battery capacity:"
    $last = Get-Capacity "Last learned battery capacity:"
    $min  = Get-Capacity "Min learned battery capacity:"
    $max  = Get-Capacity "Max learned battery capacity:"

    Write-Host ""
    Write-Host "📈 学習容量"

    if ($est) {
        Write-Host "  推定容量       : $est mAh"
    }

    if ($last) {
        Write-Host "  最終学習容量   : $last mAh"
    }

    if ($min) {
        Write-Host "  最小学習容量   : $min mAh"
    }

    if ($max) {
        Write-Host "  最大学習容量   : $max mAh"
    }

    # ==========================================
    # 使用する容量
    # ==========================================

    $capacity = if ($last) {
        $last
    }
    else {
        $est
    }

    # ==========================================
    # 健康度計算
    # ==========================================

    Write-Host ""

    if ($capacity -and $designMah) {

        $health = [math]::Round(
            ($capacity / $designMah) * 100,
            1
        )

        $wear = [math]::Round(
            100 - $health,
            1
        )

        Write-Host "=============================================="
        Write-Host "📐 公称容量       : $designMah mAh"
        Write-Host "📊 現在の実効容量 : $capacity mAh"
        Write-Host "❤️ バッテリー健康度 : ${health}%"
        Write-Host "📉 推定劣化率       : ${wear}%"
        Write-Host "=============================================="
    }
    elseif ($capacity) {

        Write-Host "⚠️ 学習容量は取得できましたが、公称容量が未登録です。"
        Write-Host "   学習容量 : $capacity mAh"
    }
    else {

        Write-Host "⚠️ Androidから学習容量を取得できませんでした。"
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "               完了 🔋"
Write-Host "=============================================="
Write-Host ""

Read-Host "Enterキーで終了"
