# WezTerm 背景アニメーション調査

## 背景
依頼内容:
- 背景画像ごとにグラデーション色を適応させたい
- WezTerm 起動後に追加した画像も対象にしたい
- もっと滑らかな切り替えにしたい
- CSS / 他言語 / ライブラリで高度なアニメーションが可能か知りたい

## WezTerm が公式にサポートしていること

1. `background` によるマルチレイヤー背景
- 背景ソースは file / gradient / color を利用できる
- レイヤーは順に合成されるため、2枚画像と不透明度制御でクロスフェード相当を表現可能
- 参照: https://wezterm.org/config/lua/config/background.html

2. イベント + override による実行時更新
- `status_update_interval` で定期更新間隔を制御できる
- `window:set_config_overrides(...)` でウィンドウ単位の見た目を動的変更できる
- 参照: https://wezterm.org/config/lua/config/status_update_interval.html
- 参照: https://wezterm.org/config/lua/window/set_config_overrides.html

3. `update-right-status` は非推奨で `update-status` が推奨
- 参照: https://wezterm.org/config/lua/window-events/update-right-status.html

4. 画像色抽出APIが標準で存在
- `wezterm.color.extract_colors_from_image(...)` で代表色抽出が可能
- 大きい画像ではコストがかかるが、公式でキャッシュされる前提の機能
- 参照: https://wezterm.org/config/lua/wezterm.color/extract_colors_from_image.html

## CSS / 他言語 / ライブラリの可否

### CSS
- 非対応
- WezTerm は Web ランタイムではないため、DOM/CSS アニメーション機構は使えない

### Lua ライブラリ
- 数学処理、イージング、状態管理の補助には使える
- ただしレンダラ自体の能力を CSS 風に拡張することはできない
- 最終的な描画可能範囲は WezTerm の背景レイヤー機能に依存する

### 他言語
- Lua から外部ツールを呼び出して前処理することは可能
- ただし、シェーダー級の高度な遷移やピクセル単位効果は、実質的に WezTerm 本体(Rust)改修が必要

## 実用的な提案

### Tier 1 (推奨)
Lua + WezTerm 標準APIだけで構成
- `extract_colors_from_image` で適応グラデーション
- 定期再スキャンで起動後追加画像を反映
- 高頻度 tick + イージング付きクロスフェード

利点:
- stock WezTerm のまま運用できる
- 設定として持ち運びやすい
- 保守コストが低い

弱点:
- 完全な CSS アニメーションエンジン相当にはならない

### Tier 2
外部でフレーム生成し、WezTerm 側で差し替える

利点:
- 表現力は上がる

弱点:
- I/O と CPU 負荷が高い
- 構成が複雑化する

### Tier 3
WezTerm を独自ビルド(Rust改修)

利点:
- 表現の自由度が最大

弱点:
- 開発・保守コストが最も高い

## このプロジェクトへの提案

1. まず Tier 1 を標準路線として採用(今回の更新で実装済み)
2. 性能に余裕があればシネマティック方向へ調整
- `tick_interval_ms` を小さく
- `transition_duration_ms` を長く
- `rescan_interval_seconds` は短めだが過剰にしない
3. クロスフェード以上の表現が必要なら Tier 2 か Tier 3 へ移行

## 推奨チューニング

### バランス重視
- `tick_interval_ms = 33`
- `transition_duration_ms = 1400`
- `slideshow_interval_seconds = 20`

### より滑らか
- `tick_interval_ms = 16`
- `transition_duration_ms = 1800`
- `slideshow_interval_seconds = 18`

### 低負荷
- `tick_interval_ms = 50`
- `transition_duration_ms = 1000`
- `slideshow_interval_seconds = 22`
