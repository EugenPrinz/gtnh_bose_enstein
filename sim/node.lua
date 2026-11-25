-- IO Node (MTEBECIONode): порт incrementProgressTime 1:1 (GT5U 5.09.54.275).
-- net: {asm = Assembler, slowdowns(validSet) → int, drain(type, amount) → взято}
local recipe = require("model.recipe")

local N = {}
N.__index = N

function N.new(net)
  return setmetatable({net = net, state = "Idle", minParallel = 1, maxParallel = 1, speedDivisor = 1,
    subtick = 0, progress = 0, maxProgress = 0, powered = false, slowdowns = 0,
    pauseInstant = false, completed = 0, failed = nil}, N)
end

function N:crafting() return self.maxProgress > 0 end

function N:assemblerEUt() return self:crafting() and self.eut or 0 end

function N:setSpeedDivisor(v)
  self.speedDivisor = v
  self.subtick = 0 -- SpeedDivisorParameter.setValue сбрасывает счётчик
end

-- Старт рецепта, если в шине copies копий. Возвращает P или nil, причина.
function N:start(r, copies)
  if self:crafting() then return nil, "busy" end
  local asm = self.net.asm
  if not asm then return nil, "no_bec_assembler" end
  -- validateRecipe: параллели по входам с потолком maxParallel; затем ParallelHelper режет по EU (1A, без OC)
  local byInputs = math.min(self.maxParallel, copies)
  if byInputs < self.minParallel then return nil, "not_enough_parallels" end
  local P = math.min(byInputs, recipe.maxParallelByPower(r, asm.maxInputEu))
  if P < 1 then return nil, "insufficient_power" end
  self.recipe, self.P, self.eut = r, P, r.eut * P
  self.required = recipe.condensate(r, P)
  self.consumed = {}
  self.steps = recipe.steps(r)
  self.requiredTier = self.steps[1].tier
  self.progress, self.maxProgress = 0, r.dur
  self.state = "Crafting"
  self.failed = nil
  return P
end

function N:clear()
  self.recipe, self.required, self.consumed, self.steps = nil, nil, nil, nil
  self.P, self.eut, self.requiredTier = 0, 0, nil
  self.progress, self.maxProgress = 0, 0
  self.state = "Idle"
end

function N:stop(reason)
  self.failed = reason
  self:clear()
end

function N:tick()
  if not self:crafting() then return end
  local step = recipe.stepAt(self.steps, self.progress)
  if not step then self.state = "InternalError"; return end
  self.requiredTier = step.tier
  local asm = self.net.asm
  if not asm or not asm.running then self.state = "AssemblerOffline"; return end
  if not self.powered then self.state = "Unpowered"; return end
  local provided, available = asm:tier(), asm:available()
  if not provided or provided < self.requiredTier then self.state = "NaniteTierTooLow"; return end
  if self.pauseInstant then self.state = "PausedImmediate"; return end

  self.slowdowns = self.net.slowdowns(self.required)
  local diff = math.abs(self.requiredTier - provided)
  local div = self.P * (1 << diff) * math.max(self.slowdowns + 1, self.speedDivisor)
  self.subtick = self.subtick + available
  local full = self.subtick // div
  self.subtick = self.subtick - full * div
  local nextProgress = self.progress + full

  local gate = recipe.nextGate(self.steps, self.progress, provided)
  if gate then
    if nextProgress == gate.start then self.state = "NaniteTierTooLow" end
    nextProgress = math.min(nextProgress, gate.start)
  end

  if self.slowdowns > 3 then self:stop("bec_clogged"); return end

  for t, need in pairs(self.required) do
    local rem = need - (self.consumed[t] or 0)
    if rem > 0 then
      local got = self.net.drain(t, rem)
      self.consumed[t] = (self.consumed[t] or 0) + got
    end
  end

  self.progress = nextProgress
  self.state = "Crafting"

  if self.progress >= self.maxProgress then
    for t, need in pairs(self.required) do
      if need - (self.consumed[t] or 0) > 0 then self:stop("missing_condensate:" .. t); return end
    end
    self.completed = self.completed + self.P
    self:clear()
  else
    local s = recipe.stepAt(self.steps, self.progress)
    if not s then self.state = "InternalError"; return end
    self.requiredTier = s.tier
  end
end

return N
