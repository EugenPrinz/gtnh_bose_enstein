# CondensateType.java (GT5U 5.09.54.275) → condensates.json: единица, длительность и EU/t энтанглера по типам
import re, json, os
B = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(B, 'CondensateType.java')).read()
body = s[s.find('{', s.find('enum CondensateType')) + 1:s.find('public static final CondensateType[] VALUES')]
T = {'RECIPE_UHV': 1966080, 'RECIPE_UEV': 7864320, 'RECIPE_UIV': 31457280, 'RECIPE_UMV': 125829120, 'RECIPE_UXV': 503316480}
out = {}
def srcName(expr):
    # исходная (незапутанная) жидкость: Materials.X.getMolten → «Molten X», getFluid / gt++ getFluidStack → «X»
    m = re.search(r'\.(\w+)\.(getMolten|getFluid|getFluidStack)\(', expr)
    n = m.group(1)
    n = (n.replace('_', ' ').title() if len(n) > 6 else n) if n.isupper() else re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', n)
    return ('Molten ' + n) if m.group(2) == 'getMolten' else n
for m in re.finditer(r'(\w+)\(\s*"(\w+)",.*?,\s*(\d[\d_]*),\s*\(\)\s*->(.*?),\s*(\d+)\s*\*\s*SECONDS,\s*TierEU\.(\w+)\)', body, re.S):
    out[m.group(1)] = {'id': m.group(2), 'unit': int(m.group(3).replace('_', '')), 'dur': int(m.group(5)) * 20, 'eut': T[m.group(6)], 'src': srcName(m.group(4))}
json.dump(out, open(os.path.join(B, 'condensates.json'), 'w'))
print(len(out), 'типов конденсата')
