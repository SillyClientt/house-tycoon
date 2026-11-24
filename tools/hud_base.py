"""Builds StarterGui/HUD.rbxmx (Roblox XML model) for the housing tycoon."""
import sys
from xml.sax.saxutils import escape

# --- property value markers -------------------------------------------------
class U2:  # UDim2
    def __init__(s, xs, xo, ys, yo): s.v = (xs, xo, ys, yo)
class V2:
    def __init__(s, x, y): s.v = (x, y)
class C3:
    def __init__(s, r, g, b): s.v = (r / 255, g / 255, b / 255)
class UD:
    def __init__(s, sc, of): s.v = (sc, of)
class Tok:
    def __init__(s, n): s.v = n
class Fnt:
    def __init__(s, weight, family='FredokaOne'): s.v = (weight, family)
class CS:  # ColorSequence of (time, (r, g, b)) keypoints
    def __init__(s, *keys): s.v = keys

def prop_xml(name, v):
    if isinstance(v, bool):
        return f'<bool name="{name}">{"true" if v else "false"}</bool>'
    if isinstance(v, int):
        return f'<int name="{name}">{v}</int>'
    if isinstance(v, float):
        return f'<float name="{name}">{v}</float>'
    if isinstance(v, str):
        return f'<string name="{name}">{escape(v)}</string>'
    if isinstance(v, U2):
        xs, xo, ys, yo = v.v
        return f'<UDim2 name="{name}"><XS>{xs}</XS><XO>{xo}</XO><YS>{ys}</YS><YO>{yo}</YO></UDim2>'
    if isinstance(v, V2):
        return f'<Vector2 name="{name}"><X>{v.v[0]}</X><Y>{v.v[1]}</Y></Vector2>'
    if isinstance(v, C3):
        r, g, b = v.v
        return f'<Color3 name="{name}"><R>{r:.4f}</R><G>{g:.4f}</G><B>{b:.4f}</B></Color3>'
    if isinstance(v, UD):
        return f'<UDim name="{name}"><S>{v.v[0]}</S><O>{v.v[1]}</O></UDim>'
    if isinstance(v, Tok):
        return f'<token name="{name}">{v.v}</token>'
    if isinstance(v, Fnt):
        weight, family = v.v
        return (f'<Font name="{name}"><Family><url>rbxasset://fonts/families/{family}.json</url></Family>'
                f'<Weight>{weight}</Weight><Style>Normal</Style></Font>')
    if isinstance(v, CS):
        body = ' '.join(f'{t} {r/255:.4f} {g/255:.4f} {b/255:.4f} 0' for t, (r, g, b) in v.v)
        return f'<ColorSequence name="{name}">{body} </ColorSequence>'
    raise TypeError((name, v))

ref = [0]
def item_xml(node, depth=1):
    cls, name, props, children = node
    ref[0] += 1
    pad = '  ' * depth
    lines = [f'{pad}<Item class="{cls}" referent="RBX{ref[0]}">', f'{pad}  <Properties>',
             f'{pad}    {prop_xml("Name", name)}']
    for k, v in props.items():
        lines.append(f'{pad}    {prop_xml(k, v)}')
    lines.append(f'{pad}  </Properties>')
    for c in children:
        lines.append(item_xml(c, depth + 1))
    lines.append(f'{pad}</Item>')
    return '\n'.join(lines)

# --- enums ------------------------------------------------------------------
LEFT, RIGHT, CENTER = Tok(0), Tok(1), Tok(2)           # TextXAlignment
TOP_Y, CENTER_Y = Tok(0), Tok(1)                       # TextYAlignment
HORIZONTAL, VERTICAL = Tok(0), Tok(1)                  # FillDirection
H_CENTER, H_LEFT = Tok(0), Tok(1)                      # HorizontalAlignment
V_CENTER, V_TOP = Tok(0), Tok(1)                       # VerticalAlignment
LAYOUT_ORDER = Tok(2)                                  # SortOrder
SCROLL_X, SCROLL_Y = Tok(1), Tok(2)                    # ScrollingDirection
AUTO_X, AUTO_Y = Tok(1), Tok(2)                        # AutomaticSize
BORDER = Tok(1)                                        # ApplyStrokeMode

