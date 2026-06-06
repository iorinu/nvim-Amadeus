local M = {}

-- 設定値。setup() で上書き可能。
M.config = {
  autoplay = false,        -- nvim 起動時に自動再生するか
  gif_path = nil,          -- 既定: プラグインディレクトリ/amadeus.gif
  duration_ms = 3000,      -- 何ミリ秒で自動クローズするか (GIF はループするので必要)
  width = 80,              -- フローティングウィンドウの幅 (セル単位)
  height = 24,             -- フローティングウィンドウの高さ (セル単位)
}

function M.play()
  require("nvim-amadeus.video").play({
    gif_path = M.config.gif_path,
    duration_ms = M.config.duration_ms,
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
