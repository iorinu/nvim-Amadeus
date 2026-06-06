## Amadeus

Neovim 起動時に Steins;Gate の Amadeus 起動シーケンスっぽい GIF を流すプラグイン。

### 必要環境

- Kitty Graphics Protocol または Sixel に対応したターミナル (wezterm, kitty など)
- [3rd/image.nvim](https://github.com/3rd/image.nvim) のセットアップ済み環境
- ImageMagick (`magick` コマンド) — image.nvim が GIF 展開に使用

### GIF の用意

プラグインルートに `amadeus.gif` を置く。`gif_path` オプションで任意の場所を指定することも可能。

動画から作る場合の参考 ffmpeg コマンド (3秒, 15fps, 幅640):

```sh
ffmpeg -i amadeus.mp4 -t 3 -vf "fps=15,scale=640:-1:flags=lanczos" amadeus.gif
```

### 設定例 (lazy.nvim)

```lua
{
  "iorinu/nvim-Amadeus",
  dependencies = { "3rd/image.nvim" },
  opts = {
    autoplay = true,     -- nvim 起動時に自動再生
    duration_ms = 3000,  -- 表示時間 (GIF はループするので明示的に閉じる)
    width = 80,
    height = 24,
  },
}
```

### コマンド

- `:Amadeus` - 再生
- `:AmadeusStop` - 中断 (再生中は `q` / `<Esc>` でもスキップ可能)
