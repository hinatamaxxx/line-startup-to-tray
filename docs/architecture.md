# 実装の説明

## 全体像

LINE Tray Startupは、LINE本体をディスク上で書き換えず、起動したプロセスのメモリに表示制御を追加する補助ツールです。

| ファイル | 役割 |
| --- | --- |
| `LineTrayStart.exe` | LINE本来のランチャーを、補助DLLを読み込む状態で起動する |
| `LineTrayHook32.dll` | 32bitのランチャーからLINE本体へ、補助DLLの読み込みを引き継ぐ |
| `LineTrayHook64.dll` | 64bitのLINE本体で、起動時の表示要求と通知領域アイコンの登録を処理する |
| `Setup.exe` | セットアップ・復元・手動起動の画面を提供する |
| `Install.ps1` / `Uninstall.ps1` | 導入時と復元時だけ、自動起動の登録を変更する |

ソースはそれぞれ [Launcher.cpp](../native/Launcher.cpp)、[Hook.cpp](../native/Hook.cpp)、[Setup.cs](../setup/Setup.cs)です。セットアップ画面はWPFで作り、[SetupWindow.xaml](../setup/SetupWindow.xaml)にレイアウトと配色、[SetupWindow.cs](../setup/SetupWindow.cs)に操作と状態表示を定義しています。32bitと64bitのDLLは同じソースを異なる対象アーキテクチャでビルドします。

## 起動から通知領域まで

1. Windowsのユーザー別スタートアップから `LineTrayStart.exe` を起動します。
2. `DetourCreateProcessWithDllExW` で `LineLauncher.exe --booting` を起動します。補助DLLは、アプリの通常の処理が始まる前に読み込まれます。
3. ランチャーが `ShellExecuteExW` / `ShellExecuteW` / `CreateProcessW` で `LINE.exe` または `LineLauncher.exe` を呼ぶ場合、子プロセスにもDLLを引き継ぎます。現在の環境では32bitのランチャーから64bitのLINE本体を起動します。Detoursの32/64bit対応機能を利用します。
4. LINE本体の `CreateWindowExW`、`ShowWindow`、`ShowWindowAsync`、`SetWindowPos` をフックします。起動中のQtのトップレベルウィンドウについて、作成時の `WS_VISIBLE`、表示呼び出し、`SWP_SHOWWINDOW` を抑制します。
5. 起動画面は非表示のまま初期化を続けます。タイトルが `LINE` のメインウィンドウでは、最初の表示要求を抑えた後に `WM_CLOSE` を送ります。LINE自身が通常の「閉じる」処理を行い、通知領域へ移ります。
6. 閉じる処理の完了後、起動時の表示抑制を解除します。通知領域アイコンをユーザーがクリックした場合も解除するため、以後のユーザー操作を受け付けます。

Qtのクラス名やメインウィンドウの識別はLINEの内部実装に依存します。LINEの更新後も必ず同じ動作になるとは限りません。

## 通知領域アイコン

`Shell_NotifyIconW` のアイコン登録・更新時に、LINEの実行ファイルから取得したアイコンを設定します。クリックの通知先など、ほかの登録情報は引き継ぎます。LINEの画像や実行ファイルは配布物に含めません。

固定したアイコンに置き換えるため、LINEがアイコンに描画する未読バッジ等が反映されない場合があります。

## 監視ループが不要な理由

表示APIや通知領域アイコンのAPIが呼ばれたタイミングだけ処理します。一定間隔でプロセスやウィンドウを調べる常駐処理、秒数を決めた遅延処理はありません。起動用EXEはランチャー起動後に終了し、補助DLLはLINEのプロセス内で動作します。

セットアップ画面には通常のWindowsイベント処理があり、テスト用の表示観測にもイベント処理を使います。これらは、起動後のLINEを定期監視する処理ではありません。

## セットアップで変更する内容

- `%LOCALAPPDATA%\LineTrayStartup` に本ツールのファイルを配置します。
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` に `LineTrayStartup` を登録します。
- `Explorer\StartupApproved\Run` の通常の `LINE` を無効、補助項目 `LineTrayStartup` を有効にします。LINE本来のRunコマンドは維持します。
- 変更前の関連する値を `startup-backup.json` に保存します。
- スタートメニューに設定画面へのショートカットを作ります。
- 旧版のタスク `LINE startup to tray` が存在する場合は削除します。

設定を元に戻すと、保存していたスタートアップ状態を復元します。復元済みバックアップは別名で保存し、後日再導入した際は、その時点の設定を新しく記録します。

LINEの認証ファイル、会話データ、認証関連のレジストリは変更しません。PowerShellは導入・復元時だけ非表示で実行し、PC起動時には使用しません。

## 実際に確認したこと

- Windows 11 Home 23H2 x64、LINE 26.4.2.3957で確認。
- LINEを通常終了後、補助EXEで起動。最初の20秒間のWindows表示イベント監視でLINEのウィンドウ表示を検出しないことを確認。
- 起動画面とメインウィンドウの表示抑制、アイコン登録を診断ログで確認。
- 利用者がアイコンのダブルクリックによる再表示とログイン維持を確認。
- セットアップの導入、繰り返し実行、設定の復元、再導入、ショートカットを独立したテスト領域で確認。

**PCを再起動してサインインする一連の確認は未実施です。** そのため初回配布はプレビュー版としています。

## 参考

- [Microsoft Detours](https://github.com/microsoft/Detours)
- [DetourCreateProcessWithDllEx](https://github.com/microsoft/Detours/wiki/DetourCreateProcessWithDllEx)
- [Using Detours](https://github.com/microsoft/Detours/wiki/Using-Detours)
