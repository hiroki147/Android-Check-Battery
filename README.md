# Android-Check-Battery

Android端末のバッテリー健康度（劣化率）や学習容量をPCからワンクリックで確認できるツールです。
**事前準備（ADBのインストールなど）は一切不要**で、スクリプトを実行するだけで自動的に必要な環境をセットアップします。

## 特徴
- 📦 **環境構築不要**: スクリプト実行時にGoogle公式から最新のADBを自動ダウンロード
- 💻 **マルチOS対応**: Windows (PowerShell) と Linux (Bash) に対応
- 📊 **詳細表示**: バッテリー残量・電圧・温度・推定残量に加え、Androidが内部で学習した「実効容量（mAh）」と「健康度（%）」を表示

## 使い方

### Windows の場合
1. スマホの **設定 > 開発者向けオプション** から **USBデバッグ** をONにします。
2. スマホをUSBケーブルでPCに接続します。
3. [📥 run_check_battery.bat をダウンロード](https://github.com/hiroki147/Android-Check-Battery/raw/refs/heads/main/run_check_battery.bat)
4. `run_check_battery.bat` を右クリックして「PowerShell で実行」を選択します。

### Linux の場合
1. スマホの **USBデバッグ** をONにしてPCに接続します。
2. ターミナルで以下を実行します。
   ```bash
   wget https://raw.githubusercontent.com/hiroki147/Android-Check-Battery/refs/heads/main/check_battery.sh
   chmod +x check_battery.sh
   ./check_battery.sh
   ```
## 注意事項
- 初回実行時のみ、ADBのポータブル版を自動取得するためインターネット接続が必要です。
- スマホ画面に「USBデバッグを許可しますか？」と表示された場合は「許可」を選択してください。
- OS側から公称容量（カタログ値）が取得できない一部の機種（Xiaomiなど）では、初回のみ手入力を求められます。入力した数値は次回以降自動参照されます。
