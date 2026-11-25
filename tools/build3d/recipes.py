import re, json, os
B=os.path.dirname(os.path.abspath(__file__))
s=open(os.path.join(B,'BECRecipes.java')).read()
EU={'RECIPE_UIV':31457280,'RECIPE_UMV':125829120,'RECIPE_UXV':503316480}
out=[]
for m in re.finditer(r'//\s*([^\n]+)\n\s*addBec\((.*?)\);\n', s, re.S):
    name, body = m.group(1).strip(), m.group(2)
    nm = re.search(r'nanites\(([\d,\s]+)\)', body)
    if not nm: continue
    tiers=[int(x) for x in nm.group(1).replace(' ','').split(',')]
    cond={}
    for c in re.finditer(r'CondensateType\.(\w+)\.getEntangled\(([^)]*)\)', body):
        expr=c.group(2).replace('INGOTS','144').replace('_','')
        cond[c.group(1)]=int(eval(expr))
    dm=re.search(r'(\w+|\d+)\s*\*\s*SECONDS', body) or re.search(r'(casingTime)', body)
    dur = dm.group(1)
    dur = 40000 if dur=='casingTime' else int(dur.replace('_',''))
    em=re.search(r'TierEU\.(\w+)', body)
    outm=re.search(r'^\s*([\w.]+(?:\.get\w*\([^)]*\))?)', body.strip())
    cnt=re.search(r'\.get\((\d+)\)', body.split(',')[0])
    out.append({'name':name,'tiers':tiers,'cond':cond,'dur':dur*20,'eut':EU[em.group(1)],'tier':em.group(1)[7:],'out':int(cnt.group(1)) if cnt else 1})
# BECMetaMaterialRecipes.java: Shielding (3 тира) и Sensor Array (4 тира) по правилам из Java
EU2={'UEV':7864320,'UIV':31457280,'UMV':125829120,'UXV':503316480}
for t,v in enumerate(['UIV','UMV','UXV']):
    out.append({'name':f'Meta Material Shielding {t+1}','tiers':[4+2*t,1+2*t,1+2*t,3+2*t,1+2*t],'cond':{'ChromaticGlass':[2,4,8][t]*144,'TranscendentMetal':[2,4,8][t]*144},'dur':6000,'eut':EU2[v],'tier':v,'out':1})
for t,v in enumerate(['UEV','UIV','UMV','UXV']):
    c={'ChromaticGlass':[8,12,16,24][t]*144,'Infinity':[4,6,8,12][t]*144}
    if t==0: c['TranscendentMetal']=2*144
    else: c['BoundlessCosmicSolder']=[1,2,3,4][t]*1000
    out.append({'name':f'Meta Material Sensor Array {t+1}','tiers':[4+t,1+t,2+t,1+t],'cond':c,'dur':6000,'eut':EU2[v],'tier':v,'out':1})
order={'UEV':0,'UIV':1,'UMV':2,'UXV':3}
out.sort(key=lambda x:(max(x['tiers']),order[x['tier']],x['dur']))
json.dump(out, open(os.path.join(B,'recipes_all.json'),'w'), ensure_ascii=False)
print(len(out), 'рецептов')
