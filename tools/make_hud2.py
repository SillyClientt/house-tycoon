"""Builds StarterGui/HUD.rbxmx - bright, cartoony style (Stage 2)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from hud_base import *  # noqa

# --- palette ----------------------------------------------------------------
INK = C3(34, 38, 66)            # outlines + dark text
CREAM = C3(255, 250, 240)       # panel background
CARD = C3(255, 255, 255)
SOFT = C3(232, 236, 246)        # inset areas
SLATE = C3(118, 132, 172)       # neutral button
BLUE = C3(66, 135, 245)
ORANGE = C3(255, 150, 50)
GREEN = C3(76, 190, 92)
PURPLE = C3(150, 92, 240)
GOLD = C3(255, 196, 40)
RED = C3(235, 84, 84)
WHITE = C3(255, 255, 255)
MUTED = C3(112, 118, 140)
MONEY = C3(44, 160, 70)

GLOSS = CS((0, (255, 255, 255)), (1, (205, 205, 215)))   # buttons: light top -> darker bottom

def corner(r=14):
    return ('UICorner', 'UICorner', {'CornerRadius': UD(0, r)}, [])

def outline(thickness=3, color=INK):
    return ('UIStroke', 'UIStroke', {'Color': color, 'Thickness': float(thickness), 'ApplyStrokeMode': BORDER}, [])

def gloss():
    return ('UIGradient', 'UIGradient', {'Color': GLOSS, 'Rotation': 90.0}, [])

def padding(p):
    return ('UIPadding', 'UIPadding', {'PaddingLeft': UD(0, p), 'PaddingRight': UD(0, p),
                                         'PaddingTop': UD(0, p), 'PaddingBottom': UD(0, p)}, [])

def list_layout(direction, pad, h=H_LEFT, v=V_TOP):
    return ('UIListLayout', 'UIListLayout', {'FillDirection': direction, 'Padding': UD(0, pad),
                                               'HorizontalAlignment': h, 'VerticalAlignment': v,
                                               'SortOrder': LAYOUT_ORDER}, [])

def frame(name, pos, size, children=(), bg=CREAM, transparent=False, extra=None, anchor=(0, 0), styled=True, radius=18):
    props = {'AnchorPoint': V2(*anchor), 'Position': pos, 'Size': size, 'BorderSizePixel': 0,
             'BackgroundColor3': bg, 'BackgroundTransparency': 1.0 if transparent else 0.0}
    props.update(extra or {})
    kids = list(children)
    if styled and not transparent:
        kids = [corner(radius), outline()] + kids
    return ('Frame', name, props, kids)

def label(name, pos, size, text, text_size=18, color=INK, align=LEFT, extra=None, anchor=(0, 0), stroke=False):
    props = {'AnchorPoint': V2(*anchor), 'Position': pos, 'Size': size, 'BackgroundTransparency': 1.0,
             'BorderSizePixel': 0, 'Text': text, 'TextSize': float(text_size), 'TextColor3': color,
             'FontFace': Fnt(400), 'TextXAlignment': align, 'TextYAlignment': CENTER_Y,
             'TextWrapped': True}
    if stroke:
        props.update({'TextStrokeTransparency': 0.0, 'TextStrokeColor3': INK})
    props.update(extra or {})
    return ('TextLabel', name, props, [])

def button(name, pos, size, text, bg=SLATE, text_size=18, order=0, extra=None, anchor=(0, 0), children=(), dark_text=False):
    props = {'AnchorPoint': V2(*anchor), 'Position': pos, 'Size': size, 'BackgroundColor3': bg,
             'BorderSizePixel': 0, 'Text': text, 'TextSize': float(text_size),
             'TextColor3': INK if dark_text else WHITE, 'FontFace': Fnt(400), 'AutoButtonColor': False,
             'LayoutOrder': order}
    if not dark_text:
        props.update({'TextStrokeTransparency': 0.0, 'TextStrokeColor3': INK})
    props.update(extra or {})
    return ('TextButton', name, props, [corner(12), outline(3), gloss()] + list(children))

def scroller(name, pos, size, direction, children):
    auto = AUTO_X if direction is SCROLL_X else AUTO_Y
    return ('ScrollingFrame', name, {'Position': pos, 'Size': size, 'BackgroundTransparency': 1.0,
                                     'BorderSizePixel': 0, 'ScrollingDirection': direction,
                                     'CanvasSize': U2(0, 0, 0, 0), 'AutomaticCanvasSize': auto,
                                     'ScrollBarThickness': 8, 'ScrollBarImageColor3': INK}, list(children))

HIDDEN = {'Visible': False}

# a coloured band across the top of a panel, with the panel title on it
def header(title, color, close=True):
    kids = [
        frame('Header', U2(0, -16, 0, -16), U2(1, 32, 0, 58), bg=color, radius=18,
              extra={'ZIndex': 0}, children=[
            frame('Fill', U2(0, 0, 1, -18), U2(1, 0, 0, 18), bg=color, styled=False, extra={'ZIndex': 0}),
        ]),
        label('Title', U2(0, 4, 0, -10), U2(1, -60, 0, 46), title, 28, WHITE, stroke=True),
    ]
    if close:
        kids.append(button('Close', U2(1, 6, 0, -8), U2(0, 40, 0, 40), 'X', RED, 22, anchor=(1, 0)))
    return kids

def panel(name, size, title, color, children, extra=None):
    props = {**HIDDEN, 'ClipsDescendants': False}
    props.update(extra or {})
    return frame(name, U2(0.5, 0, 0.5, 0), size, anchor=(0.5, 0.5), extra=props, children=[
        padding(16), *header(title, color), *children,
    ])

# --- top bar ----------------------------------------------------------------
top_bar = frame('TopBar', U2(0.5, 0, 0, 10), U2(0, 520, 0, 52), transparent=True, anchor=(0.5, 0), children=[
    list_layout(HORIZONTAL, 12, H_CENTER),
    frame('Cash', U2(0, 0, 0, 0), U2(0, 240, 0, 52), bg=GREEN, radius=26, extra={'LayoutOrder': 1}, children=[
        gloss(),
        label('Amount', U2(0, 0, 0, 0), U2(1, 0, 1, 0), '\U0001F4B5 $0', 28, WHITE, align=CENTER, stroke=True),
    ]),
    frame('Value', U2(0, 0, 0, 0), U2(0, 260, 0, 52), bg=ORANGE, radius=26, extra={'LayoutOrder': 2}, children=[
        gloss(),
        label('Amount', U2(0, 0, 0, 0), U2(1, 0, 1, 0), '\U0001F3E0 Estate $0', 24, WHITE, align=CENTER, stroke=True),
    ]),
])

# --- side buttons -----------------------------------------------------------
actions = frame('Actions', U2(0, 16, 0.5, 0), U2(0, 96, 0, 420), transparent=True, anchor=(0, 0.5), children=[
    list_layout(VERTICAL, 12),
    *[button(n, U2(0, 0, 0, 0), U2(0, 96, 0, 92), '', color, 20, o, children=[
            label('Icon', U2(0, 0, 0, 6), U2(1, 0, 0, 48), icon, 40, WHITE, align=CENTER),
            label('Label', U2(0, 0, 1, -32), U2(1, 0, 0, 26), text, 20, WHITE, align=CENTER, stroke=True),
        ])
      for o, (n, icon, text, color) in enumerate([
          ('Build', '\U0001F528', 'Build', BLUE), ('Houses', '\U0001F3E0', 'Houses', ORANGE),
          ('Land', '\U0001F5FA', 'Land', GREEN), ('Shop', '\U0001F6D2', 'Shop', PURPLE)], 1)],
])

# --- build bar --------------------------------------------------------------
tabs = [('Room', '\U0001F9F1', 'Room'), ('Walls', '\U0001F4CF', 'Walls'), ('Door', '\U0001F6AA', 'Door'),
        ('Window', '\U0001FA9F', 'Window'), ('Floors', '\U0001F7EB', 'Floors'), ('Paint', '\U0001F3A8', 'Paint'),
        ('Furniture', '\U0001F6CB', 'Furniture'), ('Edit', '✋', 'Edit'), ('Erase', '\U0001F9F9', 'Erase')]

# an icon-over-text tab button
def tab(name, icon, text, color, order):
    return button(name, U2(0, 0, 0, 0), U2(0, 80, 0, 56), '', color, 15, order, children=[
        label('Icon', U2(0, 0, 0, 2), U2(1, 0, 0, 30), icon, 26, WHITE, align=CENTER),
        label('Label', U2(0, 0, 1, -24), U2(1, 0, 0, 20), text, 15, WHITE, align=CENTER, stroke=True),
    ])

build_bar = frame('BuildBar', U2(0.5, 0, 1, -14), U2(0, 1000, 0, 232), anchor=(0.5, 1),
                  extra={**HIDDEN, 'ClipsDescendants': False}, children=[
    padding(12),
    label('Hint', U2(0, 0, 0, -70), U2(0.66, 0, 0, 52), '', 16, WHITE, stroke=True,
          extra={'TextYAlignment': Tok(2)}),
    label('Cost', U2(1, 0, 0, -46), U2(0.3, 0, 0, 30), '', 26, C3(120, 255, 140), align=RIGHT, anchor=(1, 0), stroke=True),
    frame('LevelBox', U2(1, 0, 0, -104), U2(0, 340, 0, 50), anchor=(1, 0), radius=16, children=[
        padding(6),
        list_layout(HORIZONTAL, 6, H_LEFT, V_CENTER),
        button('LevelDown', U2(0, 0, 0, 0), U2(0, 40, 0, 36), '▼', SLATE, 18, 1),
        label('LevelLabel', U2(0, 0, 0, 0), U2(0, 120, 0, 36), 'Ground Floor', 18, align=CENTER, extra={'LayoutOrder': 2}),
        button('LevelUp', U2(0, 0, 0, 0), U2(0, 40, 0, 36), '▲', SLATE, 18, 3),
        button('Lights', U2(0, 0, 0, 0), U2(0, 110, 0, 36), '\U0001F4A1 On', GOLD, 17, 4),
    ]),
    frame('Tabs', U2(0, 0, 0, 0), U2(1, 0, 0, 56), transparent=True, children=[
        list_layout(HORIZONTAL, 5),
        *[tab(n, icon, text, SLATE, o) for o, (n, icon, text) in enumerate(tabs, 1)],
        tab('Undo', '↩', 'Undo', GOLD, 10),
        tab('Close', '✔', 'Done', RED, 11),
    ]),
    frame('Options', U2(0, 0, 0, 64), U2(1, 0, 0, 32), transparent=True, children=[
        list_layout(HORIZONTAL, 6),
        button('OptionTemplate', U2(0, 0, 0, 0), U2(0, 84, 0, 32), 'Option', SLATE, 14,
               extra={**HIDDEN, 'AutomaticSize': AUTO_X},
               children=[('UIPadding', 'UIPadding', {'PaddingLeft': UD(0, 10), 'PaddingRight': UD(0, 10)}, [])]),
    ]),
    scroller('Items', U2(0, 0, 0, 104), U2(1, 0, 0, 104), SCROLL_X, [
        list_layout(HORIZONTAL, 10),
        ('UIPadding', 'UIPadding', {'PaddingLeft': UD(0, 4), 'PaddingTop': UD(0, 4)}, []),
        button('ItemTemplate', U2(0, 0, 0, 0), U2(0, 112, 0, 92), '', CARD, extra=HIDDEN, dark_text=True, children=[
            frame('Swatch', U2(0, 8, 0, 8), U2(1, -16, 0, 34), bg=WHITE, radius=10),
            label('Title', U2(0, 4, 0, 44), U2(1, -8, 0, 22), 'Item', 15, align=CENTER),
            label('Price', U2(0, 4, 0, 66), U2(1, -8, 0, 20), '$0', 16, MONEY, align=CENTER),
            label('Badge', U2(1, 8, 0, -8), U2(0, 50, 0, 22), 'R$', 14, WHITE, align=CENTER, anchor=(1, 0),
                  stroke=True, extra={'Visible': False, 'BackgroundTransparency': 0.0, 'BackgroundColor3': PURPLE}),
        ]),
    ]),
])

# --- furniture selection ----------------------------------------------------
selection = frame('Selection', U2(1, -16, 0.5, 0), U2(0, 220, 0, 240), anchor=(1, 0.5), extra={**HIDDEN, 'ClipsDescendants': False},
                  children=[
    padding(16),
    *header('Item', BLUE, close=False),
    frame('Buttons', U2(0, 0, 0, 54), U2(1, 0, 1, -54), transparent=True, children=[
        list_layout(VERTICAL, 10),
        button('Rotate', U2(0, 0, 0, 0), U2(1, 0, 0, 44), '\U0001F504 Rotate (R)', SLATE, 18, 2),
        button('Move', U2(0, 0, 0, 0), U2(1, 0, 0, 44), '✋ Move (M)', BLUE, 18, 3),
        button('Remove', U2(0, 0, 0, 0), U2(1, 0, 0, 44), '\U0001F4B0 Sell (X)', RED, 18, 4),
    ]),
])

# --- houses -----------------------------------------------------------------
houses_panel = panel('HousesPanel', U2(0, 700, 0, 560), '\U0001F3E0 Houses', ORANGE, [
    button('CollectAll', U2(1, -44, 0, -6), U2(0, 200, 0, 38), '\U0001F4B5 Collect $0', GREEN, 18, anchor=(1, 0)),
    frame('ListBox', U2(0, 0, 0, 54), U2(0, 210, 1, -54), bg=SOFT, radius=14, children=[
        padding(6),
        label('NoHouses', U2(0, 4, 0, 4), U2(1, -8, 0, 140),
              'No houses yet!\n\nUse the Room tool to build rooms with a bed and a toilet.', 15, MUTED,
              extra={'TextYAlignment': TOP_Y}),
        scroller('List', U2(0, 0, 0, 0), U2(1, 0, 1, 0), SCROLL_Y, [
            list_layout(VERTICAL, 6),
            button('HouseTemplate', U2(0, 0, 0, 0), U2(1, -10, 0, 70), '', CARD, extra=HIDDEN, dark_text=True, children=[
                label('Title', U2(0, 10, 0, 4), U2(1, -20, 0, 22), 'House 1', 18),
                label('Status', U2(0, 10, 0, 26), U2(1, -20, 0, 18), 'Building', 14, MUTED),
                label('Value', U2(0, 10, 0, 44), U2(1, -20, 0, 22), '$0', 18, MONEY),
            ]),
        ]),
    ]),
    frame('Details', U2(0, 224, 0, 54), U2(1, -224, 1, -54), transparent=True, children=[
        label('Name', U2(0, 0, 0, 0), U2(1, 0, 0, 30), 'Pick a house', 26),
        label('Status', U2(0, 0, 0, 30), U2(1, 0, 0, 20), '', 15, MUTED),
        label('Value', U2(0, 0, 0, 52), U2(1, 0, 0, 38), '', 32, MONEY),
        label('Stats', U2(0, 0, 0, 92), U2(1, 0, 0, 20), '', 15),
        label('Rooms', U2(0, 0, 0, 116), U2(1, 0, 0, 92), '', 15, extra={'RichText': True, 'TextYAlignment': TOP_Y}),
        frame('Buttons', U2(0, 0, 0, 212), U2(1, 0, 0, 44), transparent=True, children=[
            list_layout(HORIZONTAL, 8),
            button('Sell', U2(0, 0, 0, 0), U2(0, 110, 0, 44), '\U0001F4B0 Sell', GREEN, 18, 1),
            button('Rent', U2(0, 0, 0, 0), U2(0, 120, 0, 44), '\U0001F511 Rent', BLUE, 18, 2),
            button('Unlist', U2(0, 0, 0, 0), U2(0, 160, 0, 44), '❌ Off Market', RED, 16, 3),
            button('Evict', U2(0, 0, 0, 0), U2(0, 140, 0, 44), '\U0001F6AA End Lease', RED, 16, 4),
        ]),
        label('OffersTitle', U2(0, 0, 0, 264), U2(1, 0, 0, 24), '\U0001F4E8 Offers', 20),
        label('NoOffers', U2(0, 0, 0, 292), U2(1, 0, 0, 26), '', 15, MUTED),
        scroller('Offers', U2(0, 0, 0, 292), U2(1, 0, 1, -292), SCROLL_Y, [
            list_layout(VERTICAL, 8),
            frame('OfferTemplate', U2(0, 0, 0, 0), U2(1, -10, 0, 60), bg=CARD, radius=14, extra=HIDDEN, children=[
                label('Buyer', U2(0, 12, 0, 6), U2(0.45, 0, 0, 24), 'Buyer', 18),
                label('Amount', U2(0, 12, 0, 30), U2(0.45, 0, 0, 22), '$0', 18, MONEY),
                label('Timer', U2(0.45, 0, 0, 0), U2(0, 50, 1, 0), '45s', 15, MUTED, align=CENTER),
                button('Accept', U2(1, -98, 0.5, 0), U2(0, 88, 0, 40), 'Accept', GREEN, 16, anchor=(1, 0.5)),
                button('Decline', U2(1, -6, 0.5, 0), U2(0, 86, 0, 40), 'No', RED, 16, anchor=(1, 0.5)),
            ]),
        ]),
    ]),
])

# --- land -------------------------------------------------------------------
land_panel = panel('LandPanel', U2(0, 440, 0, 600), '\U0001F5FA Land', GREEN, [
    label('Hint', U2(0, 0, 0, 50), U2(1, 0, 0, 20), 'The road is at the bottom', 15, MUTED, align=CENTER),
    frame('Grid', U2(0.5, 0, 0, 76), U2(0, 320, 0, 320), anchor=(0.5, 0), transparent=True, children=[
        ('UIGridLayout', 'UIGridLayout', {'CellSize': U2(0, 74, 0, 74), 'CellPadding': U2(0, 8, 0, 8),
                                          'SortOrder': LAYOUT_ORDER}, []),
        button('ParcelTemplate', U2(0, 0, 0, 0), U2(0, 74, 0, 74), '', SLATE, 15, extra=HIDDEN),
    ]),
    label('Info', U2(0, 0, 0, 404), U2(1, 0, 0, 24), 'Pick a parcel next to your land', 16, align=CENTER),
    button('BuyCash', U2(0, 0, 0, 432), U2(0.5, -5, 0, 46), 'Buy $0', GREEN, 20),
    button('BuyRobux', U2(1, 0, 0, 432), U2(0.5, -5, 0, 46), 'Buy R$0', PURPLE, 20, anchor=(1, 0)),
    label('LevelInfo', U2(0, 0, 0, 490), U2(1, 0, 0, 22), 'Floors: 1/3', 18, align=CENTER),
    button('UnlockLevel', U2(0, 0, 0, 516), U2(1, 0, 0, 46), 'Unlock 2nd Floor', BLUE, 18),
])

# --- shop -------------------------------------------------------------------
shop_panel = panel('ShopPanel', U2(0, 560, 0, 540), '\U0001F6D2 Shop', PURPLE, [
    label('PassesTitle', U2(0, 0, 0, 50), U2(1, 0, 0, 24), '⭐ Gamepasses', 20),
    scroller('Passes', U2(0, 0, 0, 78), U2(1, 0, 0, 270), SCROLL_Y, [
        list_layout(VERTICAL, 8),
        frame('PassTemplate', U2(0, 0, 0, 0), U2(1, -10, 0, 62), bg=CARD, radius=14, extra=HIDDEN, children=[
            label('Title', U2(0, 12, 0, 6), U2(1, -140, 0, 24), 'Pass', 18),
            label('Description', U2(0, 12, 0, 30), U2(1, -140, 0, 26), '', 14, MUTED),
            button('Buy', U2(1, -8, 0.5, 0), U2(0, 110, 0, 42), 'R$0', PURPLE, 18, anchor=(1, 0.5)),
        ]),
    ]),
    label('CashTitle', U2(0, 0, 0, 356), U2(1, 0, 0, 24), '\U0001F4B5 Cash', 20),
    frame('Cash', U2(0, 0, 0, 386), U2(1, 0, 0, 100), transparent=True, children=[
        list_layout(HORIZONTAL, 10),
        button('CashTemplate', U2(0, 0, 0, 0), U2(0, 122, 0, 96), '', GREEN, extra=HIDDEN, children=[
            label('Amount', U2(0, 0, 0, 12), U2(1, 0, 0, 32), '$0', 22, WHITE, align=CENTER, stroke=True),
            label('Price', U2(0, 0, 0, 52), U2(1, 0, 0, 28), 'R$0', 20, GOLD, align=CENTER, stroke=True),
        ]),
    ]),
])

# --- toasts -----------------------------------------------------------------
notifications = frame('Notifications', U2(0.5, 0, 0, 74), U2(0, 460, 0, 240), transparent=True, anchor=(0.5, 0), children=[
    list_layout(VERTICAL, 8, H_CENTER),
    ('TextLabel', 'Template', {
        'Size': U2(0, 0, 0, 40), 'AutomaticSize': AUTO_X, 'BackgroundColor3': INK, 'BackgroundTransparency': 0.05,
        'BorderSizePixel': 0, 'Text': 'Message', 'TextSize': 20.0, 'TextColor3': WHITE, 'FontFace': Fnt(400),
        'Visible': False}, [corner(20), outline(3, WHITE),
                            ('UIPadding', 'UIPadding', {'PaddingLeft': UD(0, 18), 'PaddingRight': UD(0, 18)}, [])]),
])

hud = ('ScreenGui', 'HUD', {'ResetOnSpawn': False, 'ZIndexBehavior': Tok(1), 'IgnoreGuiInset': False}, [
    top_bar, actions, build_bar, selection, houses_panel, land_panel, shop_panel, notifications,
])

body = item_xml(hud)
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
       f'{body}\n</roblox>\n')
open(sys.argv[1], 'w', encoding='utf-8').write(xml)
print('items:', ref[0])
