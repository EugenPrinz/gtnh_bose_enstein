-- Челнок Pending ↔ Input: Redstone I/O. Импульс на все стороны возвращает пустую ячейку (корпус «возврат»);
-- «звонок» (Item Detector корпуса) приходит событием redstone_changed — его ловит main.lua.
local G = require("hal.gtbase")

local S = {}
S.__index = S

function S.new(component)
  local self = setmetatable({c = component}, S)
  for addr in component.list("redstone", true) do self.p = component.proxy(addr); self.addr = addr; break end
  return self
end

function S:ok() return self.p ~= nil end

local function all(level)
  local t = {}
  for side = 0, 5 do t[side] = level end
  return t
end

-- sleep(сек) — os.sleep в игре
function S:pulse(sleep, seconds)
  if not self.p then return nil, "нет компонента redstone (Redstone I/O)" end
  local _, e = G.call(self.p, "setOutput", all(15))
  if e then return nil, "setOutput: " .. e end
  sleep(seconds or 0.2)
  _, e = G.call(self.p, "setOutput", all(0))
  if e then return nil, "setOutput: " .. e end
  return true
end

return S
