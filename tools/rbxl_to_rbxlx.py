"""Convert a binary .rbxl to .rbxlx, swapping in a Rojo-style project.

usage: rbxl_to_rbxlx.py <in.rbxl> <project dir> <out.rbxlx>
"""
import struct, sys, os, base64, math, re, json
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(__file__))
from rbxl_dump import read_chunks

# ---------------------------------------------------------------- helpers
def zz(v):
    return (v >> 1) ^ -(v & 1)

def il_u32(b, off, n):
    return [(b[off+i] << 24) | (b[off+n+i] << 16) | (b[off+2*n+i] << 8) | b[off+3*n+i] for i in range(n)]

def il_i32(b, off, n):
    return [zz(v) for v in il_u32(b, off, n)]

def rfloat(u):
    u = ((u >> 1) | ((u & 1) << 31)) & 0xffffffff
    return struct.unpack('>f', struct.pack('>I', u))[0]

def il_f32(b, off, n):
    return [rfloat(u) for u in il_u32(b, off, n)]

def il_i64(b, off, n):
    out = []
    for i in range(n):
        v = 0
        for k in range(8):
            v = (v << 8) | b[off + k*n + i]
        out.append((v >> 1) ^ -(v & 1))
    return out

ROT_IDS = {
    0x02: (1,0,0, 0,1,0, 0,0,1), 0x03: (1,0,0, 0,0,-1, 0,1,0), 0x05: (1,0,0, 0,-1,0, 0,0,-1),
    0x06: (1,0,0, 0,0,1, 0,-1,0), 0x07: (0,1,0, 1,0,0, 0,0,-1), 0x09: (0,0,1, 1,0,0, 0,1,0),
    0x0a: (0,-1,0, 1,0,0, 0,0,1), 0x0c: (0,0,-1, 1,0,0, 0,-1,0), 0x0d: (0,1,0, 0,0,1, 1,0,0),
    0x0e: (0,0,-1, 0,1,0, 1,0,0), 0x10: (0,-1,0, 0,0,-1, 1,0,0), 0x11: (0,0,1, 0,-1,0, 1,0,0),
    0x14: (-1,0,0, 0,1,0, 0,0,-1), 0x15: (-1,0,0, 0,0,1, 0,1,0), 0x17: (-1,0,0, 0,-1,0, 0,0,1),
    0x18: (-1,0,0, 0,0,-1, 0,-1,0), 0x19: (0,1,0, -1,0,0, 0,0,1), 0x1b: (0,0,-1, -1,0,0, 0,1,0),
    0x1c: (0,-1,0, -1,0,0, 0,0,-1), 0x1e: (0,0,1, -1,0,0, 0,-1,0), 0x1f: (0,1,0, 0,0,-1, -1,0,0),
    0x20: (0,0,1, 0,1,0, -1,0,0), 0x22: (0,-1,0, 0,0,1, -1,0,0), 0x23: (0,0,-1, 0,-1,0, -1,0,0),
}

def read_cframes(b, off, n):
    rots = []
    for _ in range(n):
        rid = b[off]; off += 1
        if rid == 0:
            rots.append(struct.unpack_from('<9f', b, off)); off += 36
        else:
            rots.append(ROT_IDS[rid])
    xs = il_f32(b, off, n); ys = il_f32(b, off+4*n, n); zs = il_f32(b, off+8*n, n)
    off += 12*n
    return [(xs[i], ys[i], zs[i]) + tuple(rots[i]) for i in range(n)], off

def fmt(v):
    if isinstance(v, float):
        if math.isnan(v): return 'NAN'
        if math.isinf(v): return 'INF' if v > 0 else '-INF'
        return '%.9g' % v
    return str(v)

# ---------------------------------------------------------------- decode
BINARY_STRINGS = {'AttributesSerialize', 'Tags', 'SmoothGrid', 'PhysicsGrid', 'MaterialColors',
                  'CollisionGroupData', 'PhysicalConfigData', 'ChildData', 'MeshData'}

LEGACY_CONTENT = {
    'Decal.TextureContent': 'Texture', 'Texture.TextureContent': 'Texture',
    'Sky.SkyboxBackContent': 'SkyboxBk', 'Sky.SkyboxDownContent': 'SkyboxDn',
    'Sky.SkyboxFrontContent': 'SkyboxFt', 'Sky.SkyboxLeftContent': 'SkyboxLf',
    'Sky.SkyboxRightContent': 'SkyboxRt', 'Sky.SkyboxUpContent': 'SkyboxUp',
    'Sky.SunTextureContent': 'SunTextureId', 'Sky.MoonTextureContent': 'MoonTextureId',
    'ImageLabel.ImageContent': 'Image', 'ImageButton.ImageContent': 'Image',
    'Sound.AudioContent': 'SoundId',
}

def decode_place(path):
    data = open(path, 'rb').read()
    classes = {}; inst_class = {}; parents = {}; props = {}; order = []
    sstr = []
    for name, b in read_chunks(data):
        if name == 'SSTR':
            _, count = struct.unpack_from('<II', b, 0); off = 8
            for _ in range(count):
                off += 16
                ln, = struct.unpack_from('<I', b, off); off += 4
                sstr.append(b[off:off+ln]); off += ln
        elif name == 'INST':
            cid, nl = struct.unpack_from('<II', b, 0); cname = b[8:8+nl].decode(); off = 9 + nl
            cnt, = struct.unpack_from('<I', b, off); off += 4
            acc = 0; ids = []
            for r in il_i32(b, off, cnt):
                acc += r; ids.append(acc)
            classes[cid] = (cname, ids)
            for r in ids:
                inst_class[r] = cname; props[r] = []; order.append(r)
        elif name == 'PROP':
            cid, pl = struct.unpack_from('<II', b, 0); pn = b[8:8+pl].decode(); t = b[8+pl]; off = 9 + pl
            cname, ids = classes[cid]; n = len(ids)
            vals = decode_column(t, b, off, n, sstr, f'{cname}.{pn}')
            if vals is None:
                continue
            xml_type, values = vals
            for r, v in zip(ids, values):
                if v is not None:
                    name_out = pn
                    if xml_type == 'Content' and f'{cname}.{pn}' in LEGACY_CONTENT:
                        name_out = LEGACY_CONTENT[f'{cname}.{pn}']
                    elif xml_type == 'Content':
                        continue
                    props[r].append((xml_type, name_out, v))
        elif name == 'PRNT':
            cnt, = struct.unpack_from('<I', b, 1)
            acc = 0; ch = []
            for r in il_i32(b, 5, cnt): acc += r; ch.append(acc)
            acc = 0; pa = []
            for r in il_i32(b, 5 + 4*cnt, cnt): acc += r; pa.append(acc)
            parents.update(zip(ch, pa))
    return inst_class, parents, props, order

def decode_column(t, b, off, n, sstr, fullname):
    pn = fullname.split('.')[-1]
    if t == 0x01:
        out = []
        for _ in range(n):
            ln, = struct.unpack_from('<I', b, off); off += 4
            out.append(b[off:off+ln]); off += ln
        if pn in ('Source',):
            return 'ProtectedString', [v.decode('utf-8', 'replace') for v in out]
        binary = pn in BINARY_STRINGS
        res = []
        for v in out:
            if binary:
                res.append(('bin', v))
            else:
                try:
                    s = v.decode('utf-8')
                    if re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', s):
                        res.append(('bin', v))
                    else:
                        res.append(('str', s))
                except UnicodeDecodeError:
                    res.append(('bin', v))
        return 'StringOrBinary', res
    if t == 0x02:
        return 'bool', [b[off+i] != 0 for i in range(n)]
    if t == 0x03:
        return 'int', il_i32(b, off, n)
    if t == 0x04:
        return 'float', il_f32(b, off, n)
    if t == 0x05:
        return 'double', [struct.unpack_from('<d', b, off + 8*i)[0] for i in range(n)]
    if t == 0x06:
        s = il_f32(b, off, n); o = il_i32(b, off + 4*n, n)
        return 'UDim', list(zip(s, o))
    if t == 0x07:
        xs = il_f32(b, off, n); ys = il_f32(b, off+4*n, n); xo = il_i32(b, off+8*n, n); yo = il_i32(b, off+12*n, n)
        return 'UDim2', list(zip(xs, xo, ys, yo))
    if t == 0x0B:
        return 'BrickColor', il_u32(b, off, n)
    if t == 0x0C:
        return 'Color3', list(zip(il_f32(b, off, n), il_f32(b, off+4*n, n), il_f32(b, off+8*n, n)))
    if t == 0x0D:
        return 'Vector2', list(zip(il_f32(b, off, n), il_f32(b, off+4*n, n)))
    if t == 0x0E:
        return 'Vector3', list(zip(il_f32(b, off, n), il_f32(b, off+4*n, n), il_f32(b, off+8*n, n)))
    if t == 0x10:
        cfs, _ = read_cframes(b, off, n)
        return 'CoordinateFrame', cfs
    if t == 0x12:
        return 'token', il_u32(b, off, n)
    if t == 0x13:
        acc = 0; out = []
        for r in il_i32(b, off, n):
            acc += r; out.append(acc)
        return 'Ref', out
    if t == 0x15:
        out = []
        for _ in range(n):
            c, = struct.unpack_from('<I', b, off); off += 4
            ks = [struct.unpack_from('<3f', b, off + 12*k) for k in range(c)]; off += 12*c
            out.append(ks)
        return 'NumberSequence', out
    if t == 0x16:
        out = []
        for _ in range(n):
            c, = struct.unpack_from('<I', b, off); off += 4
            ks = [struct.unpack_from('<5f', b, off + 20*k) for k in range(c)]; off += 20*c
            out.append(ks)
        return 'ColorSequence', out
    if t == 0x17:
        return 'NumberRange', [struct.unpack_from('<2f', b, off + 8*i) for i in range(n)]
    if t == 0x18:
        a = il_f32(b, off, n); c = il_f32(b, off+4*n, n); d = il_f32(b, off+8*n, n); e = il_f32(b, off+12*n, n)
        return 'Rect2D', list(zip(a, c, d, e))
    if t == 0x19:
        out = []
        for _ in range(n):
            flag = b[off]; off += 1
            if flag & 1:
                vals = struct.unpack_from('<5f', b, off); off += 20
                if flag & 2:
                    off += 4
                out.append(vals)
            else:
                out.append(False)
        return 'PhysicalProperties', out
    if t == 0x1A:
        return 'Color3uint8', [(b[off+i], b[off+n+i], b[off+2*n+i]) for i in range(n)]
    if t == 0x1B:
        return 'int64', il_i64(b, off, n)
    if t == 0x1C:
        if pn != 'Tags':
            return None
        idx = il_u32(b, off, n)
        return 'StringOrBinary', [('bin', sstr[i]) if i < len(sstr) and sstr[i] else None for i in idx]
    if t == 0x1E:
        assert b[off] == 0x10
        cfs, off2 = read_cframes(b, off + 1, n)
        assert b[off2] == 0x02
        present = [b[off2 + 1 + i] != 0 for i in range(n)]
        return 'OptionalCoordinateFrame', [cf if p else None for cf, p in zip(cfs, present)]
    if t == 0x20:
        out = []
        for _ in range(n):
            ln, = struct.unpack_from('<I', b, off); off += 4
            fam = b[off:off+ln].decode(); off += ln
            weight, = struct.unpack_from('<H', b, off); off += 2
            style = b[off]; off += 1
            ln, = struct.unpack_from('<I', b, off); off += 4
            cached = b[off:off+ln].decode(); off += ln
            out.append((fam, weight, 'Italic' if style == 1 else 'Normal', cached))
        return 'Font', out
    if t == 0x22:
        kinds = il_i32(b, off, n); off += 4*n
        cnt, = struct.unpack_from('<I', b, off); off += 4
        uris = []
        for _ in range(cnt):
            ln, = struct.unpack_from('<I', b, off); off += 4
            uris.append(b[off:off+ln].decode()); off += ln
        out = []; k = 0
        for kind in kinds:
            if kind == 1 and k < len(uris):
                out.append(uris[k]); k += 1
            else:
                out.append(None)
        return 'Content', out
    # UniqueId, SecurityCapabilities, ContentMap and anything else: let Studio use defaults
    return None

# ---------------------------------------------------------------- xml out
def prop_xml(xml_type, name, v):
    n = escape(name, {'"': '&quot;'})
    if xml_type == 'StringOrBinary':
        kind, val = v
        if kind == 'bin':
            return f'<BinaryString name="{n}">{base64.b64encode(val).decode()}</BinaryString>'
        return f'<string name="{n}">{escape(val)}</string>'
    if xml_type == 'ProtectedString':
        return f'<ProtectedString name="{n}"><![CDATA[{v.replace("]]>", "]]]]><![CDATA[>")}]]></ProtectedString>'
    if xml_type == 'bool':
        return f'<bool name="{n}">{"true" if v else "false"}</bool>'
    if xml_type in ('int', 'int64', 'token', 'BrickColor'):
        return f'<{xml_type} name="{n}">{v}</{xml_type}>'
    if xml_type in ('float', 'double'):
        return f'<{xml_type} name="{n}">{fmt(v)}</{xml_type}>'
    if xml_type == 'UDim':
        return f'<UDim name="{n}"><S>{fmt(v[0])}</S><O>{v[1]}</O></UDim>'
    if xml_type == 'UDim2':
        return f'<UDim2 name="{n}"><XS>{fmt(v[0])}</XS><XO>{v[1]}</XO><YS>{fmt(v[2])}</YS><YO>{v[3]}</YO></UDim2>'
    if xml_type == 'Color3':
        return f'<Color3 name="{n}"><R>{fmt(v[0])}</R><G>{fmt(v[1])}</G><B>{fmt(v[2])}</B></Color3>'
    if xml_type == 'Vector2':
        return f'<Vector2 name="{n}"><X>{fmt(v[0])}</X><Y>{fmt(v[1])}</Y></Vector2>'
    if xml_type == 'Vector3':
        return f'<Vector3 name="{n}"><X>{fmt(v[0])}</X><Y>{fmt(v[1])}</Y><Z>{fmt(v[2])}</Z></Vector3>'
    if xml_type in ('CoordinateFrame', 'OptionalCoordinateFrame'):
        keys = ['X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22']
        inner = ''.join(f'<{k}>{fmt(float(x))}</{k}>' for k, x in zip(keys, v))
        if xml_type == 'OptionalCoordinateFrame':
            return f'<OptionalCoordinateFrame name="{n}"><CFrame>{inner}</CFrame></OptionalCoordinateFrame>'
        return f'<CoordinateFrame name="{n}">{inner}</CoordinateFrame>'
    if xml_type == 'Ref':
        return f'<Ref name="{n}">{v}</Ref>'
    if xml_type == 'NumberSequence':
        return f'<NumberSequence name="{n}">' + ' '.join(' '.join(fmt(x) for x in k) for k in v) + ' </NumberSequence>'
    if xml_type == 'ColorSequence':
        return f'<ColorSequence name="{n}">' + ' '.join(' '.join(fmt(x) for x in k) for k in v) + ' </ColorSequence>'
    if xml_type == 'NumberRange':
        return f'<NumberRange name="{n}">{fmt(v[0])} {fmt(v[1])} </NumberRange>'
    if xml_type == 'Rect2D':
        return (f'<Rect2D name="{n}"><min><X>{fmt(v[0])}</X><Y>{fmt(v[1])}</Y></min>'
                f'<max><X>{fmt(v[2])}</X><Y>{fmt(v[3])}</Y></max></Rect2D>')
    if xml_type == 'PhysicalProperties':
        if v is False:
            return f'<PhysicalProperties name="{n}"><CustomPhysics>false</CustomPhysics></PhysicalProperties>'
        d, f, e, fw, ew = v
        return (f'<PhysicalProperties name="{n}"><CustomPhysics>true</CustomPhysics><Density>{fmt(d)}</Density>'
                f'<Friction>{fmt(f)}</Friction><Elasticity>{fmt(e)}</Elasticity>'
                f'<FrictionWeight>{fmt(fw)}</FrictionWeight><ElasticityWeight>{fmt(ew)}</ElasticityWeight></PhysicalProperties>')
    if xml_type == 'Color3uint8':
        r, g, bb = v
        return f'<Color3uint8 name="{n}">{0xFF000000 | (r << 16) | (g << 8) | bb}</Color3uint8>'
    if xml_type == 'Font':
        fam, w, style, cached = v
        extra = f'<CachedFaceId><url>{escape(cached)}</url></CachedFaceId>' if cached else ''
        return (f'<Font name="{n}"><Family><url>{escape(fam)}</url></Family><Weight>{w}</Weight>'
                f'<Style>{style}</Style>{extra}</Font>')
    if xml_type == 'Content':
        return f'<Content name="{n}"><url>{escape(v)}</url></Content>'
    raise ValueError(xml_type)

# ---------------------------------------------------------------- project -> items
new_ref = [0]
def next_ref():
    new_ref[0] += 1
    return f'NEW{new_ref[0]}'

def script_item(cls, name, source, children=''):
    return (f'<Item class="{cls}" referent="{next_ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'{prop_xml("ProtectedString", "Source", source)}</Properties>{children}</Item>')

def folder_item(name, children, cls='Folder'):
    return (f'<Item class="{cls}" referent="{next_ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string></Properties>{children}</Item>')

def path_items(path):
    """Rojo rules: dir -> Folder (or ModuleScript if init.lua), x.lua -> ModuleScript,
    x.server.lua -> Script, x.client.lua -> LocalScript, x.model.json -> its className."""
    name = os.path.basename(path)
    if os.path.isdir(path):
        kids = ''.join(path_items(os.path.join(path, c)) for c in sorted(os.listdir(path)) if c != 'init.lua')
        init = os.path.join(path, 'init.lua')
        if os.path.exists(init):
            return script_item('ModuleScript', name, open(init).read(), kids)
        return folder_item(name, kids)
    if name.endswith('.server.lua'):
        return script_item('Script', name[:-11], open(path).read())
    if name.endswith('.client.lua'):
        return script_item('LocalScript', name[:-11], open(path).read())
    if name.endswith('.lua'):
        return script_item('ModuleScript', name[:-4], open(path).read())
    if name.endswith('.model.json'):
        return folder_item(name[:-11], '', json.load(open(path))['className'])
    if name.endswith('.rbxmx'):
        xml = open(path).read()
        body = xml[xml.index('<Item'):xml.rindex('</roblox>')]
        return re.sub(r'referent="RBX(\d+)"', lambda m: f'referent="HUD{m.group(1)}"', body)
    raise ValueError(path)

# ---------------------------------------------------------------- main
def main(src, project, out):
    inst_class, parents, props, order = decode_place(src)
    children = {}
    for r in order:
        children.setdefault(parents.get(r, -1), []).append(r)

    def name_of(r):
        for t, n, v in props[r]:
            if n == 'Name':
                return v[1] if isinstance(v, tuple) else v
        return inst_class[r]

    def find(path):
        current = -1
        for part in path.split('.'):
            current = next((c for c in children.get(current, []) if name_of(c) == part), None)
            if current is None:
                return None
        return current

    removed = set()
    def remove(r):
        if r is None:
            return
        removed.add(r)
        for c in children.get(r, []):
            remove(c)

    for p in ['ReplicatedStorage.Modules', 'ReplicatedStorage.Remotes', 'ServerStorage.Modules',
              'ServerScriptService.Runtime', 'StarterPlayer.StarterPlayerScripts.Runtime', 'StarterGui.HUD']:
        remove(find(p))
    plot = find('Workspace.Plot')
    for c in children.get(plot, []):
        remove(c)

    starter_pack = find('StarterPack')
    archived = [c for c in children.get(starter_pack, [])]
    archive_ref = 'ARCHIVE'

    src_root = os.path.join(project, 'src')
    inserts = {
        find('ReplicatedStorage'): path_items(os.path.join(src_root, 'ReplicatedStorage', 'Modules'))
                                   + path_items(os.path.join(src_root, 'ReplicatedStorage', 'Remotes')),
        find('ServerStorage'): path_items(os.path.join(src_root, 'ServerStorage', 'Modules')),
        find('ServerScriptService'): path_items(os.path.join(src_root, 'ServerScriptService', 'Runtime.server.lua')),
        find('StarterPlayer.StarterPlayerScripts'): path_items(os.path.join(src_root, 'StarterPlayerScripts', 'Runtime.client.lua')),
        find('StarterGui'): path_items(os.path.join(src_root, 'StarterGui', 'HUD.rbxmx')),
    }
    assert None not in inserts, 'missing a service in the place'

    def item_xml(r, depth):
        parts = [f'<Item class="{inst_class[r]}" referent="RBX{r}"><Properties>']
        for t, n, v in props[r]:
            if t == 'Ref':
                v = 'null' if v == -1 or v in removed or v not in inst_class else f'RBX{v}'
            parts.append(prop_xml(t, n, v))
        parts.append('</Properties>')
        for c in children.get(r, []):
            if c in removed or (r == starter_pack and c in archived):
                continue
            parts.append(item_xml(c, depth + 1))
        if r in inserts:
            parts.append(inserts[r])
        if r == find('ServerStorage') and archived:
            parts.append(f'<Item class="Folder" referent="{archive_ref}"><Properties><string name="Name">Archive</string></Properties>')
            for c in archived:
                parts.append(item_xml(c, depth + 2))
            parts.append('</Item>')
        parts.append('</Item>')
        return ''.join(parts)

    body = ''.join(item_xml(r, 1) for r in children.get(-1, []) if r not in removed)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           '<Meta name="ExplicitAutoJoints">true</Meta>' + body + '</roblox>')
    open(out, 'w', encoding='utf-8').write(xml)
    print('instances kept:', len(order) - len(removed), 'removed:', len(removed), 'archived:', len(archived))

if __name__ == '__main__':
    main(*sys.argv[1:4])
