# condensates.json + recipes_all.json → bec/model/data.lua (таблицы для модели на Lua)
import json, os
B = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(B, '..', '..', 'bec', 'model', 'data.lua')
ct = json.load(open(os.path.join(B, 'condensates.json')))
rs = json.load(open(os.path.join(B, 'recipes_all.json')))

def lstr(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

L = ['-- Сгенерировано tools/build3d/luadata.py из GT5U 5.09.54.275. Не править руками.',
     'local M = {}', '',
     '-- энтанглер: вход unit L исходной жидкости → unit L конденсата за параллель, dur тиков, eut EU/t',
     'M.condensates = {']
for k, v in ct.items():
    L.append(f'  {k} = {{id = {lstr(v["id"])}, unit = {v["unit"]}, dur = {v["dur"]}, eut = {v["eut"]}}},')
L += ['}', '', '-- рецепты IO Node: tiers — тиры нанитов по шагам (1..10), cond — L конденсата на 1 параллель,',
      '-- items — предметные входы {имя, количество} на 1 параллель, out/outItem — выход',
      'M.recipes = {']
for r in rs:
    cond = ', '.join(f'{k} = {v}' for k, v in r['cond'].items())
    tiers = ', '.join(str(t) for t in r['tiers'])
    items = ', '.join(f'{{{lstr(i["n"])}, {i["c"]}}}' for i in r.get('items', []))
    L.append(f'  {{name = {lstr(r["name"])}, tiers = {{{tiers}}}, cond = {{{cond}}}, dur = {r["dur"]}, eut = {r["eut"]}, tier = {lstr(r["tier"])}, out = {r["out"]},')
    L.append(f'    outItem = {lstr(r.get("outItem", r["name"]))}, items = {{{items}}}}},')
L += ['}', '', 'return M', '']
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8').write('\n'.join(L))
print(os.path.normpath(OUT), len(ct), 'конденсатов,', len(rs), 'рецептов')
