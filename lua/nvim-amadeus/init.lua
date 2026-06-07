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

  -- autoplay が有効なら VimEnter で再生をスケジュール。
  -- VimEnter 直後は UI 情報 (nvim_list_uis) がまだ不安定なことがあるので
  -- vim.schedule で 1tick 遅らせる。
  if M.config.autoplay then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("NvimAmadeusAutoplay", { clear = true }),
      callback = function()
        vim.schedule(function() M.play() end)
      end,
    })
  end
end

return M
