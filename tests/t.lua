-- Мини-проверки для тестов
local T = {}

function T.eq(a, b, msg)
  if a ~= b then error((msg or "") .. " ожидалось " .. tostring(b) .. ", получено " .. tostring(a), 2) end
end

function T.ok(v, msg)
  if not v then error(msg or "ожидалось истинное значение", 2) end
end

function T.near(a, b, tol, msg)
  if math.abs(a - b) > tol then error((msg or "") .. " ожидалось ≈" .. b .. " ±" .. tol .. ", получено " .. a, 2) end
end

function T.list(a, b, msg)
  T.eq(#a, #b, (msg or "") .. " длина:")
  for i = 1, #b do T.eq(a[i], b[i], (msg or "") .. " [" .. i .. "]") end
end

return T
