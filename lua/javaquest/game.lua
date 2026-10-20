-- ---------------------------------------------------------------------------
-- The game layer: XP, levels, achievements.
--
-- All of it is DERIVED from progress, not accumulated. Re-running a test you
-- already passed earns nothing, and a state file that gets deleted only loses
-- your streak and unlock dates, never your progress.
-- ---------------------------------------------------------------------------

local M = {}

function M.xp(config, progress)
  return progress.passing * config.xp_per_test + progress.complete_modules * config.module_bonus
end

function M.max_xp(config, progress)
  return progress.tests * config.xp_per_test + #config.modules * config.module_bonus
end

--- Returns level index (1-based), its name, xp into this level, xp needed for the next.
function M.level(config, xp)
  local levels = config.levels
  local index = 1
  for i, level in ipairs(levels) do
    if xp >= level.at then
      index = i
    end
  end
  local current = levels[index]
  local next_level = levels[index + 1]
  return {
    index = index,
    name = current.name,
    into = xp - current.at,
    span = next_level and (next_level.at - current.at) or nil,
    next_at = next_level and next_level.at or nil,
    max = index == #levels,
  }
end

--- Which achievements are satisfied right now.
function M.earned(config, progress, state)
  local earned = {}
  local streak = require("javaquest.state").streak(state)

  local function set(id)
    earned[id] = true
  end

  if progress.passing > 0 then
    set("first_blood")
  end
  if progress.tests > 0 and progress.passing >= progress.tests / 2 then
    set("halfway")
  end
  if progress.tests > 0 and progress.failing == 0 and progress.passing == progress.tests then
    set("completionist")
  end
  if streak >= 3 then
    set("streak_3")
  end
  if streak >= 7 then
    set("streak_7")
  end
  if state.night_owl then
    set("night_owl")
  end

  -- clear_NN, matched against the module's directory prefix.
  for _, module in ipairs(progress.modules) do
    if module.complete then
      local number = module.dir:match("^(%d+)")
      if number then
        set("clear_" .. number)
      end
    end
  end

  return earned
end

--- Updates unlock timestamps and returns the achievements newly unlocked by this
--- call, so they can be celebrated exactly once.
function M.reconcile(root, config, progress, state)
  local earned = M.earned(config, progress, state)
  local newly = {}

  state.unlocked = state.unlocked or {}
  for _, achievement in ipairs(config.achievements) do
    if earned[achievement.id] and not state.unlocked[achievement.id] then
      state.unlocked[achievement.id] = os.time()
      table.insert(newly, achievement)
    end
  end

  if #newly > 0 then
    require("javaquest.state").save(root, state)
  end
  return newly, earned
end

--- A unicode block progress bar.
function M.bar(current, total, width)
  width = width or 20
  if total <= 0 then
    return string.rep("░", width)
  end
  local filled = math.floor((current / total) * width + 0.5)
  filled = math.max(0, math.min(width, filled))
  return string.rep("█", filled) .. string.rep("░", width - filled)
end

return M
