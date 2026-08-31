#!/bin/bash
set -e

echo "=============================================="
echo "        🔋 Android Battery Health Checker"
echo "=============================================="

WORK_DIR="/tmp/adb_temp"
ADB_BIN="$WORK_DIR/platform-tools/adb"
CACHE_FILE="$(dirname "$0")/known_capacities.txt"

# 1. ADBの自動ダウンロード
if [ ! -f "$ADB_BIN" ]; then
    echo "📦 ADBをダウンロード中..."
    mkdir -p "$WORK_DIR"
    curl -sL "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" -o "$WORK_DIR/adb.zip"
    unzip -q "$WORK_DIR/adb.zip" -d "$WORK_DIR"
    rm -f "$WORK_DIR/adb.zip"
fi

"$ADB_BIN" start-server >/dev/null 2>&1

mapfile -t DEVICES < <(
    "$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}'
)

if [ ${#DEVICES[@]} -eq 0 ]; then
    echo "❌ Android端末が接続されていません"
    exit 1
fi

for SERIAL in "${DEVICES[@]}"; do
    MODEL=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')
    BRAND=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.brand | tr -d '\r')

    echo
    echo "📱 $BRAND $MODEL"
    echo "   Serial: $SERIAL"
    echo "----------------------------------------------"

    DESIGN_MAH=""

    # 1. OSからの自動判定試行
    POWER_CAP=$("$ADB_BIN" -s "$SERIAL" shell dumpsys power 2>/dev/null | awk -F'=' '/mBatteryCapacity/ {print $2}' | tr -d '\r ')
    if [[ "$POWER_CAP" =~ ^[0-9]+$ ]] && [ "$POWER_CAP" -gt 1000 ]; then
        DESIGN_MAH="$POWER_CAP"
    fi

    # 2. 保存済みキャッシュ（known_capacities.txt）から検索
    if [ -z "$DESIGN_MAH" ] && [ -f "$CACHE_FILE" ]; then
        DESIGN_MAH=$(grep "^${MODEL}=" "$CACHE_FILE" | cut -d'=' -f2 | tr -d '\r')
    fi

    # 3. 内蔵リストから判定
    if [ -z "$DESIGN_MAH" ]; then
        case "$MODEL" in
        esac
    fi

    # 現在のバッテリー状態
    BATTERY=$("$ADB_BIN" -s "$SERIAL" shell dumpsys battery)

    LEVEL=$(echo "$BATTERY" | awk '/level:/ {print $2; exit}' | tr -d '\r')
    VOLTAGE=$(echo "$BATTERY" | awk '/voltage:/ {print $2; exit}' | tr -d '\r')
    TEMP=$(echo "$BATTERY" | awk '/temperature:/ {print $2; exit}' | tr -d '\r')
    COUNTER=$(echo "$BATTERY" | awk '/Charge counter:/ {print $3; exit}' | tr -d '\r')

    echo "🔋 残量     : ${LEVEL:-?}%"
    [ -n "$VOLTAGE" ] && echo "⚡ 電圧     : $(awk "BEGIN {printf \"%.3f\", $VOLTAGE/1000}") V"
    [ -n "$TEMP" ]    && echo "🌡️ 温度     : $(awk "BEGIN {printf \"%.1f\", $TEMP/10}") °C"
    [[ "$COUNTER" =~ ^[0-9]+$ ]] && echo "📊 残量推定 : $(awk "BEGIN {printf \"%.0f\", $COUNTER/1000}") mAh"

    echo
    echo "🔎 Android学習容量（現在の実効容量）を取得中..."

    STATS=$("$ADB_BIN" -s "$SERIAL" shell dumpsys batterystats 2>/dev/null)

    EST=$(echo "$STATS" | grep -i "Estimated battery capacity:" | tail -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' | tr -d '\r')
    LAST=$(echo "$STATS" | grep -i "Last learned battery capacity:" | tail -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' | tr -d '\r')

    CAPACITY="${LAST:-$EST}"

    # 4. どうしても取れない場合はユーザーに手入力させる（＆ファイルに保存）
    if [ -n "$CAPACITY" ] && [ -z "$DESIGN_MAH" ]; then
        echo
        echo "⚠️  $MODEL の公称容量（カタログ値）が自動取得できませんでした。"
        echo "    (参考: 現在の推定実効容量は ${CAPACITY} mAh です)"
        read -p "👉 この機種の公称容量 (mAh) を手入力してください (例: 5000): " INPUT_MAH
        if [[ "$INPUT_MAH" =~ ^[0-9]+$ ]] && [ "$INPUT_MAH" -gt 500 ]; then
            DESIGN_MAH="$INPUT_MAH"
            echo "${MODEL}=${DESIGN_MAH}" >> "$CACHE_FILE"
            echo "💾 次回用に容量設定を保存しました (${CACHE_FILE})"
        fi
    fi

    # 計算と表示
    if [[ "$CAPACITY" =~ ^[0-9]+$ ]] && [ -n "$DESIGN_MAH" ]; then
        HEALTH=$(awk -v c="$CAPACITY" -v d="$DESIGN_MAH" 'BEGIN {printf "%.1f", c/d*100}')
        WEAR=$(awk -v h="$HEALTH" 'BEGIN {printf "%.1f", 100-h}')

        echo
        echo "=============================================="
        echo "📐 公称容量       : ${DESIGN_MAH} mAh"
        echo "📊 現在の実効容量 : ${CAPACITY} mAh"
        echo "❤️ バッテリー健康度 : ${HEALTH}%"
        echo "📉 推定劣化率       : ${WEAR}%"
        echo "=============================================="
    elif [ -n "$CAPACITY" ]; then
        echo
        echo "⚠️ 公称容量が指定されなかったため、健康度は未計算です (実効容量: ${CAPACITY} mAh)"
    else
        echo
        echo "⚠️ Androidから学習容量を取得できませんでした。"
    fi
done

echo
echo "=============================================="
echo "               完了 🔋"
echo "=============================================="
