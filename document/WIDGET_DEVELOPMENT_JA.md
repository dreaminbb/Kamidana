# ウィジェット開発ガイド

この文書は、Kamidana のウィジェットを追加・変更するときに、UI のレイアウトと表示内容を決める設定項目を確認するための短いリファレンスです。

全設定項目の一覧ではなく、次の判断に必要な項目をまとめています。

- ウィジェットをどこに、どの順番で表示するか
- ウィジェットの大きさ、余白、背景、ポップアップをどう決めるか
- 通常時・コンパクト時に何を表示するか
- hover／click、アニメーション、状態表示をどう扱うか

## 設定の階層

設定ファイルは次の順で UI を組み立てます。

```text
global
  display profile: external / built_in
    section: left / center / right
      widget
        widget folder children
```

`external` と `built_in` は、それぞれ外部ディスプレイと内蔵ディスプレイ用のレイアウトです。各 profile には `left`、`center`、`right` の3セクションがあります。

```yaml
global:
  background_mode: per_widget

external:
  left:
    widgets:
      - id: network
        type: network
  center:
    center_default: clock
    widgets:
      - id: clock
        type: clock
  right:
    widgets:
      - id: cpu
        type: cpu
```

### 配置を決めるプロパティ

| プロパティ | 配置への影響 |
|---|---|
| `global.display_targets` | どのディスプレイに bar を表示するか |
| `external` / `built_in` | ディスプレイ種別ごとのレイアウト |
| `left` / `center` / `right` | ウィジェットを置くセクション |
| `widgets` | 表示するウィジェットの順番 |
| `center_default` | center Island の標準表示にする widget ID |
| `direction` | `widget-folder` の展開方向。`below`、`left`、`right` |
| `bar_padding` | bar ウィンドウと画面端の距離 |
| `background_mode` | 背景を bar 全体・セクション・各 widget のどこに描画するか |

`background_mode` の値は次のとおりです。

| 値 | 背景の単位 |
|---|---|
| `single_bar` | bar 全体を1つの背景で囲む |
| `per_section` | left、center、right ごとに背景を描画する |
| `per_widget` | widget ごとに背景を描画する |

セクションで `background_mode` を指定すると、そのセクションだけ global の値を上書きします。

## ウィジェットの基本プロパティ

```yaml
- id: cpu
  type: cpu
  format: "{icon} {usage}%"
  compact_format: "{usage}%"
  activate: hover
  animation: dynamic
```

| プロパティ | 用途 |
|---|---|
| `id` | レイアウト内で widget を識別する一意な ID |
| `type` | `cpu`、`memory`、`network` などの登録済み widget 種別 |
| `format` | 通常時に表示する文字列と placeholder |
| `compact_format` | center または compact 表示で使う短い format |
| `icon` | Nerd Font のアイコン文字列。battery は `icon` オブジェクトを使う |
| `activate` | `hover` または `click`。ポップアップを開く操作 |
| `animation` | `dynamic` または `static`。展開・ポップアップ遷移の有無 |
| `interval` | 更新間隔を持つ widget の更新周期 |
| `tooltip` | CPU、GPU、memory、network の詳細表示を有効にする |
| `tooltip_format` | tooltip の表示 format |

section に `animation` を指定した場合、section の値が配下 widget より優先されます。

## レイアウトと見た目

### `style`

`style` は通常時の widget surface を決めます。global、section、親 folder、widget の順で継承され、子で指定した値だけが上書きされます。

```yaml
style:
  background: "#1e1e2e"
  color: "#cdd6f4"
  opacity: 0.6
  padding:
    top: 6
    bottom: 9
    leading: 8
    trailing: 8
  spacing: 8
  corner_radius: 8
  material: ultra_thin
  border:
    width: 1
    color: "#585b70"
```

| プロパティ | UI への影響 |
|---|---|
| `background` | surface の色 |
| `opacity` | background の透明度。`0.0` が透明、`1.0` が不透明 |
| `color` | 通常の文字色 |
| `icon_color` | アイコン色 |
| `padding` | widget 内側の余白 |
| `spacing` | 同じ section 内の widget 間隔 |
| `corner_radius` | surface の角丸 |
| `material` | glass material。`none` で無効化 |
| `border` | 枠線の幅と色。`width: 0` で無効化 |
| `shadow` | surface の影 |

### `popup_style`

`popup_style` は展開パネルの見た目を決めます。通常の widget surface と別に設定できます。

```yaml
- id: network
  type: network
  popup_style:
    background: "#1e1e2e"
    opacity: 0.96
    corner_radius: 12
    material: ultra_thin
```

ポップアップの位置、矢印、画面端への寄せ方はアプリケーションが決めます。設定から任意の座標を指定することはできません。

### 状態別の見た目

`style.states` で hover、pressed、warning、critical などの状態を上書きできます。

```yaml
style:
  background: "#1e1e2e"
  states:
    hover:
      background: "#45475a"
      opacity: 0.8
    pressed:
      opacity: 0.88
    warning:
      color: "#fab387"
```

状態の判定と表示のタイミングは widget 共通の interaction foundation が管理します。新しい widget が独自の hover timer や popup state を持つ必要はありません。

## 表示 format

通常の widget は `format` を文字列として受け取り、`{placeholder}` を実データに置換して表示します。

```yaml
- id: network
  type: network
  format: "{connection_icon} {network_name} {upload_icon} {upload} {download_icon} {download}"
```

未定義の placeholder は置換されず、そのまま表示されます。Nerd Font の文字は自動的にアイコンとして扱われます。

### 共通の表示項目

| widget | 主な placeholder |
|---|---|
| `clock` | `{date}`、`{time}` |
| `cpu` | `{icon}`、`{usage}` |
| `gpu` | `{icon}`、`{usage}` |
| `memory` | `{icon}`、`{used_gb}`、`{total_gb}`、`{usage}` |
| `disk` | `{icon}`、`{used}` |
| `network` | `{connection_icon}`、`{ssid}`、`{network_name}`、`{upload}`、`{upload_icon}`、`{download}`、`{download_icon}` |
| `volume` | `{icon}`、`{volume}`、`{output_icon}`、`{output_volume}`、`{output_device}`、`{input_icon}`、`{input_volume}`、`{input_device}` |
| `battery` | `{icon}`、`{capacity}` |
| `bluetooth` | `{icon}`、`{status}`、`{device_count}`、`{device}`、`{device_name}` |

placeholder を追加する場合は、次の2箇所を同時に変更します。

1. widget view が作る values dictionary
2. 設定例または widget の default format

表示データの取得や変換は view に詰め込まず、既存の manager または widget config で行います。

## Music widget の format

music は通常の文字列 placeholder に加えて、専用の構成要素を持ちます。

```yaml
- id: music
  type: music
  normal:
    format: "{artwork} {title} - {artist}"
  format_on_action: "{artwork} {slider}"
```

| 要素 | 用途 |
|---|---|
| `{artwork}` | アートワーク表示 |
| `{slider}` | 再生位置スライダー |
| `normal.format` | 通常時の表示 |
| `format_on_action` | 展開時の表示 |
| `on_action.format` | action 状態の表示 |
| `extend` | 展開パネルを左右どちらへ伸ばすか |
| `artwork_spin` | アートワーク回転の秒数 |

`{artwork}` と `{slider}` は単なる文字列ではなく、Music widget が専用 View に変換します。

## WidgetFolder の設計

```yaml
- id: system
  type: widget-folder
  icon: "..."
  folded_icon: "..."
  direction: below
  widgets:
    - id: clock
      type: clock
      format: "{time}"
```

- `direction: below` は子 widget を縦方向のポップアップに表示します。
- `below` の中に、さらに hover／click でポップアップを開く widget を入れないでください。
- folder の子 widget は、単純な表示 widget または action widget に限定します。
- folder 自身の `style` と `popup_style` は、子 widget の surface へ自動的に置き換わるものではありません。

## 新しい widget を追加するとき

UI View だけを追加しても、設定から生成できません。次の順で実装します。

1. `KamidanaWidgetKind` に type を追加する。
2. `KamidanaWidget` の decoding と type 固有 validation を追加する。
3. `KamidanaConfigurationV1Adapter` で runtime config へ変換する。
4. `WidgetRegistry` に factory を登録する。
5. View では `theme`、`popupTheme`、`kamidanaWidgetFormat`、`kamidanaWidgetActivation` を利用する。
6. surface は `SmoothUIModule(theme:)` または `WidgetButtonStyle` を利用する。
7. format、継承、adapter、表示モデルのテストを追加する。
8. 必要であれば `Example/config.yaml` と `document/config.md` を更新する。

## 実装時の確認

- レイアウト位置や popup の座標を設定項目に追加していないか。
- 通常 surface と popup surface を `style` と `popup_style` に分離しているか。
- 数値や時刻などの変動値に monospaced 表示を使っているか。
- 背景色や透明度を widget View に直接ハードコードしていないか。
- hover、pressed、popup の状態を widget ごとに独自実装していないか。
- 垂直 folder の中に展開 widget を入れていないか。
- `swift test --filter KamidanaConfigurationV1` と関連する表示テストを実行したか。

## 関連文書

- [`config.md`](config.md): 設定ファイル全体の仕様
- [`ARCHITECTURE.md`](ARCHITECTURE.md): registry、adapter、interaction の構成
- [`UI_DESIGN.md`](UI_DESIGN.md): UI の責務とユーザー設定の境界
- [`CompactUI.md`](CompactUI.md): built-in display の compact レイアウト
