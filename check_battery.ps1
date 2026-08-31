$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host "        🔋 Android Battery Health Checker"
Write-Host "=============================================="

# 1. ADBの自動セットアップ
$WorkDir = Join-Path $env:TEMP "adb_temp"
$AdbZip = Join-Path $WorkDir "platform-tools.zip"
$AdbExe = Join-Path $WorkDir "platform-tools\adb.exe"
$CacheFile = Join-Path $PSScriptRoot "known_capacities.txt"

if (-not (Test-Path $AdbExe)) {
    Write-Host "📦 ADBをダウンロード中..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    
    $AdbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    Invoke-WebRequest -Uri $AdbUrl -OutFile $AdbZip
    
    Write-Host "📂 展開中..." -ForegroundColor Cyan
    Expand-Archive -Path $AdbZip -DestinationPath $WorkDir -Force
    Remove-Item $AdbZip -Force
}

# 2. ADBサーバー起動
& $AdbExe start-server *>$null

# 3. 端末取得
$devices = & $AdbExe devices | Select-String -Pattern "\tdevice$" | ForEach-Object { ($_ -split "\s+")[0] }

if (-not $devices) {
    Write-Host "❌ Android端末が接続されていません" -ForegroundColor Red
    exit 1
}

foreach ($serial in $devices) {
    $model = (& $AdbExe -s $serial shell getprop ro.product.model).Trim()
    $brand = (& $AdbExe -s $serial shell getprop ro.product.brand).Trim()

    Write-Host ""
    Write-Host "📱 $brand $model"
    Write-Host "   Serial: $serial"
    Write-Host "----------------------------------------------"

    $designMah = $null

    # 1. OSからの自動判定試行
    $powerOut = & $AdbExe -s $serial shell dumpsys power 2>$null
    if ($powerOut -match 'mBatteryCapacity=(\d+)') {
        $designMah = [int]$Matches[1]
    }

    # 2. 保存済みキャッシュ（known_capacities.txt）から検索
    if (-not $designMah -and (Test-Path $CacheFile)) {
        $match = Get-Content $CacheFile | Select-String -Pattern "^$([regex]::Escape($model))=(.+)$"
        if ($match) {
            $designMah = [int]$match.Matches[0].Groups[1].Value
        }
    }

    # 3. 内蔵リスト参照
    if (-not $designMah) {
        if ($model -like "XIG03*" -or $model -like "Redmi*") { $designMah = 5000 }
        elseif ($model -like "P780*") { $designMah = 2630 }
    }

    # バッテリー状態
    $battery = & $AdbExe -s $serial shell dumpsys battery

    $level = ($battery | Select-String "level:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $voltageRaw = ($battery | Select-String "voltage:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $tempRaw = ($battery | Select-String "temperature:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $counterRaw = ($battery | Select-String "Charge counter:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''

    Write-Host "🔋 残量     : $(if ($level) { $level } else { '?' })%"
    if ($voltageRaw) { Write-Host "⚡ 電圧     : $([math]::Round([double]$voltageRaw / 1000, 3)) V" }
    if ($tempRaw) { Write-Host "🌡️ 温度     : $([math]::Round([double]$tempRaw / 10, 1)) °C" }
    if ($counterRaw -match '^\d+$') { Write-Host "📊 残量推定 : $([math]::Floor([double]$counterRaw / 1000)) mAh" }

    Write-Host ""
    Write-Host "🔎 Android学習容量（現在の実効容量）を取得中..."

    $stats = & $AdbExe -s $serial shell dumpsys batterystats 2>$null

    function Get-Capacity ($pattern) {
        $matches = $stats | Select-String -Pattern $pattern
        if ($matches) {
            $lastLine = $matches[-1].Line
            if ($lastLine -match ':\s*(\d+)') { return [int]$Matches[1] }
        }
        return $null
    }

    $est = Get-Capacity "Estimated battery capacity:"
    $last = Get-Capacity "Last learned battery capacity:"

    $capacity = if ($last) { $last } else { $est }

    # 4. 手入力フォールバック（ファイル保存機能つき）
    if ($capacity -and -not $designMah) {
        Write-Host ""
        Write-Host "⚠️  $model の公称容量（カタログ値）が自動取得できませんでした。" -ForegroundColor Yellow
        Write-Host "    (参考: 現在の推定実効容量は $capacity mAh です)"
        $inputMah = Read-Host "👉 この機種の公称容量 (mAh) を手入力してください (例: 5000)"
        if ($inputMah -match '^\d+$' -and [int]$inputMah -gt 500) {
            $designMah = [int]$inputMah
            "$model=$designMah" | Out-File -FilePath $CacheFile -Append -Encoding utf8
            Write-Host "💾 次回用に容量設定を保存しました ($CacheFile)" -ForegroundColor Green
        }
    }

    Write-Host ""
    if ($capacity -and $designMah) {
        $health = [math]::Round(($capacity / $designMah) * 100, 1)
        $wear = [math]::Round(100 - $health, 1)

        Write-Host "=============================================="
        Write-Host "📐 公称容量       : $designMah mAh"
        Write-Host "📊 現在の実効容量 : $capacity mAh"
        Write-Host "❤️ バッテリー健康度 : ${health}%"
        Write-Host "📉 推定劣化率       : ${wear}%"
        Write-Host "=============================================="
    } elseif ($capacity) {
        Write-Host "⚠️ 公称容量が指定されなかったため、健康度は未計算です (実効容量: $capacity mAh)"
    } else {
        Write-Host "⚠️ Androidから学習容量を取得できませんでした。"
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "               完了 🔋"
Write-Host "=============================================="$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host "        🔋 Android Battery Health Checker"
Write-Host "=============================================="

# 1. ADBの自動セットアップ
$WorkDir = Join-Path $env:TEMP "adb_temp"
$AdbZip = Join-Path $WorkDir "platform-tools.zip"
$AdbExe = Join-Path $WorkDir "platform-tools\adb.exe"

if (-not (Test-Path $AdbExe)) {
    Write-Host "📦 ADBをダウンロード中..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    
    # Google公式からダウンロード
    $AdbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    Invoke-WebRequest -Uri $AdbUrl -OutFile $AdbZip
    
    Write-Host "📂 展開中..." -ForegroundColor Cyan
    Expand-Archive -Path $AdbZip -DestinationPath $WorkDir -Force
    Remove-Item $AdbZip -Force
}

# 2. ADBサーバー起動
& $AdbExe start-server *>$null

# 3. 端末取得
$devices = & $AdbExe devices | Select-String -Pattern "\tdevice$" | ForEach-Object { ($_ -split "\s+")[0] }

if (-not $devices) {
    Write-Host "❌ Android端末が接続されていません (USBデバッグがONか確認してください)" -ForegroundColor Red
    exit 1
}

foreach ($serial in $devices) {
    $model = (& $AdbExe -s $serial shell getprop ro.product.model).Trim()
    $brand = (& $AdbExe -s $serial shell getprop ro.product.brand).Trim()

    Write-Host ""
    Write-Host "📱 $brand $model"
    Write-Host "   Serial: $serial"
    Write-Host "----------------------------------------------"

    # 公称容量の設定
    $designMah = $null
    if ($model -like "XIG03*" -or $model -like "Redmi*") { $designMah = 5000 }
    elseif ($model -like "P780*") { $designMah = 2630 }

    # バッテリー状態
    $battery = & $AdbExe -s $serial shell dumpsys battery

    $level = ($battery | Select-String "level:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $voltageRaw = ($battery | Select-String "voltage:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $tempRaw = ($battery | Select-String "temperature:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''
    $counterRaw = ($battery | Select-String "Charge counter:" | ForEach-Object { ($_ -split ":\s*")[1] }) -replace '\r',''

    Write-Host "🔋 残量     : $(if ($level) { $level } else { '?' })%"
    if ($voltageRaw) { Write-Host "⚡ 電圧     : $([math]::Round([double]$voltageRaw / 1000, 3)) V" }
    if ($tempRaw) { Write-Host "🌡️ 温度     : $([math]::Round([double]$tempRaw / 10, 1)) °C" }
    if ($counterRaw -match '^\d+$') { Write-Host "📊 残量推定 : $([math]::Floor([double]$counterRaw / 1000)) mAh" }

    Write-Host ""
    Write-Host "🔎 Android学習容量を取得中..."

    $stats = & $AdbExe -s $serial shell dumpsys batterystats 2>$null

    function Get-Capacity ($pattern) {
        $matches = $stats | Select-String -Pattern $pattern
        if ($matches) {
            $lastLine = $matches[-1].Line
            if ($lastLine -match ':\s*(\d+)') { return [int]$Matches[1] }
        }
        return $null
    }

    $est = Get-Capacity "Estimated battery capacity:"
    $last = Get-Capacity "Last learned battery capacity:"
    $min = Get-Capacity "Min learned battery capacity:"
    $max = Get-Capacity "Max learned battery capacity:"

    Write-Host ""
    Write-Host "📈 学習容量"
    if ($est)  { Write-Host "  推定容量       : $est mAh" }
    if ($last) { Write-Host "  最終学習容量   : $last mAh" }
    if ($min)  { Write-Host "  最小学習容量   : $min mAh" }
    if ($max)  { Write-Host "  最大学習容量   : $max mAh" }

    $capacity = if ($last) { $last } else { $est }

    Write-Host ""
    if ($capacity -and $designMah) {
        $health = [math]::Round(($capacity / $designMah) * 100, 1)
        $wear = [math]::Round(100 - $health, 1)

        Write-Host "=============================================="
        Write-Host "❤️ バッテリー健康度 : ${health}%"
        Write-Host "📉 推定劣化率       : ${wear}%"
        Write-Host "=============================================="
    } elseif ($capacity) {
        Write-Host "⚠️ 学習容量は取得できましたが、公称容量が未登録です。"
        Write-Host "   学習容量 : $capacity mAh"
    } else {
        Write-Host "⚠️ Androidから学習容量を取得できませんでした。"
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "               完了 🔋"
Write-Host "=============================================="
