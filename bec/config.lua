-- Настройки программы. Файл /etc/bec/bec.cfg (serialization-таблица) переопределяет значения по умолчанию.
local M = {}

M.DEFAULTS = {
  poll = 0.5,               -- с, период опроса машин
  settle = 0.5,             -- с, пауза после «звонка», пока партия догружается в Input
  nodeStartTimeout = 30,    -- с, ждать, пока узел возьмёт свою часть копий
  naniteTimeout = 30,       -- с, фейковый крафт нанитов
  cellMoveTimeout = 2,      -- с, перенос ячейки Transposer'ом
  pulse = 0.2,              -- с, импульс возврата ячейки челнока
  swapTicks = 60,           -- тиков, оценка паузы на смену нанитов (для выбора const/swap)
  naniteFill = false,       -- добавлять старшие тиры к количеству: только при нескольких Nanite Containment Bus
                            -- (шина держит один вид нанитов — второй не войдёт, Dual Interface застрянет)
  fieldAuto = true,         -- поднимать напряжённость поля под партию
  fieldMargin = 1.1,        -- запас напряжённости над объёмом партии
  dummy = "water",          -- фиктивный фильтр затвора (слот 1)
  logPath = "/home/bec.log",
  logMax = 256 * 1024,
  statePath = "/etc/bec/state.cfg",
}

-- read(path) → строка или nil; unserialize(строка) → таблица
function M.load(read, unserialize, path)
  local c = {}
  for k, v in pairs(M.DEFAULTS) do c[k] = v end
  local s = read and read(path or "/etc/bec/bec.cfg")
  if s and unserialize then
    local ok, t = pcall(unserialize, s)
    if ok and type(t) == "table" then
      for k, v in pairs(t) do if M.DEFAULTS[k] ~= nil then c[k] = v end end
    end
  end
  return c
end

return M
