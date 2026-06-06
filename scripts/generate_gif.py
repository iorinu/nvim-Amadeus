# /// script
# requires-python = ">=3.11"
# dependencies = ["Pillow"]
# ///
"""
Amadeus 風の起動シーケンス GIF を生成するスクリプト。

なぜこのスクリプトがあるか:
- 著作権の都合で実物の GIF はリポジトリに含められないため、各自で原作風の
  オリジナルアニメーションを生成できるようにするのが目的。
- Pillow だけで完結するので uv 一発で実行可能 (依存をインラインで宣言)。

使い方:
  uv run scripts/generate_gif.py                              # ~/.config/nvim/amadeus.gif に出力
  uv run scripts/generate_gif.py /path/to/output.gif          # 出力先を指定
"""

from __future__ import annotations

import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# ====== 基本パラメータ ======
# SCALE を変えると解像度・フォント・座標を一括でスケーリングできる。
# 1.0 = 640x360 (基準)、1.5 = 960x540 (現状)、2.0 = 1280x720。
SCALE = 1.5
W, H = int(640 * SCALE), int(360 * SCALE)
FPS = 15                 # フレームレート
DURATION_S = 3           # 全体の秒数
TOTAL_FRAMES = FPS * DURATION_S  # 45 枚


def s(n: float) -> int:
    """座標やサイズを SCALE 倍する小さなヘルパ。"""
    return int(n * SCALE)

# ====== 配色 (シアン × ブラック) ======
BG = (4, 8, 12)
CYAN = (0, 255, 229)
DIM_CYAN = (0, 130, 115)
DARK_CYAN = (0, 70, 65)
GRID = (0, 35, 35)
GLITCH = (255, 80, 160)  # たまに走るピンクのアクセント

# ====== フォント探索 ======
# macOS 想定で等幅フォントを優先的に探す。見つからなければ Pillow のデフォルト。
# 等幅フォントを使う理由: 起動ログ風の表示はカラム揃いの方がそれっぽく見えるため。
def find_mono_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/Library/Fonts/SF-Mono-Regular.otf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


FONT_SM = find_mono_font(s(14))
FONT_MD = find_mono_font(s(20))
FONT_LG = find_mono_font(s(72))


# ====== 補助描画関数 ======
def draw_grid(draw: ImageDraw.ImageDraw) -> None:
    """背景に薄いグリッドを敷く。SF UI 感を出すための定番演出。"""
    step = s(32)
    for x in range(0, W, step):
        draw.line([(x, 0), (x, H)], fill=GRID, width=1)
    for y in range(0, H, step):
        draw.line([(0, y), (W, y)], fill=GRID, width=1)


def draw_scanline(draw: ImageDraw.ImageDraw, frame_idx: int) -> None:
    """ブラウン管風の走査線を 1 本入れて動かす。"""
    y = (frame_idx * s(11)) % H
    draw.line([(0, y), (W, y)], fill=DARK_CYAN, width=1)


def draw_border(draw: ImageDraw.ImageDraw) -> None:
    """画面外枠と角のティック。HUD っぽさを足す。"""
    inset = s(8)
    tick = s(4)
    draw.rectangle([(inset, inset), (W - inset - 1, H - inset - 1)], outline=DIM_CYAN, width=1)
    for cx, cy in [(inset, inset), (W - inset - 1, inset), (inset, H - inset - 1), (W - inset - 1, H - inset - 1)]:
        draw.line([(cx - tick, cy), (cx + tick, cy)], fill=CYAN, width=1)
        draw.line([(cx, cy - tick), (cx, cy + tick)], fill=CYAN, width=1)


def maybe_glitch(img: Image.Image, frame_idx: int, intensity: float) -> Image.Image:
    """確率的に横方向のグリッチ (画像の一部を横にずらす) を起こす。
    intensity: 0.0 ~ 1.0。高いほど頻繁・激しく。"""
    if random.random() > intensity:
        return img
    band_h = random.randint(s(4), s(16))
    y0 = random.randint(0, H - band_h)
    shift = random.randint(s(-30), s(30))
    band = img.crop((0, y0, W, y0 + band_h))
    img.paste(band, (shift, y0))
    return img


# ====== シーン構築 ======
BOOT_LINES = [
    "[ 0.001 ] BIOS  AMADEUS v2.31  init",
    "[ 0.034 ] CORE  neural matrix .......... OK",
    "[ 0.128 ] MEM   personality cache ...... OK",
    "[ 0.421 ] VOL   memory volumes mounted .  OK",
    "[ 0.789 ] AUD   voice synthesis online .  OK",
    "[ 1.103 ] NET   operator link established",
    "[ 1.456 ] SEC   handshake verified ......  OK",
]

HEADER = "AMADEUS SYSTEM BOOT"


def render_frame(i: int) -> Image.Image:
    """フレーム番号 i (0 始まり) を 1 枚描画して返す。"""
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw_grid(draw)
    draw_scanline(draw, i)
    draw_border(draw)

    # ----- フェーズ分割 -----
    # 0..7   (0.0-0.5s) : ヘッダをタイプライタ風に出す
    # 8..25  (0.5-1.7s) : ブートログを順次表示
    # 26..34 (1.7-2.3s) : ログをそのまま、AMADEUS ロゴがフェードイン+グリッチ
    # 35..44 (2.3-3.0s) : SYSTEM READY 表示 + カーソル点滅
    header_xy = (s(24), s(24))
    if i < 8:
        n = int(len(HEADER) * (i + 1) / 8)
        cursor = "_" if i % 2 == 0 else " "
        draw.text(header_xy, HEADER[:n] + cursor, font=FONT_SM, fill=CYAN)
    else:
        draw.text(header_xy, HEADER, font=FONT_SM, fill=CYAN)

    if 8 <= i < 35:
        # 8 から 2 フレームごとに 1 行ずつ出す → 全行出るのは i=8+2*7=22 あたり
        lines_shown = min(len(BOOT_LINES), max(0, (i - 8) // 2 + 1))
        for j in range(lines_shown):
            color = DIM_CYAN if j < lines_shown - 1 else CYAN
            draw.text((s(24), s(56) + j * s(22)), BOOT_LINES[j], font=FONT_SM, fill=color)

    if 26 <= i:
        # AMADEUS ロゴ。26 で薄く、徐々に濃く。
        progress = min(1.0, (i - 26) / 8.0)
        # 明度を progress で線形に
        c = tuple(int(ch * progress) for ch in CYAN)
        text = "AMADEUS"
        bbox = draw.textbbox((0, 0), text, font=FONT_LG)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        x = (W - tw) // 2
        y = (H - th) // 2 + s(20)
        # 影 (グロー風)
        draw.text((x + s(2), y + s(2)), text, font=FONT_LG, fill=DARK_CYAN)
        draw.text((x, y), text, font=FONT_LG, fill=c)

    if i >= 35:
        # SYSTEM READY + 点滅カーソル
        text = "SYSTEM READY"
        bbox = draw.textbbox((0, 0), text, font=FONT_MD)
        tw = bbox[2] - bbox[0]
        x = (W - tw) // 2
        y = H - s(60)
        cursor = "█" if (i // 3) % 2 == 0 else " "
        draw.text((x, y), text + " " + cursor, font=FONT_MD, fill=CYAN)

    # ロゴ出現中はグリッチを強めに。落ち着いたら弱く。
    if 26 <= i < 35:
        img = maybe_glitch(img, i, intensity=0.7)
    else:
        img = maybe_glitch(img, i, intensity=0.08)

    # 中央付近にたまにピンクのアクセント線を 1 本走らせる (フレーム 28, 31 など)
    if i in (28, 31, 38):
        d = ImageDraw.Draw(img)
        y = random.randint(H // 3, 2 * H // 3)
        d.line([(0, y), (W, y)], fill=GLITCH, width=1)

    return img


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".config/nvim/amadeus.gif"
    out.parent.mkdir(parents=True, exist_ok=True)

    # 乱数シードを固定して毎回同じ見た目になるように (再現性のため)。
    random.seed(42)

    frames = [render_frame(i) for i in range(TOTAL_FRAMES)]

    # GIF として保存。
    # duration はフレーム間隔 (ms)。1000/FPS で 1秒/FPS フレーム。
    # loop=0 で無限ループ (どうせプラグイン側で duration_ms で止めるので関係ない)。
    # optimize=True でパレット最適化。disposal=2 で前フレームをクリアして残像を防ぐ。
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=int(1000 / FPS),
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"wrote {out} ({len(frames)} frames, {DURATION_S}s @ {FPS}fps)")


if __name__ == "__main__":
    main()
