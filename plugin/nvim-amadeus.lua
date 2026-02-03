vim.api.nvim_create_user_command("Amadeus", function()
  require("nvim-amadeus").play()
end, { desc = "Play Amadeus animation" })

vim.api.nvim_create_user_command("AmadeusStop", function()
  require("nvim-amadeus").stop()
end, { desc = "Stop Amadeus animation" })
