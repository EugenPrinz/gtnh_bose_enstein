-- Общие методы GT-машины (есть у всех пяти BEC-машин, DESIGN §1.6).
-- Все вызовы — через call(): ошибка драйвера или пропавший компонент не роняют программу.
local G = {}

G.NAMES = {
  ["multi.bec.io-node"] = "node",
  ["multi.bec.diode"] = "diode",
  ["multi.bec.storage"] = "storage",
  ["multi.bec.generator"] = "entangler",
  ["multi.bec.assembler"] = "array",
}

-- Вызов метода прокси: значения или nil, ошибка
function G.call(p, method, ...)
  local f = p[method]
  if f == nil then return nil, "нет метода " .. method end
  local res = table.pack(pcall(f, ...))
  if not res[1] then return nil, tostring(res[2]) end
  return table.unpack(res, 2, res.n)
end

local Base = {}
Base.__index = Base
G.Base = Base

function G.wrap(proxy, cls)
  local o = setmetatable({p = proxy, addr = proxy.address}, cls or Base)
  return o
end

function Base:call(m, ...) return G.call(self.p, m, ...) end

-- «multi.bec.io-node» и т.п.
function Base:name() return self:call("getName") end

function Base:kind()
  local n = self:name()
  return n and G.NAMES[n] or nil, n
end

-- {x, y, z} (драйвер отдаёт три числа)
function Base:coords()
  local x, y, z = self:call("getCoordinates")
  if type(x) == "table" then x, y, z = x[1], x[2], x[3] end
  if type(x) ~= "number" then return nil, y end
  return {x, y, z}
end

-- Структура собрана и есть энергохетч: ёмкость буфера > 0 (DESIGN §1.6)
function Base:formed()
  local cap = self:call("getEUMaxStored")
  return type(cap) == "number" and cap > 0
end

function Base:eu()
  return self:call("getStoredEU") or 0, self:call("getEUMaxStored") or 0
end

function Base:euIn() return self:call("getAverageElectricInput") or 0 end
function Base:active() return self:call("isMachineActive") == true end
function Base:hasWork() return self:call("hasWork") == true end
function Base:allowed() return self:call("isWorkAllowed") == true end
function Base:setAllowed(b) return self:call("setWorkAllowed", b and true or false) end

function Base:progress()
  return self:call("getWorkProgress") or 0, self:call("getWorkMaxProgress") or 0
end

-- Для журнала: строки сканера GT как есть
function Base:info()
  local t = self:call("getSensorInformation")
  return type(t) == "table" and t or {}
end

-- Снимок для becctl diag
function Base:snapshot()
  local s = {addr = self.addr, name = self:name(), coords = self:coords(), formed = self:formed(),
    active = self:active(), hasWork = self:hasWork(), allowed = self:allowed()}
  s.eu, s.euMax = self:eu()
  s.euIn = self:euIn()
  s.progress, s.maxProgress = self:progress()
  return s
end

-- Методы, которые HAL вызывает у всех машин (сверяются с дампом из игры в tests/test_hal.lua)
G.USES = {"getName", "getCoordinates", "getEUMaxStored", "getStoredEU", "getAverageElectricInput",
  "isMachineActive", "hasWork", "isWorkAllowed", "setWorkAllowed", "getWorkProgress", "getWorkMaxProgress",
  "getSensorInformation"}

return G
