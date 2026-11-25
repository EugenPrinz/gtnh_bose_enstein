import json, base64, glob, os
B = os.path.dirname(os.path.abspath(__file__))
S = json.load(open(f'{B}/structs.json'))
structs = {n: {'W': s['W'], 'H': s['H'], 'D': s['D'], 's': s['slices']} for n, s in S.items()}
spec = json.load(open(f'{B}/specials.json'))
ct = json.load(open(f'{B}/condensates.json'))
recipes = json.load(open(f'{B}/recipes_all.json'))
tex, anim = {}, {}
for f in sorted(glob.glob(f'{B}/tex/*.png')):
    n = os.path.basename(f)[:-4]
    tex[n] = 'data:image/png;base64,' + base64.b64encode(open(f, 'rb').read()).decode()
    if os.path.exists(f + '.mcmeta'):
        anim[n] = json.load(open(f + '.mcmeta'))['animation'].get('frametime', 1)
s = open(f'{B}/template.html').read()
for k, v in [('__STRUCTS__', structs), ('__SPEC__', spec), ('__CT__', ct), ('__RECIPES__', recipes), ('__TEX__', tex), ('__ANIM__', anim)]:
    s = s.replace(k, json.dumps(v, separators=(',', ':'), ensure_ascii=False))
out = os.environ.get('OUT', '/home/claude/bec/docs/build.html')
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, 'w').write(s)
print(out, len(s) // 1024, 'KB')
