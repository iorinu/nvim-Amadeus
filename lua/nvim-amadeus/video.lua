-- image.nvim を使って PNG 連番フレームをパラパラ漫画式に再生するモジュール。
-- なぜ GIF をやめたか:
--   image.nvim は GIF アニメーションを実装していない (kitty animation protocol の
--   定数定義はあるが renderer から呼ばれていない) ため、GIF を渡しても 1 枚目しか
--   出ない。プラグイン側で明示的にフレーム差し替えする方が確実。
local M = {}

-- 状態。再生は同時に一つだけという前提。
local timer = nil
local win = nil
local buf = nil
local images = {} -- 事前ロードした image.nvim のイメージオブジェクト配列
local current = 1
local finish_fn = nil

local function get_plugin_dir()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h")
end

local function load_image_nvim()
  local ok, image = pcall(require, "image")
  if not ok then return nil end
  return image
end

-- frame_00000.png, frame_00001.png ... を連番でリストアップ。
local function list_frames(dir)
  local frames = {}
  local i = 0
  while true do
    local path = string.format("%s/frame_%05d.png", dir, i)
    if vim.fn.filereadable(path) == 0 then break end
    table.insert(frames, path)
    i = i + 1
  end
  return frames
end

function M.is_available()
  return load_image_nvim() ~= nil
end

-- 再生本体。
-- config: { frames_dir, fps, width, height }
function M.play(config)
  local image = load_image_nvim()
  if not image then
    vim.notify("Amadeus: image.nvim が見つかりません", vim.log.levels.ERROR)
    return
  end

  local dir = config.frames_dir or (get_plugin_dir() .. "/amadeus_frames")
  local frame_paths = list_frames(dir)
  if #frame_paths == 0 then
    vim.notify(
      "Amadeus: frames not found in " .. dir .. " (uv run scripts/generate_frames.py で生成)",
      vim.log.levels.WARN
    )
    return
  end

  M.stop() -- 多重再生防止

  local width, height = config.width, config.height

  -- フローティングウィンドウ用バッファ。
  -- 重要: image.nvim はバッファに 1 行も無いと描画位置を確定できず、枠だけ出て中身が
  -- 空になることがある。height ぶんの空行で埋めて描画アンカーを用意しておく。
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  local placeholder = {}
  for _ = 1, height do table.insert(placeholder, "") end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, placeholder)

  local ui = vim.api.nvim_list_uis()[1]
  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = "minimal",
    border = "rounded",
  })

  -- フレームを事前ロード。
  -- 理由: 再生中に from_file を呼ぶと I/O とデコードが入り、特に最初の数枚で
  -- カクつく。3秒×15fps = 45 枚程度ならメモリも問題にならない。
  images = {}
  for _, path in ipairs(frame_paths) do
    local ok, img = pcall(image.from_file, path, {
      window = win,
      buffer = buf,
      x = 0,
      y = 0,
      width = width,
      height = height,
      -- image.nvim のデフォルトは max_height_window_percentage=50 で、画像高さが
      -- ウィンドウの 50% にキャップされる。フローティングウィンドウいっぱいに
      -- 表示したいので 100% に上書きする。幅も同様に上限を外す。
      max_width_window_percentage = 100,
      max_height_window_percentage = 100,
    })
    if ok and img then table.insert(images, img) end
  end

  if #images == 0 then
    vim.notify("Amadeus: フレームの読み込みに失敗", vim.log.levels.ERROR)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    win, buf = nil, nil
    return
  end

  current = 1
  local interval = math.floor(1000 / config.fps)
  local finished = false

  local function finish()
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
  end
  finish_fn = finish

  vim.keymap.set("n", "q", function() finish() end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", function() finish() end, { buffer = buf, silent = true })

  -- フレーム送りループ。
  -- vim.loop.new_timer はメインスレッド外で呼ばれるので、Neovim API を触る前に
  -- vim.schedule_wrap でスケジューラに乗せる必要がある (必須のお作法)。
  timer = vim.loop.new_timer()
  timer:start(0, interval, vim.schedule_wrap(function()
    if not win or not vim.api.nvim_win_is_valid(win) then
      finish()
      return
    end
    -- 直前フレームを消してから次を描画。
    -- バックエンドによっては同一位置に重ねると残像が出るので、明示クリアが安全。
    if current > 1 and images[current - 1] then
      pcall(function() images[current - 1]:clear() end)
    end
    local img = images[current]
    if img then
      pcall(function() img:render() end)
    end
    current = current + 1
    if current > #images then
      finish()
    end
  end))
end

function M.stop()
  if finish_fn then finish_fn() end
end

return M
