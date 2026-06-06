local M = {}

-- 設定値。setup() で上書き可能。
M.config = {
  autoplay = false,        -- nvim 起動時に自動再生するか
  video_dir = nil,         -- 既定: プラグインディレクトリ/video_frames
  fps = 15,                -- 1秒あたりのフレーム数
  width = 80,              -- フローティングウィンドウの幅 (セル単位)
  height = 24,             -- フローティングウィンドウの高さ (セル単位)
}

-- 公開 API: 再生を開始。
function M.play()
  require("nvim-amadeus.video").play({
    video_dir = M.config.video_dir,
    fps = M.config.fps,
    width = M.config.width,
    height = M.config.height,
  })
end

-- 公開 API: 再生を中断。
function M.stop()
  require("nvim-amadeus.video").stop()
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- autoplay が有効なら VimEnter で再生をスケジュール。
  -- VimEnter 直後だと UI 情報 (nvim_list_uis) がまだ不安定なことがあるので
  -- vim.schedule で 1tick 遅らせている。
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
