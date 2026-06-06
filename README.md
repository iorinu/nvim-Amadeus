## Amadeus

Neovim 起動時に Steins;Gate の Amadeus 起動シーケンスっぽい動画を流すプラグイン。

### 必要環境

- Kitty Graphics Protocol または Sixel に対応したターミナル (wezterm, kitty など)
- [3rd/image.nvim](https://github.com/3rd/image.nvim) のセットアップ済み環境

### フレームの生成

動画ファイルを連番 PNG に変換して `video_frames/` に置く。3 秒分なら `-t 3`、15fps なら `-r 15` で 45 枚程度。

```sh
mkdir -p video_frames
ffmpeg -i amadeus.mp4 -t 3 -r 15 -vf "scale=640:-1" video_frames/frame_%05d.png
```

ファイル名は `frame_00000.png` から連番である必要がある (抜けがあるとそこで打ち切られる)。

### 設定例 (lazy.nvim)

```lua
{
  "iorinu/nvim-Amadeus",
  dependencies = { "3rd/image.nvim" },
  opts = {
    autoplay = true, -- nvim 起動時に自動再生
    fps = 15,
    width = 80,
    height = 24,
  },
}
```

### コマンド

- `:Amadeus` - 再生
- `:AmadeusStop` - 中断 (再生中は `q` / `<Esc>` でもスキップ可能)
