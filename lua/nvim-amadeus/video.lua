-- image.nvim に GIF を渡してフローティングウィンドウで再生するモジュール。
-- image.nvim は GIF を渡すと内部で magick を使ってフレーム展開しアニメーションしてくれるので、
-- こちら側はタイマでフレーム送りをする必要がなく、「指定秒数経過したら閉じる」だけでよい。
local M = {}

-- 状態。再生は同時に一つだけ。
local img = nil
local win = nil
local buf = nil
local close_timer = nil

local function get_plugin_dir()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h")
end

local function load_image_nvim()
  local ok, image = pcall(require, "image")
  if not ok then return nil end
  return image
end

function M.is_available()
  return load_image_nvim() ~= nil
end

-- 再生開始。
-- config: { gif_path, duration_ms, width, height }
function M.play(config)
  local image = load_image_nvim()
  if not image then
    vim.notify("Amadeus: image.nvim が見つかりません", vim.log.levels.ERROR)
    return
  end

  local gif_path = config.gif_path or (get_plugin_dir() .. "/amadeus.gif")
  if vim.fn.filereadable(gif_path) == 0 then
    vim.notify("Amadeus: GIF が見つかりません: " .. gif_path, vim.log.levels.WARN)
    return
  end

  -- 既に再生中なら止めてから上書き再生。
  M.stop()

  -- フローティングウィンドウを生成。
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

  -- スキップ用キーバインド。
  vim.keymap.set("n", "q", function() M.stop() end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", function() M.stop() end, { buffer = buf, silent = true })

  -- GIF を読み込んで描画。image.nvim 側で勝手にアニメーションが回る。
  local ok, result = pcall(image.from_file, gif_path, {
    window = win,
    buffer = buf,
    x = 0,
    y = 0,
    width = width,
    height = height,
  })
  if not ok or not result then
    vim.notify("Amadeus: GIF の読み込みに失敗しました", vim.log.levels.ERROR)
    M.stop()
    return
  end
  img = result
  pcall(function() img:render() end)

  -- 指定秒数経過後に自動クローズ。GIF はループ再生されるので明示的に止めないと閉じない。
  -- vim.defer_fn は内部で vim.schedule_wrap してくれるので、ここでは UI 操作をそのまま書ける。
  local duration = config.duration_ms or 3000
  close_timer = vim.defer_fn(function()
    M.stop()
  end, duration)
end

function M.stop()
  if close_timer then
    -- defer_fn の戻り値は uv_timer ハンドル。stop+close で確実に解放。
    pcall(function() close_timer:stop() end)
    pcall(function() close_timer:close() end)
    close_timer = nil
  end
  if img then
    pcall(function() img:clear() end)
    img = nil
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  win, buf = nil, nil
end

return M
