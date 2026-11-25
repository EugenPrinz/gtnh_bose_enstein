# CondensateType.java (GT5U 5.09.54.275) → condensates.json: единица, длительность и EU/t энтанглера по типам
import re, json, os
B = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(B, 'CondensateType.java')).read()
body = s[s.find('{', s.find('enum CondensateType')) + 1:s.find('public static final CondensateType[] VALUES')]
T = {'RECIPE_UHV': 1966080, 'RECIPE_UEV': 7864320, 'RECIPE_UIV': 31457280, 'RECIPE_UMV': 125829120, 'RECIPE_UXV': 503316480}
out = {}
for m in re.finditer(r'(\w+)\(\s*"(\w+)",.*?,\s*(\d[\d_]*),\s*\(\)\s*->.*?,\s*(\d+)\s*\*\s*SECONDS,\s*TierEU\.(\w+)\)', body, re.S):
    out[m.group(1)] = {'id': m.group(2), 'unit': int(m.group(3).replace('_', '')), 'dur': int(m.group(4)) * 20, 'eut': T[m.group(5)]}
json.dump(out, open(os.path.join(B, 'condensates.json'), 'w'))
print(len(out), 'типов конденсата')
