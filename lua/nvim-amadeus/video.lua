-- image.nvim を使って連番PNGをパラパラ漫画式に再生するモジュール
-- なぜ別ファイルにするか: AA版（テキスト描画）と画像版で必要な依存・APIが全く異なるため、
-- 関心を分離しておくと「image.nvim が無い環境ではAAにフォールバック」が綺麗に書ける。
local M = {}

-- モジュールローカル状態。再生は同時に一つだけという前提（複数並走させる意味がないので）。
local timer = nil
local win = nil
local buf = nil
local images = {} -- 事前ロードした image.nvim のイメージオブジェクト配列
local current = 1
local finish_fn = nil

-- プラグインのルートディレクトリを取得する。
-- debug.getinfo(1, "S").source は "@/path/to/this/file.lua" を返すので、先頭の "@" を除き、
-- 親ディレクトリを 2 段上る (lua/nvim-amadeus/video.lua -> プラグインルート) ことで求まる。
local function get_plugin_dir()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h")
end

-- image.nvim を安全に require する。未インストールでもエラーにせず nil を返したい。
local function load_image_nvim()
  local ok, img = pcall(require, "image")
  if not ok then
    return nil
  end
  return img
end

-- frame_00000.png, frame_00001.png ... を連番でリストアップ。
-- 抜け番が出た時点で打ち切る (ffmpeg の出力は基本連番なのでこれで十分)。
local function list_frames(dir)
  local frames = {}
  local i = 0
  while true do
    local path = string.format("%s/frame_%05d.png", dir, i)
    if vim.fn.filereadable(path) == 0 then
      break
    end
    table.insert(frames, path)
    i = i + 1
  end
  return frames
end

-- image.nvim が利用可能か（プラグインが読み込めるか）を返す。
-- init.lua から「mode=auto」判定で使う。
function M.is_available()
  return load_image_nvim() ~= nil
end

-- 再生本体。
-- config: { video_dir, fps, width, height }
-- on_done(ok): 再生終了時に呼ばれるコールバック。ok=false ならフォールバック判定に使う。
function M.play(config, on_done)
  local image = load_image_nvim()
  if not image then
    if on_done then on_done(false) end
    return
  end

  local dir = config.video_dir or (get_plugin_dir() .. "/video_frames")
  local frame_paths = list_frames(dir)
  if #frame_paths == 0 then
    vim.notify(
      "Amadeus: video frames not found in " .. dir .. " (README の ffmpeg コマンドで生成してください)",
      vim.log.levels.WARN
    )
    if on_done then on_done(false) end
    return
  end

  -- フローティングウィンドウを作る。画像はこのウィンドウに紐付けて描画する。
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local ui = vim.api.nvim_list_uis()[1]
  local width, height = config.width, config.height
  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = "minimal",
    border = "rounded",
  })

  -- すべてのフレームを事前ロードしておく。
  -- 理由: 再生中に from_file を呼ぶと I/O とデコードでフレーム落ちしやすい。
  -- 3秒×15fps = 45枚程度ならメモリも問題にならない。
  images = {}
  for _, path in ipairs(frame_paths) do
    local ok, img = pcall(image.from_file, path, {
      window = win,
      buffer = buf,
      x = 0,
      y = 0,
      width = width,
      height = height,
    })
    if ok and img then
      table.insert(images, img)
    end
  end

  if #images == 0 then
    vim.notify("Amadeus: failed to load any frame (image.nvim setup を確認してください)", vim.log.levels.ERROR)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    win, buf = nil, nil
    if on_done then on_done(false) end
    return
  end

  current = 1
  local interval = math.floor(1000 / config.fps)
  local finished = false

  -- finish は「タイマ停止」「画像クリア」「ウィンドウ閉じる」をまとめて行う。
  -- Esc/q によるスキップと、最終フレームに到達した時の両方から呼ばれるので、
  -- 二重実行防止のために finished フラグでガードしている。
  local function finish(ok_flag)
    if finished then return end
    finished = true
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    for _, img in ipairs(images) do
      pcall(function() img:clear() end)
    end
    images = {}
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    win, buf = nil, nil
    if on_done then on_done(ok_flag) end
  end
  finish_fn = finish

  -- スキップ用キー。q または Esc。
  vim.keymap.set("n", "q", function() finish(true) end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", function() finish(true) end, { buffer = buf, silent = true })

  -- フレーム描画ループ。
  -- vim.loop.new_timer はメインスレッド外で呼ばれるので、Neovim API を触る前に
  -- vim.schedule_wrap でスケジューラに乗せる必要がある（必須のお作法）。
  timer = vim.loop.new_timer()
  timer:start(0, interval, vim.schedule_wrap(function()
    if not win or not vim.api.nvim_win_is_valid(win) then
      finish(false)
      return
    end
    -- 直前フレームを消してから次を描画。
    -- image.nvim は同一座標に重ねると残るバックエンドがあるので、明示クリアが安全。
    if current > 1 and images[current - 1] then
      pcall(function() images[current - 1]:clear() end)
    end
    local img = images[current]
    if img then
      pcall(function() img:render() end)
    end
    current = current + 1
    if current > #images then
      finish(true)
    end
  end))
end

-- 外部から停止したい時用。init.lua の M.stop から呼ぶ。
function M.stop()
  if finish_fn then finish_fn(true) end
end

return M
