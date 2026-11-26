-- Журнал: последние строки в памяти (для экрана) + файл с ротацией (bec.log → bec.log.old).
local L = {}
L.__index = L

-- o = {now = function() → строка времени, append = function(path, line), size = function(path), rotate = function(path)}
function L.new(o, path, max)
  return setmetatable({o = o or {}, path = path, max = max or 256 * 1024, lines = {}, keep = 40}, L)
end

function L:write(level, msg, code)
  local t = self.o.now and self.o.now() or ""
  local line = string.format("%s %s %s%s", t, level, code and (code .. " ") or "", msg)
  table.insert(self.lines, {t = t, level = level, code = code, msg = msg})
  while #self.lines > self.keep do table.remove(self.lines, 1) end
  if self.o.append and self.path then
    if self.o.size and self.o.rotate and (self.o.size(self.path) or 0) > self.max then self.o.rotate(self.path) end
    pcall(self.o.append, self.path, line)
  end
end

function L:info(m) self:write("I", m) end
function L:warn(m, code) self:write("W", m, code) end
function L:err(m, code) self:write("E", m, code) end

return L
