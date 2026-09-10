local M = {}
local api = vim.api

---------------------------------------------------------------
-- Constants
---------------------------------------------------------------
local ROWS = 20
local COLS = 10
local TOTAL_ROWS = ROWS + 4
local BLOCK = "██"
local BLOCK_BYTES = 6
local PANEL_W = 14

local GRAVITY_MS = { 1000, 800, 650, 500, 400, 300, 230, 170, 130 }
local function gravity(lvl) return GRAVITY_MS[math.min(lvl, #GRAVITY_MS)] or 100 end

local LINE_SCORE = { [1] = 100, [2] = 300, [3] = 500, [4] = 800 }

---------------------------------------------------------------
-- Pieces (SRS standard)
---------------------------------------------------------------
local PIECES = {
  { name = "I", hl = "TetrisI", offsets = {{-1,0},{0,0},{1,0},{2,0}}, kick = "I" },
  { name = "O", hl = "TetrisO", offsets = {{0,0},{1,0},{0,1},{1,1}}, kick = "O" },
  { name = "T", hl = "TetrisT", offsets = {{-1,0},{0,0},{1,0},{0,1}}, kick = "N" },
  { name = "S", hl = "TetrisS", offsets = {{-1,0},{0,0},{0,1},{1,1}}, kick = "N" },
  { name = "Z", hl = "TetrisZ", offsets = {{0,0},{1,0},{-1,1},{0,1}}, kick = "N" },
  { name = "J", hl = "TetrisJ", offsets = {{-1,1},{-1,0},{0,0},{1,0}}, kick = "N" },
  { name = "L", hl = "TetrisL", offsets = {{-1,0},{0,0},{1,0},{1,1}}, kick = "N" },
}

-- SRS wall kick tests for clockwise rotation (from_state → from_state+1)
local KICKS = {
  N = {
    [0] = {{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},
    [1] = {{0,0},{1,0},{1,-1},{0,2},{1,2}},
    [2] = {{0,0},{1,0},{1,1},{0,-2},{1,-2}},
    [3] = {{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},
  },
  I = {
    [0] = {{0,0},{-2,0},{1,0},{-2,-1},{1,2}},
    [1] = {{0,0},{-1,0},{2,0},{-1,2},{2,-1}},
    [2] = {{0,0},{2,0},{-1,0},{2,1},{-1,-2}},
    [3] = {{0,0},{1,0},{-2,0},{1,-2},{-2,1}},
  },
  O = { [0] = {{0,0}}, [1] = {{0,0}}, [2] = {{0,0}}, [3] = {{0,0}} },
}

---------------------------------------------------------------
-- Highlights
---------------------------------------------------------------
local function setup_highlights()
  local float_hl = api.nvim_get_hl(0, { name = "NormalFloat", link = false })
  local bg = float_hl.bg and string.format("#%06x", float_hl.bg) or "#1a1b26"

  api.nvim_set_hl(0, "TetrisI", { fg = "#00f0f0" })
  api.nvim_set_hl(0, "TetrisO", { fg = "#f0f000" })
  api.nvim_set_hl(0, "TetrisT", { fg = "#a000f0" })
  api.nvim_set_hl(0, "TetrisS", { fg = "#00f000" })
  api.nvim_set_hl(0, "TetrisZ", { fg = "#f00000" })
  api.nvim_set_hl(0, "TetrisJ", { fg = "#0060f0" })
  api.nvim_set_hl(0, "TetrisL", { fg = "#f0a000" })
  api.nvim_set_hl(0, "TetrisBg", { fg = bg })
  api.nvim_set_hl(0, "TetrisGhost", { fg = "#3b3d57" })
  api.nvim_set_hl(0, "TetrisLabel", { fg = "#7aa2f7", bold = true })
  api.nvim_set_hl(0, "TetrisValue", { fg = "#c0caf5" })
  api.nvim_set_hl(0, "TetrisGameOver", { fg = "#f7768e", bold = true })
end

---------------------------------------------------------------
-- State
---------------------------------------------------------------
local S = {}
local bag = {}

local function reset_state()
  S.board = {}
  for r = 1, TOTAL_ROWS do
    S.board[r] = {}
    for c = 1, COLS do S.board[r][c] = false end
  end
  S.piece = nil
  S.pivot = { 0, 0 }
  S.rotation = 0
  S.next_piece = nil
  S.hold_piece = nil
  S.hold_used = false
  S.score = 0
  S.level = 1
  S.lines = 0
  S.game_over = false
  S.timer = nil
  S.buf = nil
  S.win = nil
  S.ns = nil
  bag = {}
end

---------------------------------------------------------------
-- Rotation & collision
---------------------------------------------------------------
local function rotated_offsets(piece, rot)
  local r = rot % 4
  local out = {}
  for _, o in ipairs(piece.offsets) do
    local x, y = o[1], o[2]
    for _ = 1, r do x, y = y, -x end
    out[#out + 1] = { x, y }
  end
  return out
end

local function cells_at(piece, pivot, rot)
  local out = {}
  for _, o in ipairs(rotated_offsets(piece, rot)) do
    out[#out + 1] = { pivot[1] + o[1], pivot[2] + o[2] }
  end
  return out
end

local function is_valid(piece, pivot, rot)
  for _, cell in ipairs(cells_at(piece, pivot, rot)) do
    local c, r = cell[1], cell[2]
    if c < 1 or c > COLS or r < 1 then return false end
    if r <= TOTAL_ROWS and S.board[r] and S.board[r][c] then return false end
  end
  return true
end

---------------------------------------------------------------
-- 7-bag randomizer
---------------------------------------------------------------
local function next_from_bag()
  if #bag == 0 then
    for i = 1, #PIECES do bag[i] = i end
    for i = #bag, 2, -1 do
      local j = math.random(1, i)
      bag[i], bag[j] = bag[j], bag[i]
    end
  end
  return PIECES[table.remove(bag)]
end

---------------------------------------------------------------
-- Forward declarations
---------------------------------------------------------------
local render, start_gravity, stop_gravity, spawn, lock_and_clear

---------------------------------------------------------------
-- Movement
---------------------------------------------------------------
local function try_move(dx, dy)
  if S.game_over or not S.piece then return false end
  local np = { S.pivot[1] + dx, S.pivot[2] + dy }
  if is_valid(S.piece, np, S.rotation) then
    S.pivot = np
    render()
    return true
  end
  return false
end

local function try_rotate()
  if S.game_over or not S.piece then return end
  local new_rot = (S.rotation + 1) % 4
  for _, kick in ipairs(KICKS[S.piece.kick][S.rotation]) do
    local np = { S.pivot[1] + kick[1], S.pivot[2] + kick[2] }
    if is_valid(S.piece, np, new_rot) then
      S.pivot = np
      S.rotation = new_rot
      render()
      return
    end
  end
end

local function hard_drop()
  if S.game_over or not S.piece then return end
  local dropped = 0
  while is_valid(S.piece, { S.pivot[1], S.pivot[2] - 1 }, S.rotation) do
    S.pivot[2] = S.pivot[2] - 1
    dropped = dropped + 1
  end
  S.score = S.score + dropped * 2
  lock_and_clear()
end

local function soft_drop()
  if try_move(0, -1) then S.score = S.score + 1 end
end

local function do_hold()
  if S.game_over or not S.piece or S.hold_used then return end
  stop_gravity()
  local prev_hold = S.hold_piece
  S.hold_piece = S.piece
  S.hold_used = true
  S.piece = nil
  if prev_hold then
    spawn(prev_hold)
  else
    local next = S.next_piece
    S.next_piece = next_from_bag()
    spawn(next)
  end
end

---------------------------------------------------------------
-- Spawn & lock
---------------------------------------------------------------
spawn = function(piece_def)
  S.piece = piece_def
  S.pivot = { 5, 21 }
  S.rotation = 0

  if not is_valid(S.piece, S.pivot, S.rotation) then
    S.game_over = true
    stop_gravity()
    render()
    return
  end

  if is_valid(S.piece, { 5, 20 }, S.rotation) then
    S.pivot = { 5, 20 }
  end

  start_gravity()
  render()
end

lock_and_clear = function()
  stop_gravity()
  S.hold_used = false

  for _, cell in ipairs(cells_at(S.piece, S.pivot, S.rotation)) do
    local c, r = cell[1], cell[2]
    if r >= 1 and r <= TOTAL_ROWS then
      S.board[r][c] = S.piece.hl
    end
  end

  local cleared = 0
  local r = 1
  while r <= TOTAL_ROWS do
    local full = true
    for c = 1, COLS do
      if not S.board[r][c] then full = false; break end
    end
    if full then
      table.remove(S.board, r)
      local empty = {}
      for c = 1, COLS do empty[c] = false end
      table.insert(S.board, empty)
      cleared = cleared + 1
    else
      r = r + 1
    end
  end

  if cleared > 0 then
    S.score = S.score + (LINE_SCORE[cleared] or 0) * S.level
    S.lines = S.lines + cleared
    S.level = math.floor(S.lines / 10) + 1
  end

  local next = S.next_piece
  S.next_piece = next_from_bag()
  spawn(next)
end

---------------------------------------------------------------
-- Gravity timer
---------------------------------------------------------------
start_gravity = function()
  stop_gravity()
  S.timer = vim.uv.new_timer()
  local ms = gravity(S.level)
  S.timer:start(ms, ms, vim.schedule_wrap(function()
    if S.game_over or not S.buf or not api.nvim_buf_is_valid(S.buf) then
      stop_gravity()
      return
    end
    if not try_move(0, -1) then
      lock_and_clear()
    end
  end))
end

stop_gravity = function()
  if S.timer then
    if not S.timer:is_closing() then
      S.timer:stop()
      S.timer:close()
    end
    S.timer = nil
  end
end

---------------------------------------------------------------
-- Piece preview rendering
---------------------------------------------------------------
local function piece_preview(piece_def, width)
  local blank = string.rep(" ", width)
  if not piece_def then return { blank, blank }, nil, {} end

  local offsets = piece_def.offsets
  local min_x, max_x, min_y, max_y = 99, -99, 99, -99
  for _, o in ipairs(offsets) do
    if o[1] < min_x then min_x = o[1] end
    if o[1] > max_x then max_x = o[1] end
    if o[2] < min_y then min_y = o[2] end
    if o[2] > max_y then max_y = o[2] end
  end

  local pw, ph = max_x - min_x + 1, max_y - min_y + 1
  local grid = {}
  for y = 0, ph - 1 do
    grid[y] = {}
    for x = 0, pw - 1 do grid[y][x] = false end
  end
  for _, o in ipairs(offsets) do
    grid[o[2] - min_y][o[1] - min_x] = true
  end

  local lines = {}
  local ranges = {}

  for li = 1, 2 do
    local y = (ph - 1) - (li - 1)
    if y >= 0 then
      local pad = math.floor((width - pw * 2) / 2)
      local parts = { string.rep(" ", pad) }
      local byte = pad

      for x = 0, pw - 1 do
        if grid[y][x] then
          ranges[#ranges + 1] = { li, byte, byte + BLOCK_BYTES }
          parts[#parts + 1] = BLOCK
          byte = byte + BLOCK_BYTES
        else
          parts[#parts + 1] = "  "
          byte = byte + 2
        end
      end
      lines[li] = table.concat(parts)
    else
      lines[li] = blank
    end
  end

  return lines, piece_def.hl, ranges
end

---------------------------------------------------------------
-- Render
---------------------------------------------------------------
render = function()
  if not S.buf or not api.nvim_buf_is_valid(S.buf) then return end

  local piece_map, ghost_map = {}, {}
  if S.piece and not S.game_over then
    for _, cell in ipairs(cells_at(S.piece, S.pivot, S.rotation)) do
      piece_map[cell[2] * 100 + cell[1]] = S.piece.hl
    end
    local gp = { S.pivot[1], S.pivot[2] }
    while is_valid(S.piece, { gp[1], gp[2] - 1 }, S.rotation) do
      gp[2] = gp[2] - 1
    end
    if gp[2] ~= S.pivot[2] then
      for _, cell in ipairs(cells_at(S.piece, gp, S.rotation)) do
        ghost_map[cell[2] * 100 + cell[1]] = true
      end
    end
  end

  local next_lines, next_hl, next_ranges = piece_preview(S.next_piece, PANEL_W)
  local hold_lines, hold_hl, hold_ranges = piece_preview(S.hold_piece, PANEL_W)

  local panel = {}
  panel[0]  = "  NEXT"
  panel[1]  = next_lines[1]
  panel[2]  = next_lines[2]
  panel[3]  = ""
  panel[4]  = "  HOLD" .. (S.hold_used and " *" or "")
  panel[5]  = hold_lines[1]
  panel[6]  = hold_lines[2]
  panel[7]  = ""
  panel[8]  = "  SCORE"
  panel[9]  = "  " .. tostring(S.score)
  panel[10] = ""
  panel[11] = "  LEVEL"
  panel[12] = "  " .. tostring(S.level)
  panel[13] = ""
  panel[14] = "  LINES"
  panel[15] = "  " .. tostring(S.lines)
  panel[16] = ""
  panel[17] = "  ──────────"
  panel[18] = "  WASD Move"
  panel[19] = "  J:Drop H:Hold"

  if S.game_over then
    panel[17] = ""
    panel[18] = "  GAME OVER"
    panel[19] = "  R:Again Q:Quit"
  end

  local playfield = string.rep(BLOCK, COLS)
  local pf_bytes = #playfield
  local panel_start = pf_bytes + 2

  local buf_lines = {}
  local hls = {}

  for i = 0, ROWS - 1 do
    local row = ROWS - i
    buf_lines[i + 1] = playfield .. "  " .. (panel[i] or "")

    for c = 1, COLS do
      local key = row * 100 + c
      local hl
      if piece_map[key] then
        hl = piece_map[key]
      elseif S.board[row] and S.board[row][c] then
        hl = S.board[row][c]
      elseif ghost_map[key] then
        hl = "TetrisGhost"
      else
        hl = "TetrisBg"
      end
      hls[#hls + 1] = { i, (c - 1) * BLOCK_BYTES, c * BLOCK_BYTES, hl }
    end

    -- Panel label highlights
    local is_label = (i == 0 or i == 4 or i == 8 or i == 11 or i == 14)
    local is_value = (i == 9 or i == 12 or i == 15)
    if is_label then
      hls[#hls + 1] = { i, panel_start, panel_start + #(panel[i] or ""), "TetrisLabel" }
    elseif is_value then
      hls[#hls + 1] = { i, panel_start, panel_start + #(panel[i] or ""), "TetrisValue" }
    elseif i == 18 and S.game_over then
      hls[#hls + 1] = { i, panel_start, panel_start + #(panel[i] or ""), "TetrisGameOver" }
    end
  end

  -- Preview piece highlights
  for _, rng in ipairs(next_ranges) do
    hls[#hls + 1] = { rng[1], panel_start + rng[2], panel_start + rng[3], next_hl }
  end
  for _, rng in ipairs(hold_ranges) do
    hls[#hls + 1] = { rng[1] + 4, panel_start + rng[2], panel_start + rng[3], hold_hl }
  end

  vim.bo[S.buf].modifiable = true
  api.nvim_buf_set_lines(S.buf, 0, -1, false, buf_lines)
  vim.bo[S.buf].modifiable = false

  api.nvim_buf_clear_namespace(S.buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    api.nvim_buf_add_highlight(S.buf, S.ns, h[4], h[1], h[2], h[3])
  end
end

---------------------------------------------------------------
-- Start / Stop
---------------------------------------------------------------
function M.start()
  if S.buf and api.nvim_buf_is_valid(S.buf) then
    M.stop()
  end

  setup_highlights()
  math.randomseed(os.time())
  reset_state()

  S.buf = api.nvim_create_buf(false, true)
  vim.bo[S.buf].bufhidden = "wipe"
  vim.bo[S.buf].buftype = "nofile"
  vim.bo[S.buf].swapfile = false
  vim.bo[S.buf].modifiable = false

  S.ns = api.nvim_create_namespace("tetris")

  local width = COLS * 2 + 2 + PANEL_W
  local height = ROWS
  S.win = api.nvim_open_win(S.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " TETRIS ",
    title_pos = "center",
  })

  vim.wo[S.win].number = false
  vim.wo[S.win].relativenumber = false
  vim.wo[S.win].cursorline = false
  vim.wo[S.win].wrap = false

  -- Block all letter keys
  local opts = { buffer = S.buf, silent = true, nowait = true, noremap = true }
  for i = 97, 122 do
    local key = string.char(i)
    vim.keymap.set("n", key, "", opts)
    vim.keymap.set("n", string.upper(key), "", opts)
  end

  -- Game controls
  vim.keymap.set("n", "a", function() try_move(-1, 0) end, opts)
  vim.keymap.set("n", "d", function() try_move(1, 0) end, opts)
  vim.keymap.set("n", "s", soft_drop, opts)
  vim.keymap.set("n", "w", try_rotate, opts)
  vim.keymap.set("n", "j", hard_drop, opts)
  vim.keymap.set("n", "h", do_hold, opts)
  vim.keymap.set("n", "q", function() M.stop() end, opts)
  vim.keymap.set("n", "<Esc>", function() M.stop() end, opts)
  vim.keymap.set("n", "r", function()
    if S.game_over then M.start() end
  end, opts)

  -- Arrow key alternatives
  vim.keymap.set("n", "<Left>", function() try_move(-1, 0) end, opts)
  vim.keymap.set("n", "<Right>", function() try_move(1, 0) end, opts)
  vim.keymap.set("n", "<Down>", soft_drop, opts)
  vim.keymap.set("n", "<Up>", try_rotate, opts)
  vim.keymap.set("n", "<Space>", hard_drop, opts)

  api.nvim_create_autocmd("BufWipeout", {
    buffer = S.buf,
    once = true,
    callback = function()
      stop_gravity()
      S.buf = nil
      S.win = nil
    end,
  })

  -- Start
  S.next_piece = next_from_bag()
  local first = next_from_bag()
  S.next_piece = next_from_bag()
  spawn(first)
end

function M.stop()
  stop_gravity()
  if S.win and api.nvim_win_is_valid(S.win) then
    api.nvim_win_close(S.win, true)
  end
  S.buf = nil
  S.win = nil
end

vim.api.nvim_create_user_command("Tetris", function() M.start() end, {})

return M
