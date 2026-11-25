-- Containment Field (MTEBECStorage). Цикл TT-машины — 20 тиков; в начале цикла checkProcessing:
-- если объём > напряжённости поля, каждый тип × 9/10 (целочисленно, x·9/10), нули удаляются.
-- Без работы/питания цикл не начинается: содержимое стирается (stopMachine / add|remove при maxProgress ≤ 0).
local S = {}
S.__index = S

function S.new(strength)
  return setmetatable({strength = strength, contents = {}, allowed = true, powered = true,
    progress = 0, maxProgress = 0, wiped = 0}, S)
end

function S:running() return self.maxProgress > 0 end

function S:amount()
  local s = 0
  for _, v in pairs(self.contents) do s = s + v end
  return s
end

function S:wipe()
  if next(self.contents) then self.wiped = self.wiped + 1 end
  self.contents = {}
end

function S:tick()
  if not self.powered then -- обрыв питания: критическая остановка
    self.maxProgress = 0
    self:wipe()
    return
  end
  if self.maxProgress > 0 then
    self.progress = self.progress + 1
    if self.progress < self.maxProgress then return end
    self.maxProgress = 0
  end
  if not self.allowed then -- новый цикл не начинается → содержимое пропадает
    self:wipe()
    return
  end
  self.progress, self.maxProgress = 0, 20
  if self:amount() > self.strength then
    for t, v in pairs(self.contents) do
      local nv = v * 9 // 10
      self.contents[t] = nv > 0 and nv or nil
    end
  end
end

function S:add(t, a)
  if not self:running() then self:wipe(); return 0 end
  self.contents[t] = (self.contents[t] or 0) + a
  return a
end

-- Забрать до a; вернуть сколько забрано
function S:remove(t, a)
  if not self:running() then self:wipe(); return 0 end
  local have = self.contents[t] or 0
  local take = math.min(have, a)
  if take > 0 then
    local nv = have - take
    self.contents[t] = nv > 0 and nv or nil
  end
  return take
end

return S
