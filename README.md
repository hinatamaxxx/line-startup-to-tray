# Windows版LINEを通知領域に最小化して起動する

Windowsへのサインイン時に、LINEの起動画面とメインウィンドウを表示せず、通知領域に常駐させる補助プログラムです。

## 仕組み

以前のPowerShell版は、一定間隔でウィンドウを探して非表示にしていました。新しいネイティブ版は、Microsoft Detoursを使って起動時の表示要求を処理します。

1. Windows標準のスタートアップから `LineTrayStart.exe` を起動します。
2. LINE本来の `LineLauncher.exe --booting` を起動し、ランチャーからLINE本体を起動する際にもフックを引き継ぎます。
3. 起動画面の表示要求を抑えて初期化を進めます。続くメインウィンドウも表示を抑え、LINEの通常の「閉じる」処理を呼びます。この処理が終わると、以後の表示操作を許可します。通知領域アイコンをユーザーが操作した場合も表示の抑制を解除します。
4. 通知領域アイコンの登録・更新時に、LINE本体に含まれるアイコンを設定します。クリックや通知に使われる設定は維持します。

常駐する監視スクリプト、周期タイマー、画面のポーリングは使いません。補助EXEは起動処理が終わると終了します。フックDLLはLINEのプロセス内に残ります。起動時にcmdやPowerShellの画面は開きません。

LINEの実行ファイルはディスク上で書き換えません。ログイン情報のファイルやレジストリにも触れません。

## ビルド

必要な環境はWindows x64、Visual Studio 2022 CommunityのC++ビルドツール、Gitです。ビルドスクリプトはVisual Studioの標準インストール先を参照します。

```powershell
git submodule update --init
.\build.cmd
```

Microsoft Detoursはv4.0.1リリースのコミットに固定しています。`dist` に補助EXEと32bit・64bitのDLLが生成されます。

## 設定

通知領域のメニューからLINEを終了した状態で、次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

スクリプトを実行すると、ファイルを `%LOCALAPPDATA%\LineTrayStartup` に配置します。スタートアップ項目 `LineTrayStartup` を登録し、Windows側でLINE本来のスタートアップ項目を無効にして二重起動を防ぎます。旧版のタスク `LINE startup to tray` は削除します。LINE本来の起動コマンドは残します。変更前の設定は同じフォルダーの `startup-backup.json` に保存します。

次回サインインから適用されます。再起動せずに試す場合は、LINEを通常終了してから `%LOCALAPPDATA%\LineTrayStartup\LineTrayStart.exe` を実行してください。

## 元に戻す

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

補助プログラムとLINEのスタートアップ登録を変更前の状態に戻します。LINEを通常終了して起動し直すと、プロセス内のフックも外れます。配置ファイルと診断ログは自動では削除されません。

## 検証状況と制約

- 32bitランチャーから64bitアプリへの引き継ぎ、初回表示の抑制、その後の再表示をテスト用アプリで確認しました。
- LINE 26.4.2.3957を通常終了した後、補助EXEから起動して確認しました。起動開始から20秒間のWindows表示イベント監視で、LINEのウィンドウ表示は検出されませんでした。起動画面とメインウィンドウの表示抑制、通知領域アイコンの登録もログで確認しました。
- 通知領域アイコンのダブルクリックでLINEを開けることと、ログインが維持されることをユーザーが確認しました。
- PC再起動を伴う最終確認は未実施です。スタートアップには確認済みの補助EXEを登録しています。
- LINEの内部実装が変わると対応が必要になることがあります。
- 通知領域アイコンを固定するため、LINEがアイコン自体に描く未読表示などが反映されない場合があります。
- LINEの自動ログイン設定はLINE側で管理されます。認証が必要な場合は通常の方法でLINEを開いてログインしてください。
- Windowsの設定でLINE本来のスタートアップ項目を再び有効にすると、通常起動と競合します。

診断ログは `%LOCALAPPDATA%\LineTrayStartup\diagnostic.log` に保存します。記録するのは処理名、プロセスID、ウィンドウクラス、数値だけです。会話本文や認証情報は記録しません。

本プログラムはLINE公式が提供・サポートするものではありません。Microsoft Detoursのライセンスは `third_party/Detours/LICENSE.md` を参照してください。
