#!/bin/bash
set -e

echo "=============================================="
echo "        🔋 Android Battery Health Checker"
echo "=============================================="

WORK_DIR="/tmp/adb_temp"
ADB_BIN="$WORK_DIR/platform-tools/adb"

# 1. ADBがない場合は自動ダウンロード
if [ ! -f "$ADB_BIN" ]; then
    echo "📦 ADBをダウンロード中..."
    mkdir -p "$WORK_DIR"
    curl -sL "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" -o "$WORK_DIR/adb.zip"
    
    echo "📂 展開中..."
    unzip -q "$WORK_DIR/adb.zip" -d "$WORK_DIR"
    rm -f "$WORK_DIR/adb.zip"
fi

# 2. ADB実行
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

    case "$MODEL" in
        XIG03|Redmi*) DESIGN_MAH=5000 ;;
        P780*)        DESIGN_MAH=2630 ;;
        *)            DESIGN_MAH="" ;;
    esac

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
    echo "🔎 Android学習容量を取得中..."

    STATS=$("$ADB_BIN" -s "$SERIAL" shell dumpsys batterystats 2>/dev/null)

    EST=$(echo "$STATS" | grep -i "Estimated battery capacity:" | tail -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' | tr -d '\r')
    LAST=$(echo "$STATS" | grep -i "Last learned battery capacity:" | tail -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' | tr -d '\r')

    CAPACITY="${LAST:-$EST}"

    if [[ "$CAPACITY" =~ ^[0-9]+$ ]] && [ -n "$DESIGN_MAH" ]; then
        HEALTH=$(awk -v c="$CAPACITY" -v d="$DESIGN_MAH" 'BEGIN {printf "%.1f", c/d*100}')
        WEAR=$(awk -v h="$HEALTH" 'BEGIN {printf "%.1f", 100-h}')

        echo "=============================================="
        echo "❤️ バッテリー健康度 : ${HEALTH}%"
        echo "📉 推定劣化率       : ${WEAR}%"
        echo "=============================================="
    elif [ -n "$CAPACITY" ]; then
        echo "⚠️ 公称容量未登録 (学習容量: ${CAPACITY} mAh)"
    else
        echo "⚠️ 学習容量を取得できませんでした。"
    fi
done

echo
echo "=============================================="
echo "               完了 🔋"
echo "=============================================="
