# ビルドとテスト

## 必要なもの

- Windows x64
- Visual Studio 2022 Communityの「C++によるデスクトップ開発」
- Windowsに含まれる.NET Framework 4系のC#コンパイラー、Windows PowerShell 5.1
- Git

`build.cmd` はVisual Studio 2022 Communityの標準インストール先を使用します。別の場所へ導入している場合は `VSROOT` を設定してください。

## 配布EXEをビルドする

```powershell
git clone --recurse-submodules https://github.com/hinatamaxxx/windows-line-start-to-tray.git
cd windows-line-start-to-tray
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Release.ps1
```

`release` にセットアップEXEと `SHA256SUMS.txt` を出力します。セットアップにはネイティブEXE、32/64bitのDLL、導入・復元スクリプト、利用案内、ライセンスをリソースとして埋め込みます。LINE本体は含みません。

すでにビルド済みのネイティブファイルを使用する場合は `-SkipNativeBuild` を指定します。配布前には、埋め込まれたバイナリが検証済みのものと一致することを確認してください。

Microsoft Detoursはv4.0.1のコミット `e4bfd6b03e50de46b47abfbd1e46b384f0c5f833` に固定しています。

## セットアップのテスト

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Setup.ps1
```

セットアップEXEからリソースを取り出し、バイナリのハッシュ、導入、二重実行、設定の復元、再導入、ショートカットを確認します。テスト専用のフォルダーとレジストリを使い、現在のLINEの設定は変更しません。実際のLINEプロセスの存在は、このテストでは模擬します。

セットアップ画面は.NET FrameworkのWPFを使います。次のテストでは、テーマ切り替え、処理中の操作制限、狭い画面でのレイアウトを確認します。

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-SetupWindow.ps1
```

`--extract <directory>` はテスト用の展開オプションです。セットアップ処理やスタートアップ登録は実行しません。

## 表示制御のテスト

`tests/Fixture.cpp` と `tests/BuildFixture.cmd` に、32bitランチャーから64bitアプリを起動するテスト用アプリがあります。起動画面、初回メイン画面、閉じる処理、その後の再表示を確認するために使用します。

実際のLINEの表示を観測する場合は、LINEを通知領域から通常終了した後に、次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Observe-LineStartup.ps1
```

このテストは本ツールのインストール済みEXEからLINEを起動し、20秒間のWindows表示イベントと、終了時点のウィンドウ状態を出力します。LINEのログイン状態や会話内容は検査しません。PC再起動テストの代わりにはなりません。

## 公開するファイル

- `WindowsLineStartToTray-Setup-<version>.exe`
- `SHA256SUMS.txt`

ビルド出力、診断ログ、`startup-backup.json`、LINE本体はGitへ追加しません。新しい版では、コードのバージョン、ビルドスクリプト、READMEのダウンロードリンク、リリースノートを同じ版へ更新してください。
