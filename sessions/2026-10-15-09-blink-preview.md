# 赤の点滅プレビュー

## Request / Investigation
赤の点滅をテストで見たい。AGENTS/CURRENT、CODEMAP/TESTING、StatusStripの実タイマーと既存描画ツールを確認。

## Changes / Files Changed
tools/RenderStatusStrip.swiftに --live-alert-preview を追加。同じStatusStripを合成値の別windowで表示、120秒で自動終了。windowを閉じても終了。実監視アプリ・設定・履歴を変更しない。TESTINGとsession索引を更新。

## Validation / Result
描画ツールをcompileし、Fast/Full検証を実行。実デスクトップ上の点滅の見え方はユーザー確認対象。Reduce Motionを尊重し、OS設定は変更しない。

## Remaining Issues
このプレビューは合成値で、実測による警告発生の証拠ではない。
