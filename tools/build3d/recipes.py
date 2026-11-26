# Полная выгрузка рецептов BEC (IO Node) из GT5U 5.09.54.275:
#   BECRecipes.java (прямые addBec/addBecUnsafe + циклы) и BECMetaMaterialRecipes.java (генерация по тирам).
# Маленький интерпретатор подмножества Java, которое есть в этих файлах: объявления, for, if/else, return,
# вызовы методов класса, массивы, арифметика, тернарный оператор. Вызовы GT/AE превращаются в предметы с именами.
# Выход: recipes_all.json — [{name, out, outItem, items:[{n,c}], cond:{тип: L}, tiers, dur, eut, tier}]
import re, json, os, sys

B = os.path.dirname(os.path.abspath(__file__))
CT = json.load(open(os.path.join(B, 'condensates.json')))
EU = {'RECIPE_UEV': 7864320, 'RECIPE_UIV': 31457280, 'RECIPE_UMV': 125829120, 'RECIPE_UXV': 503316480}
NANITE = {'Carbon': 1, 'Glowstone': 1, 'Silver': 2, 'Neutronium': 2, 'Gold': 3, 'Transcendent': 4, 'SixPhasedCopper': 5,
          'WhiteDwarf': 6, 'BlackDwarf': 7, 'Universium': 8, 'Eternity': 9, 'MagMatter': 10}
CONST = {'INGOTS': 144, 'HALF_INGOTS': 72, 'STACKS': 64 * 144, 'SECONDS': 20, 'MINUTES': 1200, 'HOURS': 72000}
MATCLS = {'Materials', 'GGMaterial', 'MaterialsAlloy', 'MaterialsElements', 'MaterialsKevlar', 'MaterialsUEVplus'}
ITEMCLS = {'ItemList', 'CustomItemList', 'GregtechItemList'}
PREFIX_RU = {'frameGt': 'Frame Box', 'plate': 'Plate', 'plateDense': 'Dense Plate', 'plateSuperdense': 'Superdense Plate',
             'plateDouble': 'Double Plate', 'gearGt': 'Gear', 'gearGtSmall': 'Small Gear', 'cableGt04': '4x Cable',
             'cableGt01': 'Cable', 'wireGt04': '4x Wire', 'wireFine': 'Fine Wire', 'circuit': 'Circuit', 'stick': 'Rod',
             'stickLong': 'Long Rod', 'screw': 'Screw', 'bolt': 'Bolt', 'ring': 'Ring', 'foil': 'Foil', 'round': 'Round',
             'itemCasing': 'Casing', 'nanite': 'Nanites', 'spring': 'Spring', 'springSmall': 'Small Spring',
             'rotor': 'Rotor', 'lens': 'Lens', 'block': 'Block', 'ingot': 'Ingot', 'dust': 'Dust'}
METHOD_PREFIX = {'getPlate': 'plate', 'getFrameBox': 'frameGt', 'getRod': 'stick', 'getLongRod': 'stickLong',
                 'getFoil': 'foil', 'getFineWire': 'wireFine', 'getRing': 'ring', 'getScrew': 'screw', 'getBolt': 'bolt',
                 'getGear': 'gearGt', 'getSmallGear': 'gearGtSmall', 'getPlateDouble': 'plateDouble', 'getPlateDense': 'plateDense',
                 'getRotor': 'rotor', 'getGearSmall': 'gearGtSmall', 'getPlateSuperdense': 'plateSuperdense'}


def pretty(s):
    s = s.replace('_', ' ')
    s = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', s)
    s = re.sub(r'(?<=[A-Za-z])(?=\d)', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


class Item:
    def __init__(self, name, count): self.name, self.count = name, int(count)
    def __repr__(self): return f'{self.name} ×{self.count}'

class Fluid:
    def __init__(self, t, amount): self.t, self.amount = t, int(amount)

class Mat:
    def __init__(self, n): self.n = n

class Prefix:
    def __init__(self, n): self.n = n

class ItemRef:
    def __init__(self, n): self.n = n

class Cond:
    def __init__(self, n): self.n = n

class Static:  # неразрешённое квалифицированное имя (класс, мод): вызов метода по строке
    def __init__(self, path): self.path = path


def oredict(prefix, mat, n):
    p = prefix.n
    mn = mat.n.capitalize() if mat.n.isupper() and len(mat.n) > 3 else mat.n  # QUANTUM → Quantum
    mn = mn if re.match(r'^(UEV|UIV|UMV|UXV|UHV|MHDCSM)', mn) else pretty(mn)
    mn = mn[:1].upper() + mn[1:]  # tairitsu → Tairitsu (GGMaterial)
    name = f"Circuit {mn}" if p == 'circuit' else f"{mn} {PREFIX_RU.get(p, p)}"
    return Item(name, n)

# ---------- лексер ----------
TOK = re.compile(r'\s+|///[^\n]*|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\d[\d_]*(?:\.\d+)?[LlFf]?|[A-Za-z_]\w*|\+\+|--|==|!=|<=|>=|&&|\|\||[{}()\[\];,.=+\-*/%<>?:!@]', re.S)

def lex(src):
    out = []
    for m in TOK.finditer(src):
        t = m.group(0)
        if t.isspace() or t.startswith('//') or t.startswith('/*'): continue
        out.append(t)
    return out

# ---------- разбор выражений ----------
class P:
    def __init__(self, toks, i=0): self.t, self.i = toks, i
    def peek(self, k=0): return self.t[self.i + k] if self.i + k < len(self.t) else None
    def next(self): v = self.t[self.i]; self.i += 1; return v
    def eat(self, v):
        if self.peek() != v: raise SyntaxError(f'ожидалось {v}, есть {self.peek()} @ {" ".join(self.t[max(0,self.i-8):self.i+8])}')
        self.i += 1

    def expr(self):
        c = self.orr()
        if self.peek() == '?':
            self.next(); a = self.expr(); self.eat(':'); b = self.expr()
            return ('?', c, a, b)
        return c
    def orr(self):
        a = self.andd()
        while self.peek() == '||': self.next(); a = ('||', a, self.andd())
        return a
    def andd(self):
        a = self.eq()
        while self.peek() == '&&': self.next(); a = ('&&', a, self.eq())
        return a
    def eq(self):
        a = self.rel()
        while self.peek() in ('==', '!='): o = self.next(); a = (o, a, self.rel())
        return a
    def rel(self):
        a = self.add()
        while self.peek() in ('<', '>', '<=', '>=') : o = self.next(); a = (o, a, self.add())
        return a
    def add(self):
        a = self.mul()
        while self.peek() in ('+', '-'): o = self.next(); a = (o, a, self.mul())
        return a
    def mul(self):
        a = self.unary()
        while self.peek() in ('*', '/', '%'): o = self.next(); a = (o, a, self.unary())
        return a
    def unary(self):
        if self.peek() == '-': self.next(); return ('neg', self.unary())
        if self.peek() == '!': self.next(); return ('not', self.unary())
        return self.postfix()
    def postfix(self):
        a = self.primary()
        while True:
            if self.peek() == '.':
                self.next(); name = self.next()
                if self.peek() == '(':
                    a = ('call', a, name, self.args())
                else:
                    a = ('attr', a, name)
            elif self.peek() == '[':
                self.next(); i = self.expr(); self.eat(']'); a = ('idx', a, i)
            else:
                return a
    def args(self):
        self.eat('('); r = []
        while self.peek() != ')':
            r.append(self.expr())
            if self.peek() == ',': self.next()
        self.eat(')'); return r
    def arr(self):
        self.eat('{'); r = []
        while self.peek() != '}':
            r.append(self.expr())
            if self.peek() == ',': self.next()
        self.eat('}'); return ('arr', r)
    def primary(self):
        t = self.peek()
        if t == '(':
            self.next(); e = self.expr(); self.eat(')'); return e
        if t == '{': return self.arr()
        if t == 'new':
            self.next(); typ = self.next()
            while self.peek() == '.': self.next(); typ = self.next()
            if self.peek() == '(': return ('new', typ, self.args())
            if self.peek() == '[' and self.peek(1) != ']':
                self.next(); n = self.expr(); self.eat(']'); return ('newarr', n)
            while self.peek() == '[': self.next(); self.eat(']')
            return self.arr()
        if t.startswith('"'): self.next(); return ('lit', t[1:-1])
        if t[0].isdigit():
            self.next(); v = t.rstrip('LlFf').replace('_', '')
            return ('lit', float(v) if '.' in v else int(v))
        if t in ('true', 'false'): self.next(); return ('lit', t == 'true')
        if t == 'null': self.next(); return ('lit', None)
        self.next()
        if self.peek() == '(': return ('fcall', t, self.args())
        return ('name', t)

# ---------- разбор операторов ----------
TYPES_SKIP = {'final', 'static', 'private', 'public', 'protected'}

def is_decl(p):
    # Type[]* name (= | ;)   — тип: идентификатор(.идентификатор)* <...>? []*
    j = p.i
    t = p.t
    while j < len(t) and t[j] in TYPES_SKIP: j += 1
    if j >= len(t) or not re.match(r'[A-Za-z_]', t[j]): return False
    j += 1
    while j + 1 < len(t) and t[j] == '.' and re.match(r'[A-Za-z_]', t[j + 1]): j += 2
    while j + 1 < len(t) and t[j] == '[' and t[j + 1] == ']': j += 2
    return j + 1 < len(t) and re.match(r'[A-Za-z_]', t[j]) and t[j + 1] in ('=', ';')

def stmts(p, end='}'):
    r = []
    while p.peek() not in (end, None): r.append(stmt(p))
    return r

def block(p):
    if p.peek() == '{':
        p.next(); b = stmts(p); p.eat('}'); return b
    return [stmt(p)]

def stmt(p):
    t = p.peek()
    if t == 'for':
        p.next(); p.eat('('); p.next(); var = p.next(); p.eat('='); a = p.expr(); p.eat(';')
        p.expr_save = None; cond = p.expr(); p.eat(';'); p.next(); p.next(); p.eat(')')
        return ('for', var, a, cond, block(p))
    if t == 'if':
        p.next(); p.eat('('); c = p.expr(); p.eat(')'); a = block(p); b = []
        if p.peek() == 'else': p.next(); b = block(p)
        return ('if', c, a, b)
    if t == 'return':
        p.next(); e = None if p.peek() == ';' else p.expr(); p.eat(';'); return ('ret', e)
    if t == 'throw':
        while p.next() != ';': pass
        return ('nop',)
    if is_decl(p):
        while p.peek() in TYPES_SKIP: p.next()
        p.next()
        while p.peek() == '.': p.next(); p.next()
        while p.peek() == '[': p.next(); p.eat(']')
        name = p.next()
        if p.peek() == ';': p.next(); return ('decl', name, None)
        p.eat('='); e = p.expr(); p.eat(';'); return ('decl', name, e)
    # присваивание или вызов
    j = p.i
    if re.match(r'[A-Za-z_]', t) and p.peek(1) == '=':
        name = p.next(); p.eat('='); e = p.expr(); p.eat(';'); return ('set', name, e)
    e = p.expr()
    if p.peek() == '=':
        p.next(); v = p.expr(); p.eat(';'); return ('setidx', e, v)
    p.eat(';'); return ('expr', e)

# ---------- класс ----------
def parse_class(src):
    toks = lex(src)
    i = toks.index('class'); i = toks.index('{', i) + 1
    p = P(toks, i)
    fields, methods = [], {}
    while p.peek() != '}':
        if p.peek() == '@': p.next(); p.next(); continue
        while p.peek() in TYPES_SKIP: p.next()
        # тип
        p.next()
        while p.peek() == '.': p.next(); p.next()
        if p.peek() == '<':
            d = 0
            while True:
                x = p.next(); d += (x == '<') - (x == '>')
                if d == 0: break
        while p.peek() == '[': p.next(); p.eat(']')
        name = p.next()
        if p.peek() == '(':
            p.next(); params = []
            while p.peek() != ')':
                k = p.i
                while p.peek() not in (',', ')'): p.next()
                params.append(p.t[p.i - 1])
                if p.peek() == ',': p.next()
            p.eat(')')
            p.eat('{'); start = p.i
            try:
                body = stmts(p); p.eat('}')
            except SyntaxError:  # тело вне подмножества (instanceof и т.п.) — такие методы заменены нативными
                p.i, d, body = start, 1, None
                while d:
                    x = p.next(); d += (x == '{') - (x == '}')
            methods[name] = (params, body)
        else:
            if p.peek() == '=':
                p.next(); fields.append((name, p.expr()))
            p.eat(';')
    return fields, methods

# ---------- интерпретатор ----------
class Ret(Exception):
    def __init__(self, v): self.v = v

class Interp:
    def __init__(self, src, native):
        self.fields, self.methods = parse_class(src)
        self.native = native
        self.g = {}
        for n, e in self.fields: self.g[n] = self.ev(e, {})
        self.recipes = []

    def run(self, name, args=(), env=None):
        if name in self.native: return self.native[name](self, *args)
        params, body = self.methods[name]
        if body is None: raise ValueError(f'метод {name} не разобран и не заменён нативным')
        loc = dict(zip(params, args))
        try:
            self.exec(body, loc)
        except Ret as r:
            return r.v
        return None

    def exec(self, body, env):
        for s in body:
            k = s[0]
            if k == 'decl': env[s[1]] = self.ev(s[2], env) if s[2] is not None else None
            elif k == 'set': env[s[1]] = self.ev(s[2], env)
            elif k == 'expr': self.ev(s[1], env)
            elif k == 'setidx': self.ev(s[1][1], env)[self.ev(s[1][2], env)] = self.ev(s[2], env)
            elif k == 'ret': raise Ret(self.ev(s[1], env) if s[1] is not None else None)
            elif k == 'if': self.exec(s[2] if self.ev(s[1], env) else s[3], env)
            elif k == 'for':
                env[s[1]] = self.ev(s[2], env)
                while self.ev(s[3], env):
                    self.exec(s[4], env); env[s[1]] += 1

    def lookup(self, n, env):
        if n in env: return env[n]
        if n in self.g: return self.g[n]
        if n in CONST: return CONST[n]
        return Static(n)

    def ev(self, e, env):
        k = e[0]
        if k == 'lit': return e[1]
        if k == 'name': return self.lookup(e[1], env)
        if k == 'arr': return [self.ev(x, env) for x in e[1]]
        if k == 'idx':
            base = self.ev(e[1], env)
            if isinstance(base, Static): return base  # ItemRegistry.bw_glasses[0] — блок по имени массива
            return base[self.ev(e[2], env)]
        if k == 'neg': return -self.ev(e[1], env)
        if k == 'not': return not self.ev(e[1], env)
        if k == '?': return self.ev(e[2], env) if self.ev(e[1], env) else self.ev(e[3], env)
        if k in ('+', '-', '*', '/', '%', '==', '!=', '<', '>', '<=', '>=', '&&', '||'):
            a, b = self.ev(e[1], env), self.ev(e[2], env)
            return {'+': lambda: a + b, '-': lambda: a - b, '*': lambda: a * b, '/': lambda: a // b if isinstance(a, int) and isinstance(b, int) else a / b,
                    '%': lambda: a % b, '==': lambda: a == b, '!=': lambda: a != b, '<': lambda: a < b, '>': lambda: a > b,
                    '<=': lambda: a <= b, '>=': lambda: a >= b, '&&': lambda: a and b, '||': lambda: a or b}[k]()
        if k == 'attr':
            base = self.ev(e[1], env)
            return self.attr(base, e[2])
        if k == 'newarr': return [None] * self.ev(e[1], env)
        if k == 'new':
            args = [self.ev(x, env) for x in e[2]]
            if e[1] == 'ItemStack':
                src = args[0]
                nm = src.path.split('.')[0] if isinstance(src, Static) else getattr(src, 'n', str(src))
                return Item(pretty(re.sub(r'^Block', '', nm)) + (f' (meta {args[2]})' if len(args) > 2 and args[2] else ''), args[1] if len(args) > 1 else 1)
            raise ValueError(f'new {e[1]}')
        if k == 'fcall':
            return self.run(e[1], [self.ev(a, env) for a in e[2]])
        if k == 'call':
            base = self.ev(e[1], env)
            return self.call(base, e[2], [self.ev(a, env) for a in e[3]])
        raise ValueError(e)

    def attr(self, base, name):
        if isinstance(base, Static):
            root = base.path.split('.')[0]
            if root in MATCLS: return Mat(name)
            if root == 'OrePrefixes': return Prefix(name)
            if root == 'TierEU': return EU[name]
            if root == 'CondensateType': return Cond(name)
            if root == 'NaniteTier': return NANITE[name]
            if root in ITEMCLS: return ItemRef(name)
            if name == 'ID': return root
            return Static(base.path + '.' + name)
        if isinstance(base, Mat): return Mat(name)  # MaterialsElements.STANDALONE.HYPOGEN
        if isinstance(base, list) and name == 'length': return len(base)
        raise ValueError(f'attr {name} of {base}')

    def call(self, base, m, a):
        if isinstance(base, ItemRef) and m == 'get': return Item(pretty(base.n), a[0])
        if isinstance(base, Mat):
            if m == 'get': return oredict(a[0], base, a[1])  # Werkstoff.get(prefix, n)
            if m in METHOD_PREFIX: return oredict(Prefix(METHOD_PREFIX[m]), base, a[0])
        if m == 'getStackForm':  # Material.getStackForm(prefix, n) / Werkstoff
            if isinstance(base, Mat): return oredict(a[0], base, a[1])
        if isinstance(base, Cond):
            if m == 'getEntangled': return Fluid(base.n, a[0])
            if m == 'getUnit': return CT[base.n]['unit']
        if isinstance(base, Static):
            path = base.path + '.' + m
            if m == 'isModLoaded': return True
            if path == 'GTOreDictUnificator.get' and isinstance(a[0], str):  # по имени словаря: "plateMetastableOganesson"
                mm = re.match(r'([a-z]+)(\w+)', a[0]); return oredict(Prefix(mm.group(1)), Mat(mm.group(2)), a[1] if len(a) > 1 else 1)
            if path == 'GTOreDictUnificator.get': return oredict(a[0], a[1], a[2] if len(a) > 2 else 1)
            if path == 'GTModHandler.getModItem': return modItem(*a)
            if path == 'GTUtility.copyAmountUnsafe': return Item(a[1].name, a[0])
            if m == 'get' and len(a) == 2 and isinstance(a[0], Prefix):  # Werkstoff (WerkstoffLoader.X).get(prefix, n)
                return oredict(a[0], Mat(base.path.split('.')[-1]), a[1])
            if m in ('get', 'getStackForm') and a and isinstance(a[0], int):  # ItemRefer.X.get(n), TileEntities.x.getStackForm(n)
                return Item(pretty(base.path.split('.')[-1]), a[0])
        raise ValueError(f'call {m} on {getattr(base, "path", base)}')


def modItem(mod, name, n, meta=None):
    s = pretty(name.split('.')[-1])
    return Item(f'{s}' + (f' (meta {meta})' if meta not in (None, 0) else ''), n)


def tiername(eut):
    return {v: k[7:] for k, v in EU.items()}[eut]


def pack(out, items, tiers, cond, dur, eut, name=None):
    return {'name': name or out.name, 'out': out.count, 'outItem': out.name,
            'items': [{'n': x.name, 'c': x.count} for x in items],
            'cond': cond, 'tiers': tiers, 'dur': int(dur), 'eut': eut, 'tier': tiername(eut)}


def run_bec():
    src = open(os.path.join(B, 'BECRecipes.java'), encoding='utf-8').read()
    # имя рецепта — комментарий над вызовом addBec (как в выгрузке v1), иначе — имя выхода
    names = {}
    for m in re.finditer(r'//\s*([^\n]+)\n\s*addBec(?:Unsafe)?\(\s*(?:new ItemStack\(\s*Block)?([\w.]+(?:\.get\w*\([^)]*\))?)', src):
        names.setdefault(re.sub(r'\.(get\w*|INSTANCE)(\(.*)?$', '', m.group(2)).split('.')[-1], m.group(1).strip())
    res = []
    def addBec(I, out, items, tiers, fluids, dur, eut):
        key = re.sub(r' ', '', out.name)
        nm = None
        for k, v in names.items():
            if k.replace('_', '') == key: nm = v
        cond = {}
        for f in fluids: cond[f.t] = cond.get(f.t, 0) + f.amount
        res.append(pack(out, items, tiers, cond, dur, eut, nm))
    native = {'addBec': addBec, 'addBecUnsafe': addBec, 'getModItem': lambda I, *a: modItem(*a),
              # TIER_TO_NANITE[k - 1 + shift] — тир k + shift
              'nanites': lambda I, *t: list(t), 'nanitesShifted': lambda I, sh, *t: [x + sh for x in t]}
    I = Interp(src, native)
    I.run('run')
    I.run('runLateRecipes')  # Shielding Casing — регистрируется поздно, отдельным вызовом GT
    return res


def run_meta():
    src = open(os.path.join(B, 'BECMetaMaterialRecipes.java'), encoding='utf-8').read()
    res = []
    def addBec(I, out, items, tiers, conds, ingots, dur, eut):
        cond = {c.n: ingots[i] * CT[c.n]['unit'] for i, c in enumerate(conds)}
        res.append(pack(out, items, tiers, cond, dur, eut))
    part = lambda pre: (lambda I, mat, n: oredict(Prefix(pre), mat, n))
    native = {'addBec': addBec, 'platePart': part('plate'), 'foilPart': part('foil'), 'fineWirePart': part('wireFine'),
              'ringPart': part('ring'), 'rodPart': part('stick'), 'longRodPart': part('stickLong')}
    I = Interp(src, native)
    I.run('run')
    return res


def main():
    bec, meta = run_bec(), run_meta()
    allr = bec + meta
    order = {'UEV': 0, 'UIV': 1, 'UMV': 2, 'UXV': 3}
    allr.sort(key=lambda x: (max(x['tiers']), order[x['tier']], x['dur'], x['name']))
    json.dump(allr, open(os.path.join(B, 'recipes_all.json'), 'w'), ensure_ascii=False, indent=0)
    print(f'{len(allr)} рецептов (BECRecipes {len(bec)}, Meta Material {len(meta)})')


if __name__ == '__main__':
    main()
