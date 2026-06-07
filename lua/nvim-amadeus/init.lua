local M = {}

-- 設定値。setup() で上書き可能。
M.config = {
  autoplay = false,        -- nvim 起動時に自動再生するか
  frames_dir = nil,        -- 既定: プラグインディレクトリ/amadeus_frames
  fps = 15,                -- 1秒あたりのフレーム数 (フレーム数 × 1/fps が再生時間)
  width = 120,             -- フローティングウィンドウの幅 (セル単位)
  height = 34,             -- フローティングウィンドウの高さ (セル単位)
}

function M.play()
  require("nvim-amadeus.video").play({
    frames_dir = M.config.frames_dir,
    fps = M.config.fps,
    width = M.config.width,
    height = M.config.height,
  })
end

function M.stop()
  require("nvim-amadeus.video").stop()
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- autoplay が有効なら再生をスケジュール。
  -- ややこしい事情:
  --   - 通常のロード (init.lua から直接 setup): VimEnter 前に setup される → autocmd で拾う
  --   - lazy.nvim の event="VimEnter" 経由ロード: VimEnter コールバック中に setup される。
  --     この時点では v:vim_did_enter はまだ 0 で、新しく登録した VimEnter autocmd は
  --     今回の発火には間に合わない。次の event-loop tick で vim.schedule が拾う。
  --   - lazy.nvim の cmd/keys 等で VimEnter 後にロード: vim.schedule が即時実行される。
  -- 上記をすべてカバーするために、autocmd と vim.schedule を両方仕掛けて、
  -- once フラグで二重再生を防ぐ。
  if M.config.autoplay then
    local fired = false
    local play_once = function()
      if fired then return end
      fired = true
      M.play()
    end
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("NvimAmadeusAutoplay", { clear = true }),
      once = true,
      callback = function() vim.schedule(play_once) end,
    })
    vim.schedule(play_once)
  end
end

return M
