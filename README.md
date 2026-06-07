## Amadeus

Neovim 起動時に Steins;Gate の Amadeus 起動シーケンスっぽいアニメーションを流すプラグイン。

### 必要環境

- Kitty Graphics Protocol または Sixel に対応したターミナル (wezterm, kitty など)
- [3rd/image.nvim](https://github.com/3rd/image.nvim) のセットアップ済み環境
- ImageMagick (`magick` コマンド) — image.nvim が画像変換に使用

### フレームの用意

プラグインは `frame_00000.png`, `frame_00001.png`, ... という連番 PNG を読み、タイマで差し替えてアニメーションする。既定の置き場はプラグインルート直下の `amadeus_frames/`、`frames_dir` オプションで任意の場所を指定可能。

著作権の関係でリポジトリには素材を含めていない (`.gitignore` 済み)。

#### オリジナル生成スクリプト

原作風のシアン×ブラック起動シーケンスを Pillow で生成するスクリプトを同梱。著作権に触れない完全オリジナル素材。

```sh
uv run scripts/generate_frames.py
# 既定の出力先: ~/.config/nvim/amadeus_frames/
# 出力先を変えたい場合: uv run scripts/generate_frames.py /path/to/dir
```

#### 動画素材から作る場合

ffmpeg で PNG 連番を直接吐かせれば差し替え可能。

```sh
mkdir -p amadeus_frames
ffmpeg -i amadeus.mp4 -t 3 -vf "fps=15,scale=960:-1:flags=lanczos" amadeus_frames/frame_%05d.png
```

### 設定例 (lazy.nvim)

```lua
{
  "iorinu/nvim-Amadeus",
  dependencies = { "3rd/image.nvim" },
  opts = {
    autoplay = true,
    fps = 15,
    width = 120,
    height = 34,
    -- frames_dir = vim.fn.stdpath("config") .. "/amadeus_frames",
  },
}
```

### コマンド

- `:Amadeus` - 再生
- `:AmadeusStop` - 中断 (再生中は `q` / `<Esc>` でもスキップ可能)
