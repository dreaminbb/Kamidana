## アプリ機能

### システムモニター

#### CPU
- [x] 使用率のグラフ (※パーセンテージでの全体/コア表示を実装完了)
- [x] コア単位での使用率
- [x] クロック数
- [x] 使用しているトッププロセス (アイコン取得込みで実装完了)

#### メモリー
- [x] アプリ、確保、圧縮、空きのメモリー量の取得、表示 (※全体の使用済みメモリ計算を実装完了)
- [x] 使用しているトッププロセス (アイコン取得込みで実装完了)

#### DISK
- [x] 使用率のグラフ
- [x] 空き容量
- [x] 使用しているトッププロセス (アイコン取得込みで実装完了)
- [x] ディスクI/O速度（Read/Write MB/s）

#### ネットワーク
- [x] 通信速度（上り・下り Mbps）のリアルタイム表示

#### バッテリー＆電源
- [x] バッテリー残量（%）の表示
- [x] 充電状態（AC / バッテリー）と残り時間の表示
- [x] 消費電力・充電電力のワット数(W)取得

#### GPU＆ハードウェアセンサー
- [x] GPU使用率の取得・表示
- [x] Macの温度（サーマルステータス）の取得・表示

### ユーティリティ・OS操作機能

#### ネットワーク系 (Wifi/Bluetooth)
- [x] Wifiの接続、切り替え
    - [x] ローカルIPの表示
    - [x] 周辺のWi-Fiリスト表示機能 (ポップオーバーUI実装完了)
    - [x] 新規接続の機能 (CoreWLANによるパスワード接続実装完了)
- [x] Bluetoothの接続
    - [x] 接続、切断機能

#### メディア＆オーディオ
- [x] 再生中の楽曲情報の表示（Apple Music, Spotify等）
- [x] 再生・停止・スキップのコントロール機能
- [ ] スピーカー音量 / マイク入力レベルの表示とミュート切替

#### 日常ツール
- [x] 時計 / カレンダー表示（※現在時刻表示は実装完了）
- [ ] カフェイン機能（クリック中はMacをスリープさせない機能）

### 通知
- [ ] ユーザーが取得した通知を表示できる様にする
- [ ] UIをクリックしたら情報の表示をできる様にする

### 天気
- [ ] APIプロバイダーからお天気情報を取得
- [ ] 表示する地域の天気をその場で、入力して変更可能に

### OS連携＆コアシステム
- [ ] MacBookビルドインモニターになった場合に通知できる様にする
- [ ] 表示するモニターを決めれる
- [ ] ログイン時に起動するか（Launch at login）
- [ ] 権限リクエストUI（プロセス情報やOS制御に必要なAccessibility/Root権限の取得フロー）
- [x] スリープ復帰時やモニター変更時の描画位置ズレ修正（常駐バーとしてのUI固定化）

### 設定＆アーキテクチャ
- [ ] 設定を変更できる簡易アプリの作成
- [ ] [#サーバー]のテンプレートのダウンロードボタン
- [ ] 表示するUIの設定
- [ ] テーマファイルのフォーマット定義（JSON/YAML/Luaなど、カスタマイズ用の仕様策定）
    - [x] WaybarとYASBのスタイル・アニメーション設定方式を調査
    - [ ] YAMLベースの型付きスタイル仕様と優先順位を定義
        - [x] 独立したv1設定モデル・YAMLデコーダ・意味検証を実装
        - [x] v1設定をConfigManagerとWidgetRegistryの実行時構成へ接続
            - [x] v1 Widgetを既存SwiftUI Widgetの内部設定へ変換
            - [x] center_default・section/global/widget styleを実行時UIへ適用
            - [x] Example/config.yamlをv1スキーマへ更新
            - [x] v1実行時統合の回帰テストを追加
        - [x] ユーザー公開する全ウィジェットIDを確定
            - [x] audioの公開Widget IDをvolumeへ変更
            - [x] shellを廃止してcustomへ統合
            - [x] media・media-slider・sound-visualizerをmusic内部パーツとして非公開化
            - [x] 埋め込みbtopを組み込みWidgetとしてcenter内だけで許可
            - [x] system-actionを縦展開コンテナとし、sleep・reboot等を子Widgetとして定義
            - [x] center専用btop Widgetから外部インストール済みbtopを自動検出
        - [x] 全Widgetインスタンスにidを必須化し、center_defaultからidで参照
        - [x] musicを複合Widget、media・media-sliderを内部パーツとして定義
        - [x] UI展開のactivateと直接実行するclick actionを分離
        - [x] 背景モードをsingle_bar・per_section・per_widget・noneとして定義
        - [x] global・section・widget・内部パーツ・状態の順でスタイルを継承
        - [x] center外のmusicは基本情報から内側へ自動サイズで横展開
        - [ ] formatで利用できるプレースホルダーを定義
            - [x] WidgetFolder以外のアイコン表示をNerd Font文字を含むformatへ統合
            - [x] center_defaultで指定したWidgetにcompact_formatを適用
            - [x] 通常Widgetのicon専用プロパティを廃止し、formatの内容にUIの横幅を自動追従させる
            - [x] format内の文字・値にstyle.color、Nerd Fontアイコンにstyle.icon_colorを適用
            - [x] WidgetFolderのみiconとfolded_iconを専用プロパティとして保持
        - [ ] CPU・GPU等のformatとtooltip-formatプレースホルダーを定義
            - [x] CPU・GPUは`format: "<Nerd Font icon> {usage}%"`を内部UIに適用
            - [x] intervalの単位を秒として定義
            - [x] tooltipをCPU・GPU・Memory・Networkのactivate UIに限定
        - [x] background_mode: per_sectionで縦展開WidgetFolderをクリップしない
        - [ ] audioの下展開UIと内部スライダー・デバイス一覧のスタイル項目を定義
        - [x] music内sound-visualizerはmacOS 14.2以降のCore Audio Process Tapを使用
        - [ ] macOSの最小対応バージョンを14.2へ更新
        - [x] custom widgetのclick actionはシェルを介さない直接実行として定義
        - [x] 組み込みWidgetのアクションは固定し、ユーザー定義actionをcustomに限定
        - [x] fullscreen時はbarを非表示として定義
        - [x] hover離脱・アプリ非アクティブ化・別Widget展開時に展開UIを閉じる
        - [x] 既存設定との互換性を持たない新しい1.0 YAMLスキーマとして定義
    - [x] 共通スタイルリゾルバとSwiftUI ViewModifierを実装
    - [ ] hover・pressed・expanded状態とプリセットアニメーションを実装
    - [ ] テーマファイルの監視、検証、フォールバックを実装
    - [ ] カテゴリ単位で軽量モデルのエージェントに実装を分担し、各完了後にユーザーレビューを実施
- [ ] アプリの自動アップデート機能（Sparkle等の導入）

## サーバー
- [ ] テーマのテンプレートを管理する
- [ ] テンプレートをダウンロード可能にする
    - [ ] 認証
    - [ ] ログ
    - [ ] ダウンロード

## ウェブサイト
- [ ] 作る！！！！
