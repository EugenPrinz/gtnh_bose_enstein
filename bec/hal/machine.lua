-- Энтанглер и Матрица наблюдения: компонент gt_machine, только общие методы GT.
-- Различаются по getName: multi.bec.generator / multi.bec.assembler.
local G = require("hal.gtbase")

local M = setmetatable({}, {__index = G.Base})
M.__index = M

function M.wrap(proxy) return G.wrap(proxy, M) end

-- Энтанглер: доля текущего цикла 0..1 (nil — цикла нет)
function M:cycle()
  local cur, max = self:progress()
  if max <= 0 then return nil end
  return cur / max, cur, max
end

return M
