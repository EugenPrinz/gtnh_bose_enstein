-- Экран линии (GPU T3, 160×50; на меньшем — ужимается). Рисует снимок line:view(), кнопки — по клику (touch).
local U = {}
U.__index = U

local C = {bg = 0x0E121C, panel = 0x161C28, frame = 0x2A3350, text = 0xE6EAF2, dim = 0x8A93A8, acc = 0x4FD8FF,
  ok = 0x6BE38A, warn = 0xFFC24F, err = 0xFF5A5A, bar = 0x4FD8FF, barbg = 0x2A3350, btn = 0x26304A}

local TIERNAME = {"Carbon", "Silver", "Gold", "Transcendent", "Six-Phased Cu", "White Dwarf", "Black Dwarf",
  "Universium", "Eternity", "MagMatter"}

local ulen = (utf8 and utf8.len) or function(s) return #s end
local function usub(s, n)
  if (ulen(s) or #s) <= n then return s end
  local cut = utf8 and utf8.offset(s, n + 1)
  return cut and s:sub(1, cut - 1) or s:sub(1, n)
end
local function fmt(n)
  n = math.floor(n or 0)
  local s = tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (s:gsub("^ ", ""))
end
local function tm(sec)
  if not sec then return "—" end
  sec = math.floor(sec)
  if sec >= 3600 then return string.format("%d:%02d:%02d", sec // 3600, sec % 3600 // 60, sec % 60) end
  return string.format("%d:%02d", sec // 60, sec % 60)
end
U.fmt, U.tm = fmt, tm

function U.new(gpu)
  local self = setmetatable({g = gpu, buttons = {}}, U)
  local w, h = gpu.maxResolution()
  self.W, self.H = math.min(w, 160), math.min(h, 50)
  pcall(gpu.setResolution, self.W, self.H)
  -- рисуем в буфер видеопамяти и копируем разом — без мерцания (если GPU умеет)
  if gpu.allocateBuffer then
    local ok, b = pcall(gpu.allocateBuffer, self.W, self.H)
    if ok and b then self.buf = b end
  end
  return self
end

function U:close()
  if self.buf then pcall(self.g.setActiveBuffer, 0); pcall(self.g.freeBuffer, self.buf); self.buf = nil end
  pcall(self.g.setBackground, 0x000000); pcall(self.g.setForeground, 0xFFFFFF)
end

function U:put(x, y, s, fg, bg)
  if y < 1 or y > self.H or x > self.W then return end
  s = usub(s, self.W - x + 1)
  if bg then self.g.setBackground(bg) end
  self.g.setForeground(fg or C.text)
  self.g.set(x, y, s)
end

function U:box(x, y, w, h, title, col)
  local g = self.g
  g.setBackground(C.panel)
  g.fill(x, y, w, h, " ")
  g.setForeground(col or C.frame)
  g.set(x, y, "┌" .. string.rep("─", w - 2) .. "┐")
  g.set(x, y + h - 1, "└" .. string.rep("─", w - 2) .. "┘")
  for yy = y + 1, y + h - 2 do g.set(x, yy, "│"); g.set(x + w - 1, yy, "│") end
  if title then self:put(x + 2, y, " " .. title .. " ", col or C.acc, C.panel) end
end

function U:bar(x, y, w, frac, col)
  frac = math.max(0, math.min(1, frac or 0))
  local n = math.floor(w * frac + 0.5)
  self.g.setBackground(col or C.bar); self.g.fill(x, y, n, 1, " ")
  self.g.setBackground(C.barbg); self.g.fill(x + n, y, w - n, 1, " ")
  self.g.setBackground(C.panel)
end

function U:button(x, y, label, id, col)
  local w = ulen(label) + 2
  self:put(x, y, " " .. label .. " ", C.text, col or C.btn)
  self.buttons[#self.buttons + 1] = {x = x, y = y, w = w, id = id}
  return x + w + 1
end

-- Строка ввода числа: open → key(ch, code) → "apply", число | "cancel" | nil
function U:openInput(start) self.input = {text = start and tostring(start) or ""} end
function U:key(ch, code)
  local inp = self.input
  if not inp then return nil end
  if code == 28 or code == 156 then -- Enter
    local n = math.tointeger(tonumber(inp.text))
    if not n then inp.err = "нужно целое число"; return nil end
    return "apply", n
  elseif code == 1 then self.input = nil; return "cancel" -- Esc
  elseif code == 14 then inp.text = inp.text:sub(1, -2); inp.err = nil -- Backspace
  elseif ch and ch >= 48 and ch <= 57 and #inp.text < 12 then inp.text = inp.text .. string.char(ch); inp.err = nil
  end
  return nil
end

function U:hit(x, y)
  for _, b in ipairs(self.buttons) do
    if y == b.y and x >= b.x and x < b.x + b.w then return b.id end
  end
end

local STATE_COL = {crafting = C.ok, idle = C.dim, ["nanite-tier-too-low"] = C.warn, unpowered = C.err,
  ["assembler-offline"] = C.err, ["paused-immediate"] = C.warn, ["paused-step"] = C.warn, ["internal-error"] = C.err}

function U:draw(v)
  local g, W, H = self.g, self.W, self.H
  self.buttons = {}
  if self.buf then g.setActiveBuffer(self.buf) end
  g.setBackground(C.bg); g.fill(1, 1, W, H, " ")
  -- верхняя строка
  local b = v.batch
  local head = "BEC · " .. (b and (b.name .. " ×" .. b.copies) or "нет партии") .. " · " .. v.phaseRu
  if v.strategy then head = head .. " · " .. v.strategy end
  if v.steps then
    local t = {}
    for _, x in ipairs(v.steps) do t[#t + 1] = "T" .. x end
    head = head .. " " .. table.concat(t, "→")
  end
  if v.elapsed then head = head .. " · " .. tm(v.elapsed) end
  self:put(2, 1, head, v.phase == "FAULT" and C.err or C.acc, C.bg)
  local bx = W - 34
  bx = self:button(bx, 1, v.paused and "Продолжить" or "Пауза", "pause", v.paused and C.warn or C.btn)
  bx = self:button(bx, 1, "Diag", "diag")
  self:button(bx, 1, "Сброс", "reset", v.phase == "FAULT" and C.err or C.btn)
  -- три машины
  local w3 = (W - 4) // 3
  local y = 3
  self:box(2, y, w3, 6, "Энтанглер", (v.ent and v.ent.active) and C.ok or C.frame)
  if v.ent then
    self:put(4, y + 1, v.ent.max > 0 and string.format("цикл %s / %s с", tm(v.ent.cur / 20), tm(v.ent.max / 20)) or "простой", C.text, C.panel)
    self:bar(4, y + 2, w3 - 4, v.ent.max > 0 and v.ent.cur / v.ent.max or 0)
    self:put(4, y + 3, "EU " .. (v.ent.cap > 0 and string.format("%d%%", v.ent.eu * 100 // v.ent.cap) or "—"), C.dim, C.panel)
  end
  local fx = 3 + w3
  self:box(fx, y, w3, 6, "Поле удержания", (v.field and v.field.active) and C.ok or C.err)
  if v.field then
    local sum = 0
    for _, a in pairs(v.field.stored) do sum = sum + a end
    local over = sum > v.field.strength
    self:put(fx + 2, y + 1, string.format("%s / %s L%s", fmt(sum), fmt(v.field.strength), over and "  РАСПАД" or ""), over and C.err or C.text, C.panel)
    self:bar(fx + 2, y + 2, w3 - 4, v.field.strength > 0 and sum / v.field.strength or 0, over and C.err or C.bar)
    local line, n = {}, 0
    for t, a in pairs(v.field.stored) do
      n = n + 1
      if n <= 3 then
        local need = v.field.need and v.field.need[t]
        line[#line + 1] = string.format("%s %s%s", t, fmt(a), need and ("/" .. fmt(need)) or "")
      end
    end
    self:put(fx + 2, y + 3, table.concat(line, "  "), C.dim, C.panel)
    self:put(fx + 2, y + 4, "EU " .. (v.field.cap > 0 and string.format("%d%%", v.field.eu * 100 // v.field.cap) or "—"), C.dim, C.panel)
    local bx = fx + w3 - 26
    bx = self:button(bx, y + 4, "Изменить", "field", self.input and C.acc or C.btn)
    self:button(bx, y + 4, v.field.auto and "Авто: вкл" or "Авто: выкл", "fieldauto", v.field.auto and C.ok or C.btn)
  end
  local gx = 4 + 2 * w3
  self:box(gx, y, W - gx, 6, "Затвор Максвелла", (v.gate and v.gate.active) and C.ok or C.err)
  if v.gate then
    local f = {}
    for i = 1, 19 do if v.gate.filters[i] then f[#f + 1] = tostring(v.gate.filters[i]) end end
    self:put(gx + 2, y + 1, "маршрут:", C.dim, C.panel)
    self:put(gx + 2, y + 2, #f > 0 and table.concat(f, ", ") or "открыт ВСЁ (нет фильтров!)", #f > 0 and C.text or C.err, C.panel)
  end
  -- наниты
  y = y + 7
  local nt = v.tier and (string.format("T%d %s · %s шт.", v.tier, TIERNAME[v.tier] or "", fmt(v.N))) or "не загружены"
  if v.load and #v.load > 1 then
    local parts = {}
    for _, o in ipairs(v.load) do parts[#parts + 1] = string.format("T%d×%s", o[1], fmt(o[2])) end
    nt = nt .. " (" .. table.concat(parts, " + ") .. ")"
  end
  if v.array and not v.array.active then nt = nt .. " · Матрица НЕ работает" end
  self:box(2, y, W - 2, 3, "Наниты", v.tier and C.ok or C.frame)
  self:put(4, y + 1, nt, C.text, C.panel)
  -- узлы: плитки 4 в ряд
  y = y + 4
  local cols, tw = 4, (W - 2) // 4
  local rows = math.max(1, math.ceil(#v.nodes / cols))
  self:box(2, y, W - 2, rows * 3 + 2, "IO Node (" .. #v.nodes .. ")")
  for k, n in ipairs(v.nodes) do
    local cx = 4 + ((k - 1) % cols) * tw
    local cy = y + 1 + ((k - 1) // cols) * 3
    local col = n.slow > 0 and C.err or STATE_COL[n.state] or C.text
    self:put(cx, cy, string.format("%2d %s%s%s", n.i, n.state, n.P and (" P" .. n.P) or "", n.tier and (" T" .. n.tier) or ""), col, C.panel)
    self:bar(cx, cy + 1, tw - 4, n.max > 0 and n.cur / n.max or 0, col)
    if n.slow > 0 then self:put(cx + tw - 12, cy, "загр. " .. n.slow, C.err, C.panel) end
  end
  -- ошибка, строка ввода и журнал
  y = y + rows * 3 + 3
  if self.input then
    self:put(2, y, "Напряжённость поля, L: ", C.acc, C.bg)
    self:put(25, y, " " .. self.input.text .. "_" .. string.rep(" ", 12 - #self.input.text), C.text, C.btn)
    self:put(41, y, "Enter — применить, Esc — отмена" .. (self.input.err and ("   ✗ " .. self.input.err) or ""),
      self.input.err and C.err or C.dim, C.bg)
    y = y + 2
  end
  if v.err then
    self:put(2, y, "✗ " .. v.err.code .. ": " .. v.err.msg, C.err, C.bg)
    if v.err.action then self:put(4, y + 1, "→ " .. v.err.action, C.warn, C.bg) end
    y = y + 2
  end
  local left = H - y
  local lines = v.log or {}
  for k = math.max(1, #lines - left + 1), #lines do
    local l = lines[k]
    local col = l.level == "E" and C.err or l.level == "W" and C.warn or C.dim
    self:put(2, y, string.format("%s %s%s", l.t, l.code and (l.code .. " ") or "", l.msg), col, C.bg)
    y = y + 1
  end
  if self.buf then g.setActiveBuffer(0); g.bitblt(0, 1, 1, W, H, self.buf, 1, 1) end
end

return U
