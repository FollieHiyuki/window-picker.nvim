local fn = vim.fn
local o = vim.o
local api = vim.api

local shift_numbers = {
  [ '!' ] = 1,
  [ '@' ] = 2,
  [ '#' ] = 3,
  [ '$' ] = 4,
  [ '%' ] = 5,
  [ '^' ] = 6,
  [ '&' ] = 7,
  [ '*' ] = 8,
  [ '(' ] = 9,
  [ ')' ] = '$',
}

local defaults = {
  keys = 'alskdjfhgwoeiruty',
  swap_shift = true,
  exclude = { qf = true,  vimTree = true, aerial = true }
}

local M = {
  config = defaults
}

function M.setup(config)
  config = vim.tbl_extend('force', defaults, config or {})
end

-- Annotates and returns the picker window.
-- Returns winid,upper
local function choose(hl)
  local tabpage = api.nvim_get_current_tabpage()
  local win_ids = api.nvim_tabpage_list_wins(tabpage)
  local exclude = M.config.exclude
  local winid = fn.win_getid()

  local candidates = vim.tbl_filter(function (id)
    local bufnr = api.nvim_win_get_buf(id)

    if id == winid then
      return false
    end
    if exclude[api.nvim_buf_get_option(bufnr, 'filetype')] == true then
      return false
    end

    return true
  end, win_ids)

  -- If there are no candidate windows, return nil
  if #candidates == 0 then return -1 end
  -- There is only one candidate
  if #candidates == 1 then return candidates[1] end

  local keys = M.config.keys

  -- Old window statusline
  local old_statuslines = {}
  local win_keys = {}

  -- Save old value and force statusline
  local laststatus = o.laststatus
  o.laststatus = 2

  -- Setup UI
  for i, winid in ipairs(candidates) do
    local key = keys:sub(i, i):upper()

    local ok, old_statusline = pcall(api.nvim_win_get_option, winid, 'statusline')

    if ok == true then
      old_statuslines[winid] = old_statusline
    end

    win_keys[key] = winid

    api.nvim_win_set_option(winid, 'statusline', string.format("%%#%s#%%=%s%%=", hl, key))

    if i > #keys then break end
  end

  vim.cmd("redraw")
  print("Pick window: ")

  -- Get next char
  local input = fn.getchar()

  print('')

  -- Restore window statuslines
  for _, winid in ipairs(candidates) do
    api.nvim_win_set_option(winid, 'statusline', old_statuslines[winid])
  end

  -- Restore laststatus
  o.laststatus = laststatus


  local key = string.char(input)

  -- User entered a number
  if input > 48 and input < 58 then
    return fn.win_getid(input - 48), false
  elseif shift_numbers[key] then
    return fn.win_getid(shift_numbers[key]), true
  else
    return win_keys[key:upper()], bit.band(input, 100000) == 0
  end

end

-- Jumps to `winid`.
-- If `winid` is not given, the windows will be annotated and user will be
-- promted.
function M.pick(winid)
  local upper = false

  if not winid then
    winid, upper = choose('WindowPicker')
  end

  if not winid then
    return
  end

  if upper and M.config.swap_shift then
    M.swap(false, winid)
    return
  end

  api.nvim_set_current_win(winid)

end

-- Swaps current window with `winid`.
-- If `stay` the cursor will stay in the current window. Default behaviour is to
-- follow the buffer.
-- If `winid` is not given, the windows will be annotated and user will be
-- promted.
function M.swap(stay, winid)
  winid = winid or choose('WindowPickerSwap')

  local cur_winid = fn.win_getid()

  if not winid then
    return
  end

  local cur_bufnr = api.nvim_win_get_buf(cur_winid)
  local target_bufnr = api.nvim_win_get_buf(winid)

  api.nvim_win_set_buf(cur_winid, target_bufnr)
  api.nvim_win_set_buf(winid, cur_bufnr)

  if not stay then
    api.nvim_set_current_win(winid)
  end
end

vim.cmd 'hi WindowPicker     guifg=#ededed guibg=#5e81ac gui=bold'
vim.cmd 'hi WindowPickerSwap guifg=#ededed guibg=#d08770 gui=bold'

return M