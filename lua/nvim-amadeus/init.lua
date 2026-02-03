local M = {}

M.config = {
  frame_dir = nil, -- will be set to plugin directory / aa_frames
  fps = 15,
  width = 150,
  height = 47,
}

local timer = nil
local win = nil
local buf = nil
local frames = {}
local current_frame = 1

local function get_plugin_dir()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h")
end

local function load_frames()
  local frame_dir = M.config.frame_dir or (get_plugin_dir() .. "/aa_frames")
  frames = {}

  local i = 0
  while true do
    local filename = string.format("%s/frame_%05d.txt", frame_dir, i)
    local file = io.open(filename, "r")
    if not file then
      break
    end

    local lines = {}
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
    table.insert(frames, lines)
    i = i + 1
  end

  return #frames > 0
end

local function create_window()
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local ui = vim.api.nvim_list_uis()[1]
  local width = M.config.width
  local height = M.config.height

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = "minimal",
    border = "rounded",
  }

  win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(win, "winblend", 0)

  -- Close on any key press
  vim.keymap.set("n", "q", function()
    M.stop()
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    M.stop()
  end, { buffer = buf, silent = true })
end

local function display_frame(frame_index)
  if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
    M.stop()
    return
  end

  local frame = frames[frame_index]
  if frame then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, frame)
  end
end

local function animate()
  display_frame(current_frame)
  current_frame = current_frame + 1
  if current_frame > #frames then
    current_frame = 1 -- loop
  end
end

function M.play()
  if timer then
    M.stop()
  end

  if not load_frames() then
    vim.notify("No frames found in aa_frames directory", vim.log.levels.ERROR)
    return
  end

  current_frame = 1
  create_window()

  local interval = math.floor(1000 / M.config.fps)
  timer = vim.loop.new_timer()
  timer:start(0, interval, vim.schedule_wrap(animate))
end

function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  win = nil
  buf = nil
  current_frame = 1
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
