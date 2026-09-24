# Windows版LINEを通知領域に起動する

Windowsへのサインイン時にLINEを起動し、起動直後のウィンドウを表示せずに通知領域へ常駐させる補助スクリプトです。通知領域には、LINEに同梱されている緑色のロゴを表示します。

## 仕組み

- LINE本体の自動起動を利用します。
- スクリプトの起動後120秒以内に最初のLINEウィンドウを検出すると、ウィンドウを非表示にしてから閉じます。
- LINEが登録した通知領域アイコンに、同梱の `StoreLogo.scale-100.png` を設定します。LINEの通知やクリック動作はそのまま利用できます。
- アイコンを10秒ごとに再適用し、LINEの再起動後も表示を保ちます。
- VBSがPowerShellを非表示で起動するため、コマンド画面は表示されません。

## 必要な環境

- WindowsとWindows PowerShell 5.1
- `%LOCALAPPDATA%\LINE\bin\current\` にインストールされたWindows版LINE
- LINE本体の自動起動が有効であること

## 設定方法

1. `LINE-startup-to-tray.ps1` と `LINE-startup-to-tray.vbs` を同じフォルダーに置きます。フォルダーはサインイン後も移動しない場所にしてください。
2. タスク スケジューラでタスクを作成します。
   - トリガー: 現在のユーザーのログオン時
   - 操作: プログラムの開始
   - プログラム: `C:\Windows\System32\wscript.exe`
   - 引数: `//B //NoLogo "<配置先>\LINE-startup-to-tray.vbs"`
3. LINE本体の自動起動を有効にします。

VBSファイルは同じフォルダー内のPowerShellスクリプトを起動します。配置先のパスはVBS内で変更する必要はありません。タスクの引数には、実際の配置先を指定してください。

## 停止・削除

1. タスク スケジューラで作成したタスクを無効化または削除します。
2. すでに起動している補助処理を停止します。管理者権限は不要です。

   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
       Where-Object { $_.CommandLine -match 'LINE-startup-to-tray\.ps1' } |
       ForEach-Object { Stop-Process -Id $_.ProcessId }
   ```

3. LINEを終了して再起動すると、LINE本来の通知領域アイコンに戻ります。

## 注意事項

通知領域アイコンの識別子はLINEの内部実装に依存します。LINEの更新で識別子やウィンドウ構成が変わると、アイコンの差し替えが動作しなくなる可能性があります。LINE 26.4.2.3957で動作を確認しています。

本スクリプトはLINEの実行ファイルやログイン情報を変更しません。LINE本体の自動ログイン設定はLINE側の設定に従います。これはLINEの公式提供・サポート対象ではありません。
