import json
import os
B=os.path.dirname(os.path.abspath(__file__))
d=json.load(open(os.path.join(B,'structs.json')))
# local frame: x right, y up (=H-1-row), z back
DIRS={'nx':(-1,0,0),'px':(1,0,0),'py':(0,1,0),'ny':(0,-1,0),'nz':(0,0,-1),'pz':(0,0,1)}
def grid(n):
    s=d[n];sl=s['slices'];H=s['H']
    G={}
    for z,S in enumerate(sl):
        for r,row in enumerate(S):
            for x,c in enumerate(row):
                if c!=' ': G[(x,H-1-r,z)]=c
    return G,s
def exposed(G,s,p):
    out=[]
    for k,(dx,dy,dz) in DIRS.items():
        x,y,z=p
        ok=True
        for i in range(1,200):
            q=(x+dx*i,y+dy*i,z+dz*i)
            if not(-1<=q[0]<=s['W'] and -1<=q[1]<=s['H'] and -1<=q[2]<=s['D']): break
            if q in G: ok=False;break
        if ok: out.append(k)
    return out
pref=['nz','px','nx','py','ny','pz']
spec={}
def pick(G,s,chars,want,prefer,avoid=set(),near=None):
    cands=[]
    for p,c in G.items():
        if c in chars and p not in avoid:
            ex=exposed(G,s,p)
            if prefer in ex: cands.append(p)
    if near: cands.sort(key=lambda p:sum((a-b)**2 for a,b in zip(p,near)))
    return cands[:want]
plan={
 'BEC_GENERATOR':[('1',['energy','inhatch'],'nz')],
 'BEC_CONTAINMENT_FIELD':[('B',['energy','detector'],'nz')],
 'BEC_ASSEMBLER':[('1',['nanite','energy','energy'],'nz')],
 'BEC_DIODE':[('B',['energy'],'nz')],
 'BEC_IO_NODE':[('B',['inbus','outbus','ctrlhatch'],'nz')],
}
for n in d:
    G,s=grid(n); L=[]
    ctl=[p for p,c in G.items() if c=='~'][0]
    for p,c in G.items():
        if c in '23~' or (c=='1' and n in('BEC_CONTAINMENT_FIELD','BEC_IO_NODE','BEC_DIODE')):
            ex=exposed(G,s,p)
            kind={'~':'ctrl'}.get(c)
            if c!='~':
                if n=='BEC_ASSEMBLER': kind='bec' if c=='2' else 'los'
                elif n=='BEC_IO_NODE': kind='los'
                elif n=='BEC_DIODE': kind='becin' if c=='1' else 'bec'
                else: kind='bec'
            face=ex[0] if ex else ('nz' if c=='~' else None)
            if c=='~' and 'nz' not in ex: face='nz'
            L.append({'p':p,'k':kind,'f':face})
    used={tuple(e['p']) for e in L}
    for ch,kinds,prefer in plan[n]:
        ps=pick(G,s,ch,len(kinds),prefer,used,near=ctl)
        for p,k in zip(ps,kinds): L.append({'p':p,'k':k,'f':prefer}); used.add(p)
    spec[n]=L
    print(n,[(e['k'],e['p'],e['f']) for e in L if e['k'] not in('los',)][:12], 'los',sum(e['k']=='los' for e in L))
json.dump(spec,open(os.path.join(B,'specials.json'),'w'))
