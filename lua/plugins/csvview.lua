return {
  {
    "hat0uma/csvview.nvim",
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
    ft = { "csv", "tsv" },
    opts = {
      parser = { comments = { "#", "//" } },
      -- keep defaults; you can customize later
      -- display_mode = "border", -- optional: try this if you want vertical separators
    },
  },
}
