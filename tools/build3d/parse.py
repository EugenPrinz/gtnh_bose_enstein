import re, json, collections
s=open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'BECStructureDefinitions.java')).read()
out={}
for m in re.finditer(r'public static final String\[\]\[\] (\w+) = (\{\{.*?\}\});', s, re.S):
    name=m.group(1); body=m.group(2)
    slices=[]
    for sm in re.finditer(r'\{([^{}]*)\}', body):
        rows=re.findall(r'"([^"]*)"', sm.group(1))
        slices.append(rows)
    W=max(len(r) for sl in slices for r in sl); H=max(len(sl) for sl in slices); D=len(slices)
    cnt=collections.Counter(c for sl in slices for r in sl for c in r if c!=' ')
    ctl=[(x,y,z) for z,sl in enumerate(slices) for y,r in enumerate(sl) for x,c in enumerate(r) if c=='~']
    out[name]={'slices':slices,'W':W,'H':H,'D':D,'ctl':ctl[0]}
    print(name,'W',W,'H',H,'D',D,'ctl',ctl,dict(sorted(cnt.items())), 'total',sum(cnt.values()))
json.dump(out,open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'structs.json'),'w'))
