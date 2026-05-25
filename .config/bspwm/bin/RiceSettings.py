#!/usr/bin/env python3
# =============================================================
#  RiceSettings — GTK3 settings panel for SaruM4N3 rice
# =============================================================

import gi, re, subprocess, os, math
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, Pango, GLib

RICE          = "SaruM4N3"
RICE_DIR      = os.path.expanduser(f"~/.config/bspwm/rices/{RICE}")
THEME_CFG     = os.path.join(RICE_DIR, "theme-config.bash")
MOD_DIR       = os.path.expanduser("~/.config/bspwm/config/modules")
JUNEST_BIN    = os.path.expanduser("~/.junest/usr/bin_wrappers")
PICOM_CONF    = os.path.expanduser("~/.config/bspwm/config/picom.conf")
PICOM_ANIM    = os.path.expanduser("~/.config/bspwm/config/picom-animations.conf")
BAR_CFG       = os.path.expanduser(f"~/.config/bspwm/rices/{RICE}/config.ini")
ALACRITTY_CFG = os.path.expanduser("~/.config/alacritty/alacritty.toml")
SXHKDRC       = os.path.expanduser("~/.config/bspwm/config/sxhkdrc")

# ── ThemeConfig ───────────────────────────────────────────────────────────────

class ThemeConfig:
    def __init__(self, path):
        self.path = path
        self._raw = ""
        self._vars = {}
        self.load()

    def load(self):
        with open(self.path) as f:
            self._raw = f.read()
        self._vars = {}
        for line in self._raw.splitlines():
            s = line.strip()
            m = re.match(r'^(\w+)="([^"]*)"', s)      # double-quoted
            if m: self._vars[m.group(1)] = m.group(2); continue
            m = re.match(r"^(\w+)='([^']*)'", s)       # single-quoted
            if m: self._vars[m.group(1)] = m.group(2); continue
            m = re.match(r"^(\w+)=([^\"'#\s]+)", s)    # bare (no #)
            if m: self._vars[m.group(1)] = m.group(2)

    def get(self, key, fallback=""):
        val = self._vars.get(key, fallback)
        val = re.sub(r"\$(\w+)", lambda m: self._vars.get(m.group(1), ""), val)
        return val

    def set(self, key, val):
        """Replace KEY=... in-place, preserving quote style and trailing comments."""
        self._vars[key] = val
        lines = self._raw.split('\n')
        new_lines = []
        replaced = False
        for line in lines:
            if not replaced:
                m = re.match(rf'^({re.escape(key)}=")([^"]*)"', line)
                if m:
                    tail = line[m.end()]  if m.end() < len(line) else ""
                    new_lines.append(f'{m.group(1)}{val}"{line[m.end():]}')
                    replaced = True; continue
                m = re.match(rf"^({re.escape(key)}=')([^']*)'", line)
                if m:
                    new_lines.append(f"{m.group(1)}{val}'{line[m.end():]}")
                    replaced = True; continue
                m = re.match(rf'^({re.escape(key)}=)(\S*)', line)
                if m:
                    new_lines.append(f'{m.group(1)}"{val}"{line[m.end():]}')
                    replaced = True; continue
            new_lines.append(line)
        if not replaced:
            new_lines.append(f'{key}="{val}"')
        self._raw = '\n'.join(new_lines)

    def save(self):
        try:
            with open(self.path, "w") as f:
                f.write(self._raw)
        except Exception as e:
            print(f"[RiceSettings] save error: {e}")

# ── File helpers ──────────────────────────────────────────────────────────────

def picom_get(key):
    try:
        with open(PICOM_CONF) as f:
            for line in f:
                m = re.match(rf'^\s*{re.escape(key)}\s*=\s*"?([^";]+)"?\s*;?', line)
                if m: return m.group(1).strip()
    except Exception: pass
    return ""

def picom_set(key, val):
    try:
        with open(PICOM_CONF) as f: raw = f.read()
        new, n = re.subn(
            rf'^(\s*{re.escape(key)}\s*=\s*)"?[^";]*"?(\s*;?)',
            lambda m: f'{m.group(1)}"{val}"{m.group(2)}',
            raw, flags=re.MULTILINE)
        if n == 0:
            new += f'\n{key} = "{val}";\n'
        with open(PICOM_CONF, "w") as f: f.write(new)
    except Exception as e:
        print(f"[picom_set] {e}")

def anim_get_duration(trigger):
    try:
        with open(PICOM_ANIM) as f: raw = f.read()
        pattern = rf'triggers\s*=\s*\["{re.escape(trigger)}"\][^}}]*?duration\s*=\s*([0-9.]+)'
        m = re.search(pattern, raw, re.DOTALL)
        if m: return m.group(1)
    except Exception: pass
    return "0.3"

def anim_set_duration(trigger, val):
    try:
        with open(PICOM_ANIM) as f: raw = f.read()
        def replacer(m):
            block = m.group(0)
            if f'"{trigger}"' in block:
                block = re.sub(r'(duration\s*=\s*)[0-9.]+', rf'\g<1>{val}', block, count=1)
            return block
        new = re.sub(r'\{[^{}]*\}', replacer, raw, flags=re.DOTALL)
        with open(PICOM_ANIM, "w") as f: f.write(new)
    except Exception as e:
        print(f"[anim_set_duration] {e}")

def bar_get_modules(bar, side):
    """Read modules-left/center/right for a bar section."""
    try:
        with open(BAR_CFG) as f: lines = f.readlines()
        in_section = False
        for line in lines:
            stripped = line.rstrip('\n')
            if re.match(rf'^\[bar/{re.escape(bar)}\]', stripped):
                in_section = True
                continue
            if in_section:
                if re.match(r'^\[', stripped):  # new section
                    break
                m = re.match(rf'^modules-{re.escape(side)}\s*=\s*(.*)', stripped)
                if m:
                    return m.group(1).strip()
    except Exception as e:
        print(f"[bar_get_modules] {e}")
    return ""

def bar_set_modules(bar, side, val):
    """Write modules-left/center/right for a bar. Line-by-line to avoid cross-section clobbering."""
    try:
        with open(BAR_CFG) as f: lines = f.readlines()
        in_section = False
        new_lines = []
        replaced = False
        for line in lines:
            stripped = line.rstrip('\n')
            if re.match(rf'^\[bar/{re.escape(bar)}\]', stripped):
                in_section = True
            elif re.match(r'^\[', stripped):
                in_section = False
            if in_section and not replaced:
                m = re.match(rf'^(modules-{re.escape(side)}\s*=\s*)(.*)', stripped)
                if m:
                    new_lines.append(f'{m.group(1)}{val}\n')
                    replaced = True
                    continue
            new_lines.append(line)
        with open(BAR_CFG, "w") as f: f.writelines(new_lines)
    except Exception as e:
        print(f"[bar_set_modules] {e}")

def bar_get_prop(bar, key, fallback=""):
    """Read an arbitrary key (e.g. 'width', 'offset-x') from a bar section."""
    try:
        with open(BAR_CFG) as f: lines = f.readlines()
        in_section = False
        for line in lines:
            stripped = line.rstrip('\n')
            if re.match(rf'^\[bar/{re.escape(bar)}\]', stripped):
                in_section = True; continue
            if in_section:
                if re.match(r'^\[', stripped): break
                m = re.match(rf'^{re.escape(key)}\s*=\s*(.*)', stripped)
                if m: return m.group(1).strip()
    except Exception as e:
        print(f"[bar_get_prop] {e}")
    return fallback

def bar_set_prop(bar, key, val):
    """Write an arbitrary key in a bar section. Line-by-line, section-scoped."""
    try:
        with open(BAR_CFG) as f: lines = f.readlines()
        in_section = False; new_lines = []; replaced = False
        for line in lines:
            stripped = line.rstrip('\n')
            if re.match(rf'^\[bar/{re.escape(bar)}\]', stripped): in_section = True
            elif re.match(r'^\[', stripped): in_section = False
            if in_section and not replaced:
                m = re.match(rf'^({re.escape(key)}\s*=\s*)(.*)', stripped)
                if m:
                    new_lines.append(f'{m.group(1)}{val}\n'); replaced = True; continue
            new_lines.append(line)
        with open(BAR_CFG, "w") as f: f.writelines(new_lines)
    except Exception as e:
        print(f"[bar_set_prop] {e}")

def alacritty_scroll_get(key, fallback=""):
    """Read a value from [scrolling] in alacritty.toml."""
    try:
        with open(ALACRITTY_CFG) as f: raw = f.read()
        m = re.search(r'\[scrolling\](.*?)(?=\n\[|\Z)', raw, re.DOTALL)
        if m:
            kv = re.search(rf'^{re.escape(key)}\s*=\s*(\S+)', m.group(1), re.MULTILINE)
            if kv: return kv.group(1).strip()
    except Exception: pass
    return fallback

def alacritty_scroll_set(key, val):
    """Write a value in [scrolling] in alacritty.toml."""
    try:
        with open(ALACRITTY_CFG) as f: raw = f.read()
        # Replace within [scrolling] block
        def replacer(m):
            block = m.group(0)
            new_block, n = re.subn(
                rf'^({re.escape(key)}\s*=\s*)\S+',
                rf'\g<1>{val}', block, flags=re.MULTILINE)
            if n: return new_block
            # Key not in block yet, append before end
            return block.rstrip('\n') + f'\n{key} = {val}\n'
        new = re.sub(r'\[scrolling\].*?(?=\n\[|\Z)', replacer, raw, flags=re.DOTALL)
        with open(ALACRITTY_CFG, "w") as f: f.write(new)
    except Exception as e:
        print(f"[alacritty_scroll_set] {e}")

# ── Helpers ───────────────────────────────────────────────────────────────────

def notify(msg, urgency="low"):
    """Fire-and-forget dunst notification. Never blocks the UI."""
    try:
        env = os.environ.copy()
        env["PATH"] = JUNEST_BIN + ":" + env.get("PATH", "")
        subprocess.Popen(
            ["dunstify", "-u", urgency, "-i", "preferences-system",
             "RiceSettings", msg],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass   # dunst not running — ignore silently

def flash_btn(btn, ok_label="✓ Saved!", ms=1800):
    """Briefly change a button label to give instant visual feedback."""
    orig = btn.get_label()
    btn.set_label(ok_label)
    btn.set_sensitive(False)
    def restore():
        btn.set_label(orig)
        btn.set_sensitive(True)
        return False   # remove the timeout
    GLib.timeout_add(ms, restore)

def safe_apply(fn):
    def wrapper(btn):
        try:
            fn(btn)
        except Exception as e:
            dlg = Gtk.MessageDialog(
                transient_for=btn.get_toplevel(),
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text=f"Error: {e}")
            dlg.run(); dlg.destroy()
    return wrapper

def run_module(name):
    env = os.environ.copy()
    env["PATH"] = JUNEST_BIN + ":" + env.get("PATH", "")
    # set -a auto-exports all variables so the child sh sees them
    subprocess.Popen(
        ["bash", "-c", f"set -a; source '{THEME_CFG}'; set +a; sh '{MOD_DIR}/{name}'"],
        env=env)

def hex_to_rgb(h):
    h = h.strip().lstrip("#")
    if len(h) == 6:
        return tuple(int(h[i:i+2], 16)/255.0 for i in (0, 2, 4))
    return (0.1, 0.1, 0.1)

def rgba_to_hex(rgba):
    return "#{:02X}{:02X}{:02X}".format(
        int(rgba.red*255), int(rgba.green*255), int(rgba.blue*255))

# ── Predefined colour schemes ─────────────────────────────────────────────────

SCHEMES = {
    "Lovelace": {
        "bg":"#1D1F28","fg":"#FDFDFD","accent_color":"#1F222B",
        "black":"#282A36","red":"#F37F97","green":"#5ADECD","yellow":"#F2A272",
        "blue":"#8897F4","magenta":"#C574DD","cyan":"#79E6F3","white":"#FDFDFD",
        "blackb":"#414458","redb":"#FF4971","greenb":"#18E3C8","yellowb":"#FF8037",
        "blueb":"#556FFF","magentab":"#B043D1","cyanb":"#3FDCEE","whiteb":"#BEBEC1",
    },
    "Catppuccin": {
        "bg":"#1E1E2E","fg":"#CDD6F4","accent_color":"#313244",
        "black":"#45475A","red":"#F38BA8","green":"#A6E3A1","yellow":"#F9E2AF",
        "blue":"#89B4FA","magenta":"#CBA4F7","cyan":"#89DCEB","white":"#BAC2DE",
        "blackb":"#585B70","redb":"#F38BA8","greenb":"#A6E3A1","yellowb":"#F9E2AF",
        "blueb":"#89B4FA","magentab":"#CBA4F7","cyanb":"#89DCEB","whiteb":"#A6ADC8",
    },
    "Dracula": {
        "bg":"#282A36","fg":"#F8F8F2","accent_color":"#44475A",
        "black":"#21222C","red":"#FF5555","green":"#50FA7B","yellow":"#F1FA8C",
        "blue":"#BD93F9","magenta":"#FF79C6","cyan":"#8BE9FD","white":"#F8F8F2",
        "blackb":"#6272A4","redb":"#FF6E6E","greenb":"#69FF94","yellowb":"#FFFFA5",
        "blueb":"#D6ACFF","magentab":"#FF92DF","cyanb":"#A4FFFF","whiteb":"#FFFFFF",
    },
    "Nord": {
        "bg":"#2E3440","fg":"#ECEFF4","accent_color":"#3B4252",
        "black":"#3B4252","red":"#BF616A","green":"#A3BE8C","yellow":"#EBCB8B",
        "blue":"#81A1C1","magenta":"#B48EAD","cyan":"#88C0D0","white":"#E5E9F0",
        "blackb":"#4C566A","redb":"#BF616A","greenb":"#A3BE8C","yellowb":"#EBCB8B",
        "blueb":"#81A1C1","magentab":"#B48EAD","cyanb":"#8FBCBB","whiteb":"#ECEFF4",
    },
    "Gruvbox": {
        "bg":"#282828","fg":"#EBDBB2","accent_color":"#3C3836",
        "black":"#282828","red":"#CC241D","green":"#98971A","yellow":"#D79921",
        "blue":"#458588","magenta":"#B16286","cyan":"#689D6A","white":"#A89984",
        "blackb":"#928374","redb":"#FB4934","greenb":"#B8BB26","yellowb":"#FABD2F",
        "blueb":"#83A598","magentab":"#D3869B","cyanb":"#8EC07C","whiteb":"#EBDBB2",
    },
    "Tokyo Night": {
        "bg":"#1A1B26","fg":"#C0CAF5","accent_color":"#24283B",
        "black":"#15161E","red":"#F7768E","green":"#9ECE6A","yellow":"#E0AF68",
        "blue":"#7AA2F7","magenta":"#BB9AF7","cyan":"#7DCFFF","white":"#A9B1D6",
        "blackb":"#414868","redb":"#F7768E","greenb":"#9ECE6A","yellowb":"#E0AF68",
        "blueb":"#7AA2F7","magentab":"#BB9AF7","cyanb":"#7DCFFF","whiteb":"#C0CAF5",
    },
    "Everforest": {
        "bg":"#2D353B","fg":"#D3C6AA","accent_color":"#374145",
        "black":"#343F44","red":"#E67E80","green":"#A7C080","yellow":"#DBBC7F",
        "blue":"#7FBBB3","magenta":"#D699B6","cyan":"#83C092","white":"#D3C6AA",
        "blackb":"#3D484D","redb":"#E67E80","greenb":"#A7C080","yellowb":"#DBBC7F",
        "blueb":"#7FBBB3","magentab":"#D699B6","cyanb":"#83C092","whiteb":"#D3C6AA",
    },
    "Cyberpunk": {
        "bg":"#0D0E16","fg":"#FFFFFF","accent_color":"#1A1A2E",
        "black":"#1A1A2E","red":"#FF003C","green":"#00FF9F","yellow":"#FFE600",
        "blue":"#00B3FF","magenta":"#FF00FF","cyan":"#00FFFF","white":"#FFFFFF",
        "blackb":"#16213E","redb":"#FF0055","greenb":"#00FFAA","yellowb":"#FFFF00",
        "blueb":"#00CCFF","magentab":"#FF44FF","cyanb":"#44FFFF","whiteb":"#FFFFFF",
    },
}

PALETTE_KEYS = ["red","green","yellow","blue","magenta","cyan"]
ALL_COLOR_KEYS = [
    "bg","fg","accent_color",
    "black","red","green","yellow","blue","magenta","cyan","white",
    "blackb","redb","greenb","yellowb","blueb","magentab","cyanb","whiteb",
]

# ── Custom colour swatch ──────────────────────────────────────────────────────

class ColorSwatch(Gtk.Button):
    def __init__(self, hex_color="#000000"):
        super().__init__()
        self._hex = hex_color.strip() or "#000000"
        self.set_size_request(76, 30)
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.get_style_context().add_class("color-swatch-btn")
        self._da = Gtk.DrawingArea()
        self._da.set_size_request(76, 30)
        self._da.connect("draw", self._draw)
        self.add(self._da)
        self.connect("clicked", self._pick)

    def _draw(self, _w, cr):
        w = self._da.get_allocated_width()
        h = self._da.get_allocated_height()
        r, g, b = hex_to_rgb(self._hex)
        rad = 7
        cr.new_sub_path()
        cr.arc(w-rad, rad,   rad, -math.pi/2, 0)
        cr.arc(w-rad, h-rad, rad,  0,          math.pi/2)
        cr.arc(rad,   h-rad, rad,  math.pi/2,  math.pi)
        cr.arc(rad,   rad,   rad,  math.pi,    3*math.pi/2)
        cr.close_path()
        cr.set_source_rgb(r, g, b)
        cr.fill_preserve()
        cr.set_source_rgba(1, 1, 1, 0.1)
        cr.set_line_width(1); cr.stroke()
        lum = 0.299*r + 0.587*g + 0.114*b
        cr.set_source_rgba(0,0,0,0.75) if lum > 0.45 else cr.set_source_rgba(1,1,1,0.80)
        cr.select_font_face("monospace", 0, 0)
        cr.set_font_size(8.5)
        te = cr.text_extents(self._hex.upper())
        cr.move_to((w - te.width)/2, (h + te.height)/2)
        cr.show_text(self._hex.upper())

    def _pick(self, _b):
        dlg = Gtk.ColorChooserDialog(title="Pick Color",
                                     transient_for=self.get_toplevel())
        dlg.set_use_alpha(False)
        rgba = Gdk.RGBA(); rgba.parse(self._hex)
        dlg.set_rgba(rgba)
        if dlg.run() == Gtk.ResponseType.OK:
            self._hex = rgba_to_hex(dlg.get_rgba())
            self._da.queue_draw()
        dlg.destroy()

    def get_hex(self):       return self._hex
    def set_hex(self, h):
        self._hex = h.strip() or "#000000"
        self._da.queue_draw()

# ── CSS ───────────────────────────────────────────────────────────────────────

CSS = """
* { font-family: "JetBrainsMono Nerd Font Mono", "Noto Sans", sans-serif; }
window { background-color: #1a1b26; }

.topbar {
    background-color: #16171f; min-height: 52px;
    padding: 0 18px; border-bottom: 1px solid rgba(255,255,255,0.055);
}
.topbar-title { font-size: 14px; font-weight: bold; color: #FDFDFD; }
.topbar-sub   { font-size: 11px; color: rgba(253,253,253,0.32); }
.close-btn {
    background: rgba(255,255,255,0.07); border: none; border-radius: 50%;
    color: rgba(253,253,253,0.5); min-width: 28px; min-height: 28px;
    padding: 0; font-size: 13px; box-shadow: none; text-shadow: none;
}
.close-btn:hover { background: rgba(255,70,70,0.35); color: #ff6b6b; }

.sidebar {
    background-color: #16171f;
    border-right: 1px solid rgba(255,255,255,0.055);
    padding: 10px 7px;
}
.section-lbl {
    font-size: 10px; font-weight: bold;
    color: rgba(253,253,253,0.25); padding: 10px 11px 5px 11px;
}
.nav-btn {
    background: transparent; border: none;
    border-radius: 9px; padding: 9px 12px;
    box-shadow: none; text-shadow: none; outline: none;
}
.nav-btn:hover  { background: rgba(255,255,255,0.055); }
.nav-btn.active { background: rgba(136,151,244,0.15); }
.nav-icon  { font-size: 13px; color: rgba(253,253,253,0.35); min-width: 20px; }
.nav-label { font-size: 13px; color: rgba(253,253,253,0.58); }
.nav-btn.active .nav-icon  { color: #8897F4; }
.nav-btn.active .nav-label { color: #c7d0ff; font-weight: bold; }
.nav-btn:hover .nav-icon   { color: rgba(253,253,253,0.7); }
.nav-btn:hover .nav-label  { color: rgba(253,253,253,0.88); }

.content-bg { background-color: #1a1b26; }
.page-title { font-size: 22px; font-weight: bold; color: #FDFDFD; }
.page-sub   { font-size: 12px; color: rgba(253,253,253,0.36); }
.group-lbl  {
    font-size: 10px; font-weight: bold;
    color: rgba(253,253,253,0.28); padding: 0 2px 5px 2px;
}

.card {
    background-color: rgba(255,255,255,0.038);
    border-radius: 12px; border: 1px solid rgba(255,255,255,0.07);
}
.card-list            { background: transparent; border-radius: 12px; }
.card-list row        { background: transparent; border-bottom: 1px solid rgba(255,255,255,0.045); padding: 0; }
.card-list row:last-child { border-bottom: none; }
.card-list row:hover  { background: rgba(255,255,255,0.025); }
.row-lbl { font-size: 13px; color: #FDFDFD; }
.row-sub { font-size: 11px; color: rgba(253,253,253,0.36); margin-top: 1px; }

.scheme-tile {
    background: rgba(255,255,255,0.04); border-radius: 10px;
    border: 1.5px solid rgba(255,255,255,0.07); padding: 11px 13px;
}
.scheme-tile:hover         { background: rgba(255,255,255,0.07); border-color: rgba(136,151,244,0.3); }
.scheme-tile.active-scheme { background: rgba(85,111,255,0.1); border-color: #556FFF; }
.scheme-name { font-size: 12px; color: rgba(253,253,253,0.78); }

switch {
    background: rgba(255,255,255,0.1); border: none;
    border-radius: 14px; min-width: 44px; min-height: 22px; outline: none;
}
switch:checked { background: #556FFF; }
switch slider  {
    background: white; border-radius: 50%;
    min-width: 16px; min-height: 16px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.5); border: none;
}
spinbutton {
    background: rgba(255,255,255,0.06); color: #FDFDFD;
    border: 1px solid rgba(255,255,255,0.1); border-radius: 8px;
    padding: 4px 8px; min-width: 82px;
}
spinbutton:focus { border-color: #556FFF; box-shadow: 0 0 0 2px rgba(85,111,255,0.2); }
spinbutton button { background: transparent; border: none; color: rgba(253,253,253,0.4); padding: 2px 4px; }
spinbutton button:hover { color: #FDFDFD; }
entry {
    background: rgba(255,255,255,0.06); color: #FDFDFD;
    border: 1px solid rgba(255,255,255,0.1); border-radius: 8px;
    padding: 6px 10px; caret-color: #8897F4;
}
entry:focus { border-color: #556FFF; box-shadow: 0 0 0 2px rgba(85,111,255,0.2); }
combobox button {
    background: rgba(255,255,255,0.06); color: #FDFDFD;
    border: 1px solid rgba(255,255,255,0.1); border-radius: 8px;
    padding: 5px 10px; box-shadow: none;
}
combobox button:hover { background: rgba(255,255,255,0.1); }

.apply-btn {
    background: #556FFF; color: white; border: none;
    border-radius: 8px; padding: 7px 20px;
    font-size: 12px; font-weight: bold; box-shadow: none; text-shadow: none;
}
.apply-btn:hover  { background: #6b82ff; }
.apply-btn:active { background: #4459dd; }
.apply-all-btn           { background: #26A269; }
.apply-all-btn:hover     { background: #33c47e; }
.apply-all-btn:active    { background: #1d8050; }
.browse-btn {
    background: rgba(255,255,255,0.07); color: rgba(253,253,253,0.7);
    border: 1px solid rgba(255,255,255,0.12); border-radius: 8px;
    padding: 5px 12px; font-size: 12px; box-shadow: none; text-shadow: none;
}
.browse-btn:hover { background: rgba(255,255,255,0.12); color: #FDFDFD; }
.reload-btn {
    background: rgba(136,151,244,0.15); color: #c7d0ff;
    border: 1px solid rgba(136,151,244,0.3); border-radius: 8px;
    padding: 7px 20px; font-size: 12px; font-weight: bold;
    box-shadow: none; text-shadow: none;
}
.reload-btn:hover  { background: rgba(136,151,244,0.25); }

.color-swatch-btn { background: transparent; border: none; padding: 0; box-shadow: none; }
.color-swatch-btn:hover { background: transparent; }

/* keybind capture button */
.capture-btn {
    background: rgba(136,151,244,0.10); color: #8897F4;
    border: 1px solid rgba(136,151,244,0.22); border-radius: 8px;
    padding: 4px 11px; font-size: 14px; box-shadow: none; min-width: 32px;
}
.capture-btn:hover { background: rgba(136,151,244,0.22); }
.capture-btn.capturing {
    background: rgba(255,200,0,0.14); color: #ffcc00;
    border-color: rgba(255,200,0,0.45);
}
.kbd-entry {
    font-family: "JetBrainsMono Nerd Font Mono", monospace;
    font-size: 12px; color: #c7d0ff;
}

separator { background: rgba(255,255,255,0.055); }
scrollbar { background: transparent; border: none; padding: 0; }
scrollbar slider {
    background: rgba(255,255,255,0.1); border-radius: 4px;
    min-width: 4px; min-height: 4px; border: 2px solid transparent;
}
scrollbar slider:hover { background: rgba(255,255,255,0.2); }
"""

# ── Widget builders ───────────────────────────────────────────────────────────

def make_row(label, widget, sub=None):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    box.set_margin_top(11); box.set_margin_bottom(11)
    box.set_margin_start(16); box.set_margin_end(16)
    lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
    lbox.set_hexpand(True)
    lbl = Gtk.Label(label=label, xalign=0)
    lbl.get_style_context().add_class("row-lbl")
    lbox.pack_start(lbl, False, False, 0)
    if sub:
        s = Gtk.Label(label=sub, xalign=0)
        s.get_style_context().add_class("row-sub")
        lbox.pack_start(s, False, False, 0)
    box.pack_start(lbox, True, True, 0)
    box.pack_end(widget, False, False, 0)
    return box

def make_card(rows):
    frame = Gtk.Frame()
    frame.get_style_context().add_class("card")
    frame.set_shadow_type(Gtk.ShadowType.NONE)
    lb = Gtk.ListBox()
    lb.set_selection_mode(Gtk.SelectionMode.NONE)
    lb.get_style_context().add_class("card-list")
    for r in rows: lb.add(r)
    frame.add(lb)
    return frame

def make_group(title, rows):
    vb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    if title:
        l = Gtk.Label(label=title.upper(), xalign=0)
        l.get_style_context().add_class("group-lbl")
        vb.pack_start(l, False, False, 0)
    vb.pack_start(make_card(rows), False, False, 0)
    return vb

def make_spin(val, lo, hi, step=1, digits=0):
    adj = Gtk.Adjustment(value=float(val or 0), lower=lo, upper=hi,
                         step_increment=step, page_increment=step*5)
    return Gtk.SpinButton(adjustment=adj, digits=digits,
                          valign=Gtk.Align.CENTER, width_request=88)

def make_switch(active):
    return Gtk.Switch(active=bool(active), valign=Gtk.Align.CENTER)

def make_entry(text, width=200):
    return Gtk.Entry(text=text or "", width_request=width, valign=Gtk.Align.CENTER)

def make_combo(opts, cur):
    c = Gtk.ComboBoxText(valign=Gtk.Align.CENTER)
    for o in opts: c.append_text(o)
    c.set_active(opts.index(cur) if cur in opts else 0)
    return c

def apply_btn(label="Apply"):
    b = Gtk.Button(label=label, valign=Gtk.Align.CENTER)
    b.get_style_context().add_class("apply-btn")
    return b

def browse_btn(label="Browse…"):
    b = Gtk.Button(label=label, valign=Gtk.Align.CENTER)
    b.get_style_context().add_class("browse-btn")
    return b

def color_dot(hex_color, size=14):
    da = Gtk.DrawingArea()
    da.set_size_request(size, size)
    r, g, b = hex_to_rgb(hex_color)
    def draw(_w, cr):
        cr.arc(size/2, size/2, size/2-1, 0, 2*math.pi)
        cr.set_source_rgb(r, g, b)
        cr.fill_preserve()
        cr.set_source_rgba(1,1,1,0.18)
        cr.set_line_width(1); cr.stroke()
    da.connect("draw", draw)
    return da

def page_wrap(title, subtitle, groups):
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroll.set_hexpand(True); scroll.set_vexpand(True)
    scroll.get_style_context().add_class("content-bg")
    outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    outer.set_margin_top(30); outer.set_margin_bottom(30)
    outer.set_margin_start(30); outer.set_margin_end(30)
    t = Gtk.Label(label=title, xalign=0)
    t.get_style_context().add_class("page-title")
    outer.pack_start(t, False, False, 0)
    if subtitle:
        s = Gtk.Label(label=subtitle, xalign=0)
        s.get_style_context().add_class("page-sub")
        s.set_margin_bottom(22)
        outer.pack_start(s, False, False, 0)
    else:
        sp = Gtk.Box(); sp.set_margin_bottom(18); outer.pack_start(sp, False, False, 0)
    inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=22)
    for g in groups: inner.pack_start(g, False, False, 0)
    outer.pack_start(inner, True, True, 0)
    scroll.add(outer)
    return scroll

def make_path_row(label, entry, action, sub=None, parent_win=None):
    """Row with an entry + Browse button for file/folder paths."""
    bb = browse_btn()
    def on_browse(_b):
        if action == "folder":
            dlg = Gtk.FileChooserDialog(
                title="Select Folder", transient_for=parent_win,
                action=Gtk.FileChooserAction.SELECT_FOLDER)
        else:
            dlg = Gtk.FileChooserDialog(
                title="Select File", transient_for=parent_win,
                action=Gtk.FileChooserAction.OPEN)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        cur = entry.get_text()
        if cur and os.path.exists(cur):
            if os.path.isdir(cur):
                dlg.set_current_folder(cur)
            else:
                dlg.set_filename(cur)
        if dlg.run() == Gtk.ResponseType.OK:
            entry.set_text(dlg.get_filename())
        dlg.destroy()
    bb.connect("clicked", on_browse)
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6,
                  valign=Gtk.Align.CENTER)
    box.pack_start(entry, True, True, 0)
    box.pack_start(bb, False, False, 0)
    return make_row(label, box, sub)

# ── sxhkdrc parser ────────────────────────────────────────────────────────────

def parse_sxhkdrc(path):
    """
    Returns (entries, orig_lines).
    entries = list of dicts:
      {'type':'section', 'title': str}
      {'type':'keybind', 'section': str, 'label': str,
       'keybind': str, 'keybind_line': int, 'command': str}
    """
    try:
        with open(path) as f:
            all_lines = f.readlines()
    except Exception as e:
        return [{'type':'section','title':f'Error: {e}'}], []

    entries        = []
    current_section = ""
    pending_comment = ""
    i = 0

    while i < len(all_lines):
        raw     = all_lines[i]
        stripped = raw.strip()

        # All-hash border line  ──  skip
        if re.match(r'^#{3,}\s*$', stripped):
            i += 1; continue

        # Section title:  # ----- Title ----- #
        m = re.match(r'^#\s*-{2,}\s*(.*?)\s*-{0,}\s*#?\s*$', stripped)
        if m:
            title = m.group(1).strip()
            if title:
                current_section = title
                entries.append({'type': 'section', 'title': title})
            pending_comment = ""
            i += 1; continue

        # Regular comment → pending action label
        if stripped.startswith('#'):
            pending_comment = stripped.lstrip('#').strip()
            i += 1; continue

        # Empty line → discard pending comment
        if not stripped:
            pending_comment = ""
            i += 1; continue

        # Keybind line (non-indented, non-empty, non-comment)
        if raw[0:1] not in ('\t', ' '):
            keybind_line = i
            keybind      = stripped
            j            = i + 1
            cmd_parts    = []
            while j < len(all_lines) and all_lines[j][0:1] in ('\t', ' ') and all_lines[j].strip():
                cmd_parts.append(all_lines[j].strip())
                j += 1
            cmd   = ' ; '.join(cmd_parts)
            label = pending_comment or (cmd[:52] + '…' if len(cmd) > 52 else cmd)
            entries.append({
                'type':         'keybind',
                'section':      current_section,
                'label':        label,
                'keybind':      keybind,
                'keybind_line': keybind_line,
                'command':      cmd,
            })
            pending_comment = ""
            i = j; continue

        i += 1

    return entries, all_lines


def setup_key_capture(button, entry):
    """
    Click the button → it waits for the next key combo pressed by the user,
    formats it in sxhkd notation, and fills the entry.  Click again to cancel.
    """
    _s = {'active': False, 'handler': None}

    MODIFIER_KEYS = {
        "Super_L","Super_R","Control_L","Control_R",
        "Alt_L","Alt_R","Shift_L","Shift_R",
        "Hyper_L","Hyper_R","Meta_L","Meta_R","ISO_Level3_Shift",
    }

    def on_click(_b):
        win = button.get_toplevel()
        if _s['active']:           # second click = cancel
            _s['active'] = False
            button.set_label("⌨")
            button.get_style_context().remove_class("capturing")
            if _s['handler']:
                win.disconnect(_s['handler']); _s['handler'] = None
            return
        _s['active'] = True
        button.set_label("…")
        button.get_style_context().add_class("capturing")
        _s['handler'] = win.connect("key-press-event", on_key)

    def on_key(win, event):
        if not _s['active']: return False
        keyname = Gdk.keyval_name(event.keyval) or ""
        if keyname in MODIFIER_KEYS:
            return True   # wait for a real key

        mods  = []
        state = event.state & ~Gdk.ModifierType.LOCK_MASK
        if state & Gdk.ModifierType.MOD4_MASK:    mods.append("super")
        if state & Gdk.ModifierType.CONTROL_MASK:  mods.append("ctrl")
        if state & Gdk.ModifierType.MOD1_MASK:     mods.append("alt")
        if state & Gdk.ModifierType.SHIFT_MASK:    mods.append("shift")

        # Normalise key name for sxhkd:
        #   single letters  → lowercase      (super + q, not super + Q)
        #   special keys    → keep GDK case  (F1, Return, Tab, space …)
        #   numpad          → strip KP_ prefix
        if keyname.startswith("KP_"):
            key = keyname[3:].lower()
        elif len(keyname) == 1:
            key = keyname.lower()   # plain letter / symbol
        else:
            key = keyname           # Return, F1, Tab, space, BackSpace …

        combo = " + ".join(mods + [key]) if mods else key
        entry.set_text(combo)

        # Cleanup
        _s['active'] = False
        button.set_label("⌨")
        button.get_style_context().remove_class("capturing")
        win.disconnect(_s['handler']); _s['handler'] = None
        return True   # swallow the event

    button.connect("clicked", on_click)


# ── Pages ─────────────────────────────────────────────────────────────────────

def colors_page(cfg):
    widgets = {}

    def crow(key, label):
        sw = ColorSwatch(cfg.get(key, "#000000"))
        widgets[key] = sw
        return make_row(label, sw)

    scheme_tiles = {}

    def apply_scheme(name):
        s = SCHEMES[name]
        for k, sw in widgets.items():
            if k in s: sw.set_hex(s[k])
        for n, tile in scheme_tiles.items():
            ctx = tile.get_style_context()
            ctx.add_class("active-scheme") if n == name else ctx.remove_class("active-scheme")
        for k, sw in widgets.items():
            cfg.set(k, sw.get_hex())
        cfg.save()
        notify(f"Scheme '{name}' saved.")

    flow = Gtk.FlowBox()
    flow.set_max_children_per_line(2); flow.set_min_children_per_line(2)
    flow.set_selection_mode(Gtk.SelectionMode.NONE)
    flow.set_column_spacing(10); flow.set_row_spacing(10)
    flow.set_homogeneous(True)
    cur_bg = cfg.get("bg", "").upper()
    for name, colors in SCHEMES.items():
        eb = Gtk.EventBox()
        eb.get_style_context().add_class("scheme-tile")
        if colors["bg"].upper() == cur_bg:
            eb.get_style_context().add_class("active-scheme")
        tile = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
        nm = Gtk.Label(label=name, xalign=0)
        nm.get_style_context().add_class("scheme-name")
        dots = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        for k in PALETTE_KEYS:
            dots.pack_start(color_dot(colors[k], 14), False, False, 0)
        tile.pack_start(nm, False, False, 0)
        tile.pack_start(dots, False, False, 0)
        eb.add(tile)
        eb.connect("button-press-event", lambda _e, _ev, n=name: apply_scheme(n))
        scheme_tiles[name] = eb
        flow.add(eb)

    schemes_grp = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    sl = Gtk.Label(label="PREDEFINED COLOR SCHEMES", xalign=0)
    sl.get_style_context().add_class("group-lbl")
    schemes_grp.pack_start(sl, False, False, 0)
    schemes_grp.pack_start(flow, False, False, 0)

    base    = make_group("Base Colors", [
        crow("bg","Background"), crow("fg","Foreground"), crow("accent_color","Accent"),
    ])
    palette = make_group("Palette", [
        crow("black","Black"), crow("red","Red"), crow("green","Green"),
        crow("yellow","Yellow"), crow("blue","Blue"), crow("magenta","Magenta"),
        crow("cyan","Cyan"), crow("white","White"),
    ])
    bright  = make_group("Bright Palette", [
        crow("blackb","Bright Black"), crow("redb","Bright Red"),
        crow("greenb","Bright Green"), crow("yellowb","Bright Yellow"),
        crow("blueb","Bright Blue"), crow("magentab","Bright Magenta"),
        crow("cyanb","Bright Cyan"), crow("whiteb","Bright White"),
    ])

    save_btn = apply_btn("Save Colors")
    def save(btn):
        for k, sw in widgets.items(): cfg.set(k, sw.get_hex())
        cfg.save(); notify("Colors saved.")
    save_btn.connect("clicked", safe_apply(save))

    # Apply Everywhere: dunst / rofi / jgmenu only — NOT terminals
    # (Terminal has its own page with Apply button)
    apply_all_btn = apply_btn("Apply to UI Apps")
    apply_all_btn.get_style_context().add_class("apply-all-btn")
    def apply_all(btn):
        for k, sw in widgets.items(): cfg.set(k, sw.get_hex())
        cfg.save()
        for mod in ("08-dunst.sh","09-rofi.sh","10-jgmenu.sh"):
            run_module(mod)
        flash_btn(btn, "✓ Applied!")
        notify("Colors applied to dunst, rofi, jgmenu.\nGo to Terminal page to apply to terminals.")
    apply_all_btn.connect("clicked", safe_apply(apply_all))

    action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                         halign=Gtk.Align.END)
    action_box.set_margin_top(4); action_box.set_margin_bottom(4)
    action_box.set_margin_end(4)
    action_box.pack_start(save_btn,      False, False, 0)
    action_box.pack_start(apply_all_btn, False, False, 0)

    note = Gtk.Label(
        label="Colors are used by dunst, rofi, jgmenu and also as defaults for terminals.\n"
              "'Apply to UI Apps' updates dunst/rofi/jgmenu. Use the Terminal page to apply to terminals.",
        xalign=0, wrap=True)
    note.get_style_context().add_class("row-sub")
    note.set_margin_start(2)

    actions_grp = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    actions_grp.pack_start(note,       False, False, 0)
    actions_grp.pack_start(action_box, False, False, 0)

    return page_wrap("Colors", "Colorscheme settings for UI apps (dunst, rofi, jgmenu).",
                     [schemes_grp, base, palette, bright, actions_grp])


def borders_page(cfg):
    bw  = make_spin(cfg.get("BORDER_WIDTH","2"), 0, 20)
    gap = make_spin(cfg.get("WINDOW_GAP","3"), 0, 100)
    nbc = ColorSwatch(cfg.get("NORMAL_BC","#1C71D8"))
    fbc = ColorSwatch(cfg.get("FOCUSED_BC","#26A269"))

    btn = apply_btn()
    def apply(btn):
        cfg.set("BORDER_WIDTH", str(int(bw.get_value())))
        cfg.set("WINDOW_GAP",   str(int(gap.get_value())))
        cfg.set("NORMAL_BC",    nbc.get_hex())
        cfg.set("FOCUSED_BC",   fbc.get_hex())
        cfg.save()
        subprocess.run(["bspc","config","border_width",         cfg.get("BORDER_WIDTH")])
        subprocess.run(["bspc","config","window_gap",           cfg.get("WINDOW_GAP")])
        subprocess.run(["bspc","config","normal_border_color",  cfg.get("NORMAL_BC")])
        subprocess.run(["bspc","config","focused_border_color", cfg.get("FOCUSED_BC")])
        flash_btn(btn, "✓ Applied!")
        notify("Borders applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("Borders", "Window borders and gaps.", [
        make_group("Window Borders", [
            make_row("Border Width",  bw),
            make_row("Window Gap",    gap),
            make_row("Normal Color",  nbc, "Unfocused window border"),
            make_row("Focused Color", fbc, "Active window border"),
        ]),
        make_group("", [make_row("Apply to running bspwm", btn)]),
    ])


def picom_page(cfg):
    fade   = make_switch(cfg.get("P_FADE")       == "true")
    shadow = make_switch(cfg.get("P_SHADOWS")    == "true")
    blur   = make_switch(cfg.get("P_BLUR")       == "true")
    anim   = make_switch(cfg.get("P_ANIMATIONS") == "@")
    shc    = ColorSwatch(cfg.get("SHADOW_C","#000000"))
    corner = make_spin(cfg.get("P_CORNER_R","0"), 0, 50)
    opac   = make_spin(cfg.get("P_TERM_OPACITY","1.0"), 0.1, 1.0, 0.05, 2)

    backends = ["glx","xrender","egl"]
    cur_backend = picom_get("backend") or "glx"
    backend_combo = make_combo(backends, cur_backend)

    def dspin(trigger):
        return make_spin(anim_get_duration(trigger), 0.05, 2.0, 0.05, 2)

    d_open  = dspin("open")
    d_close = dspin("close")
    d_show  = dspin("show")
    d_hide  = dspin("hide")
    d_geom  = dspin("geometry")

    btn = apply_btn()
    def apply(btn):
        cfg.set("P_FADE",         "true" if fade.get_active()   else "false")
        cfg.set("P_SHADOWS",      "true" if shadow.get_active() else "false")
        cfg.set("SHADOW_C",       shc.get_hex())
        cfg.set("P_CORNER_R",     str(int(corner.get_value())))
        cfg.set("P_BLUR",         "true" if blur.get_active()   else "false")
        cfg.set("P_ANIMATIONS",   "@" if anim.get_active() else "#")
        cfg.set("P_TERM_OPACITY", f"{opac.get_value():.2f}")
        cfg.save()
        picom_set("backend", backend_combo.get_active_text())
        anim_set_duration("open",     f"{d_open.get_value():.2f}")
        anim_set_duration("close",    f"{d_close.get_value():.2f}")
        anim_set_duration("show",     f"{d_show.get_value():.2f}")
        anim_set_duration("hide",     f"{d_hide.get_value():.2f}")
        anim_set_duration("geometry", f"{d_geom.get_value():.2f}")
        run_module("01-picom.sh")
        env = os.environ.copy()
        env["PATH"] = JUNEST_BIN + ":" + env.get("PATH", "")
        subprocess.Popen(["bash","-c",
            "pkill -x picom; sleep 0.2; picom --config ~/.config/bspwm/config/picom.conf &"],
            env=env)
        flash_btn(btn, "✓ Applied!")
        notify("Picom applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("Picom", "Compositor effects and transparency.", [
        make_group("Backend", [
            make_row("Renderer", backend_combo, "glx = GPU  |  xrender = CPU  |  egl = modern GPU"),
        ]),
        make_group("Effects", [
            make_row("Fade",             fade,   "Fade windows in/out"),
            make_row("Shadows",          shadow, "Drop shadows on windows"),
            make_row("Shadow Color",     shc),
            make_row("Blur",             blur,   "Background blur"),
            make_row("Animations",       anim,   "Enable open/close animations"),
        ]),
        make_group("Tweaks", [
            make_row("Corner Radius",    corner, "Rounded corners (0 = off)"),
            make_row("Terminal Opacity", opac,   "0.1 transparent → 1.0 opaque"),
        ]),
        make_group("Animation Durations", [
            make_row("Open",     d_open,  "Window opening"),
            make_row("Close",    d_close, "Window closing"),
            make_row("Show",     d_show,  "Workspace switch in"),
            make_row("Hide",     d_hide,  "Workspace switch out"),
            make_row("Geometry", d_geom,  "Window resize/move"),
        ]),
        make_group("", [make_row("Restart picom with new settings", btn)]),
    ])


def bar_page(cfg):
    h4k    = make_spin(cfg.get("BAR_HEIGHT_4K",    "40"), 10, 100)
    px4k   = make_spin(cfg.get("BAR_PIXELSIZE_4K", "10"),  4,  30)
    h1080  = make_spin(cfg.get("BAR_HEIGHT_1080",  "24"), 10, 100)
    px1080 = make_spin(cfg.get("BAR_PIXELSIZE_1080","7"),   4,  30)

    BARS = ["saru1","saru2","saru3","saru4","saru5","saru6","saru7"]
    BAR_LABELS = {
        "saru1": "Workspace launcher",
        "saru2": "Workspace list",
        "saru3": "Media controls",
        "saru4": "Date / Weather",
        "saru5": "System stats",
        "saru6": "Volume / Brightness",
        "saru7": "Power menu",
    }
    module_entries = {}
    layout_entries = {}

    def module_section(bar):
        label = BAR_LABELS.get(bar, bar)
        # Position / size
        e_w   = make_entry(bar_get_prop(bar, "width",    ""), 80)
        e_ox  = make_entry(bar_get_prop(bar, "offset-x", ""), 80)
        e_oy  = make_entry(bar_get_prop(bar, "offset-y", ""), 60)
        layout_entries[bar] = {"width": e_w, "offset-x": e_ox, "offset-y": e_oy}
        # Modules
        e_l = make_entry(bar_get_modules(bar, "left"),   220)
        e_c = make_entry(bar_get_modules(bar, "center"), 220)
        e_r = make_entry(bar_get_modules(bar, "right"),  220)
        module_entries[bar] = {"left": e_l, "center": e_c, "right": e_r}
        return make_group(f"{bar}  —  {label}", [
            make_row("Width",    e_w,  "e.g. 10% or 200"),
            make_row("Offset X", e_ox, "e.g. 5% or 80"),
            make_row("Offset Y", e_oy, "pixels from edge"),
            make_row("Left",     e_l,  "Space-separated module names"),
            make_row("Center",   e_c),
            make_row("Right",    e_r),
        ])

    mod_groups = [module_section(b) for b in BARS]

    btn = apply_btn()
    def apply(btn):
        cfg.set("BAR_HEIGHT_4K",      str(int(h4k.get_value())))
        cfg.set("BAR_PIXELSIZE_4K",   str(int(px4k.get_value())))
        cfg.set("BAR_HEIGHT_1080",    str(int(h1080.get_value())))
        cfg.set("BAR_PIXELSIZE_1080", str(int(px1080.get_value())))
        cfg.save()
        for bar, props in layout_entries.items():
            for prop, entry in props.items():
                v = entry.get_text().strip()
                if v:
                    bar_set_prop(bar, prop, v)
        for bar, sides in module_entries.items():
            for side, entry in sides.items():
                bar_set_modules(bar, side, entry.get_text())
        # Already inside junest — use native binaries directly (no wrapper).
        # JUNEST_BIN wrappers launch a *nested* junest that can't see outer processes.
        env = os.environ.copy()
        bspwm_bin = os.path.expanduser("~/.config/bspwm/bin")
        env["PATH"] = bspwm_bin + ":" + env.get("PATH", "")
        env["RICE"] = RICE
        subprocess.Popen(
            ["/usr/bin/bash", "-c",
             f"/usr/bin/pkill -x polybar 2>/dev/null; sleep 0.4;"
             f" RICE={RICE} /usr/bin/bash '{RICE_DIR}/Bar.bash'"],
            env=env)
        flash_btn(btn, "✓ Applied!")
        notify("Bar applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("Bar", "Polybar sizing, position and module layout.", [
        make_group("4K  ( > 2560 px wide )", [
            make_row("Bar Height", h4k,  "pixels"),
            make_row("Font Size",  px4k, "pixelsize"),
        ]),
        make_group("1080p  ( ≤ 1920 px wide )", [
            make_row("Bar Height", h1080,  "pixels"),
            make_row("Font Size",  px1080, "pixelsize"),
        ]),
        *mod_groups,
        make_group("", [make_row("Save sizing + layout + modules, restart polybar", btn)]),
    ])


def dunst_page(cfg):
    font   = make_entry(cfg.get("dunst_font",""), 260)
    transp = make_spin(cfg.get("dunst_transparency","0"),  0, 100)
    corner = make_spin(cfg.get("dunst_corner_radius","0"), 0,  50)
    offset = make_entry(cfg.get("dunst_offset",""), 130)
    border = make_spin(cfg.get("dunst_border","0"), 0, 20)
    icons  = make_entry(cfg.get("dunst_icon_theme",""), 200)

    origins   = ["top-left","top-center","top-right","bottom-left","bottom-center","bottom-right"]
    c_presets = ["fly-out","slide-out","fade-out","none"]
    o_presets = ["fly-in","slide-in","fade-in","none"]
    dirs      = ["up","down","left","right"]

    orig  = make_combo(origins,   cfg.get("dunst_origin","top-right"))
    c_pre = make_combo(c_presets, cfg.get("dunst_close_preset","fly-out"))
    o_pre = make_combo(o_presets, cfg.get("dunst_open_preset","fly-in"))
    c_dir = make_combo(dirs,      cfg.get("dunst_close_direction","up"))
    o_dir = make_combo(dirs,      cfg.get("dunst_open_direction","right"))

    btn = apply_btn()
    def apply(btn):
        cfg.set("dunst_font",            font.get_text())
        cfg.set("dunst_transparency",    str(int(transp.get_value())))
        cfg.set("dunst_corner_radius",   str(int(corner.get_value())))
        cfg.set("dunst_offset",          offset.get_text())
        cfg.set("dunst_border",          str(int(border.get_value())))
        cfg.set("dunst_icon_theme",      icons.get_text())
        cfg.set("dunst_origin",          orig.get_active_text())
        cfg.set("dunst_close_preset",    c_pre.get_active_text())
        cfg.set("dunst_close_direction", c_dir.get_active_text())
        cfg.set("dunst_open_preset",     o_pre.get_active_text())
        cfg.set("dunst_open_direction",  o_dir.get_active_text())
        cfg.save(); run_module("08-dunst.sh"); flash_btn(btn, "✓ Applied!"); notify("Dunst applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("Dunst", "Notification daemon settings.", [
        make_group("Appearance", [
            make_row("Font",          font),
            make_row("Icon Theme",    icons),
            make_row("Transparency",  transp),
            make_row("Corner Radius", corner),
            make_row("Border Width",  border),
            make_row("Offset",        offset, "e.g. (28, 65)"),
            make_row("Origin",        orig),
        ]),
        make_group("Animations", [
            make_row("Close Preset",    c_pre),
            make_row("Close Direction", c_dir),
            make_row("Open Preset",     o_pre),
            make_row("Open Direction",  o_dir),
        ]),
        make_group("", [make_row("Restart dunst", btn)]),
    ])


def wallpaper_page(cfg):
    engines = ["Random","CustomDir","Default","Animated","Slideshow"]
    eng     = make_combo(engines, cfg.get("ENGINE","Default"))
    default = make_entry(cfg.get("DEFAULT_WALL",""),  240)
    anim    = make_entry(cfg.get("ANIMATED_WALL",""), 240)
    custom  = make_entry(cfg.get("CUSTOM_DIR",""),    240)

    btn = apply_btn()
    def apply(btn):
        cfg.set("ENGINE",        eng.get_active_text())
        cfg.set("DEFAULT_WALL",  default.get_text())
        cfg.set("ANIMATED_WALL", anim.get_text())
        cfg.set("CUSTOM_DIR",    custom.get_text())
        cfg.save(); run_module("06-wallpaper.sh"); flash_btn(btn, "✓ Applied!"); notify("Wallpaper applied.")
    btn.connect("clicked", safe_apply(apply))

    # We need a parent window reference for the file dialogs; pass None for now
    # (the buttons will call get_toplevel() on the entry widget to find it)
    def browse_file_for(entry):
        b = browse_btn()
        def on_click(_b):
            dlg = Gtk.FileChooserDialog(
                title="Select File",
                transient_for=entry.get_toplevel(),
                action=Gtk.FileChooserAction.OPEN)
            dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                            Gtk.STOCK_OPEN,   Gtk.ResponseType.OK)
            ff = Gtk.FileFilter()
            ff.set_name("Images & Videos")
            for p in ("*.png","*.jpg","*.jpeg","*.webp","*.gif","*.mp4","*.mkv","*.webm"):
                ff.add_pattern(p)
            dlg.add_filter(ff)
            cur = entry.get_text()
            if cur and os.path.exists(os.path.dirname(cur)):
                dlg.set_current_folder(os.path.dirname(cur))
            if dlg.run() == Gtk.ResponseType.OK:
                entry.set_text(dlg.get_filename())
            dlg.destroy()
        b.connect("clicked", on_click)
        return b

    def browse_dir_for(entry):
        b = browse_btn()
        def on_click(_b):
            dlg = Gtk.FileChooserDialog(
                title="Select Directory",
                transient_for=entry.get_toplevel(),
                action=Gtk.FileChooserAction.SELECT_FOLDER)
            dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                            Gtk.STOCK_OPEN,   Gtk.ResponseType.OK)
            cur = entry.get_text()
            if cur and os.path.isdir(cur):
                dlg.set_current_folder(cur)
            if dlg.run() == Gtk.ResponseType.OK:
                entry.set_text(dlg.get_filename())
            dlg.destroy()
        b.connect("clicked", on_click)
        return b

    def path_box(entry, browse_widget):
        b = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6,
                    valign=Gtk.Align.CENTER)
        b.pack_start(entry, True, True, 0)
        b.pack_start(browse_widget, False, False, 0)
        return b

    return page_wrap("Wallpaper", "Wallpaper engine and file paths.", [
        make_group("Wallpaper Engine", [
            make_row("Engine", eng, "How to set the wallpaper"),
            make_row("Default Wallpaper",  path_box(default, browse_file_for(default)),
                     "Path to static image"),
            make_row("Animated Wallpaper", path_box(anim,    browse_file_for(anim)),
                     "Path to video / gif"),
            make_row("Custom Directory",   path_box(custom,  browse_dir_for(custom)),
                     "Folder used by CustomDir / Slideshow engines"),
        ]),
        make_group("", [make_row("Apply wallpaper now", btn)]),
    ])


def gtk_page(cfg):
    theme  = make_entry(cfg.get("gtk_theme",""),  200)
    icons  = make_entry(cfg.get("gtk_icons",""),  200)
    cursor = make_entry(cfg.get("gtk_cursor",""), 200)

    btn = apply_btn()
    def apply(btn):
        cfg.set("gtk_theme",  theme.get_text())
        cfg.set("gtk_icons",  icons.get_text())
        cfg.set("gtk_cursor", cursor.get_text())
        cfg.save(); run_module("05-gtk.sh"); flash_btn(btn, "✓ Applied!"); notify("GTK theme applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("GTK", "GTK theme, icons and cursor.", [
        make_group("Appearance", [
            make_row("GTK Theme",  theme),
            make_row("Icon Theme", icons),
            make_row("Cursor",     cursor),
        ]),
        make_group("", [make_row("Apply GTK theme", btn)]),
    ])


def terminal_page(cfg):
    """Terminal page: own color section + font + scrollback settings."""

    # ── Font ──────────────────────────────────────────────────────────────────
    font = make_entry(cfg.get("term_font_name",""), 220)
    size = make_spin(cfg.get("term_font_size","11"), 6, 32)

    # ── Scrollback (alacritty.toml [scrolling]) ────────────────────────────
    history    = make_spin(alacritty_scroll_get("history",    "10000"), 0, 100000, 1000)
    multiplier = make_spin(alacritty_scroll_get("multiplier", "3"),     1, 20)

    # ── Terminal Colors ────────────────────────────────────────────────────
    # Same vars as Colors page — but applied only to terminals
    tc = {}
    def trow(key, label):
        sw = ColorSwatch(cfg.get(key, "#000000"))
        tc[key] = sw
        return make_row(label, sw)

    # ── Buttons ───────────────────────────────────────────────────────────
    btn = apply_btn("Apply Terminal")
    def apply(btn):
        # Font
        cfg.set("term_font_name", font.get_text())
        cfg.set("term_font_size", str(int(size.get_value())))
        # Colors
        for k, sw in tc.items():
            cfg.set(k, sw.get_hex())
        cfg.save()
        # Scrollback in alacritty.toml
        alacritty_scroll_set("history",    str(int(history.get_value())))
        alacritty_scroll_set("multiplier", str(int(multiplier.get_value())))
        # Run terminal modules
        for m in ("03-alacritty.sh","04-st.sh","14-kitty.sh"):
            run_module(m)
        flash_btn(btn, "✓ Applied!")
        notify("Terminal settings applied.")
    btn.connect("clicked", safe_apply(apply))

    return page_wrap("Terminal", "Font, colors and scrollback for all terminals.", [
        make_group("Font", [
            make_row("Font Name", font),
            make_row("Font Size", size),
        ]),
        make_group("Scrollback  ( Alacritty )", [
            make_row("History Lines",    history,    "Lines kept in scrollback buffer (0 = unlimited)"),
            make_row("Scroll Multiplier", multiplier, "Mouse-wheel scroll speed"),
        ]),
        make_group("Colors — Background / Foreground", [
            trow("bg",           "Background"),
            trow("fg",           "Foreground"),
            trow("accent_color", "Accent"),
        ]),
        make_group("Colors — Normal Palette", [
            trow("black","Black"), trow("red","Red"), trow("green","Green"),
            trow("yellow","Yellow"), trow("blue","Blue"), trow("magenta","Magenta"),
            trow("cyan","Cyan"), trow("white","White"),
        ]),
        make_group("Colors — Bright Palette", [
            trow("blackb","Bright Black"), trow("redb","Bright Red"),
            trow("greenb","Bright Green"), trow("yellowb","Bright Yellow"),
            trow("blueb","Bright Blue"), trow("magentab","Bright Magenta"),
            trow("cyanb","Bright Cyan"), trow("whiteb","Bright White"),
        ]),
        make_group("", [make_row("Apply font + colors + scrollback to all terminals", btn)]),
    ])


def keybinds_page(_cfg):
    """
    GUI keybind editor.
    Each binding shows:  [action label]  [keybind entry]  [⌨ capture button]
    Grouped by section, each section in its own card.
    """
    entries, orig_lines = parse_sxhkdrc(SXHKDRC)

    # row_data[i] → {'entry': dict, 'kb_widget': Entry}  or None for section rows
    row_data    = []
    groups_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)

    current_rows  = []
    current_title = ""

    def flush_section(title, rows):
        if not rows:
            return
        grp_lbl = Gtk.Label(
            label=(title.upper() if title else "GENERAL"), xalign=0)
        grp_lbl.get_style_context().add_class("group-lbl")

        lb = Gtk.ListBox()
        lb.set_selection_mode(Gtk.SelectionMode.NONE)
        lb.get_style_context().add_class("card-list")
        for row_box in rows:
            lb.add(row_box)

        card = Gtk.Frame()
        card.get_style_context().add_class("card")
        card.set_shadow_type(Gtk.ShadowType.NONE)
        card.add(lb)

        vb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vb.pack_start(grp_lbl, False, False, 0)
        vb.pack_start(card,    False, False, 0)
        groups_vbox.pack_start(vb, False, False, 0)

    for entry in entries:
        if entry['type'] == 'section':
            flush_section(current_title, current_rows)
            current_title = entry['title']
            current_rows  = []
            row_data.append(None)
            continue

        # ── Row: [label] [keybind entry] [capture btn] ─────────────────
        row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row_box.set_margin_top(9);  row_box.set_margin_bottom(9)
        row_box.set_margin_start(14); row_box.set_margin_end(14)

        act_lbl = Gtk.Label(label=entry['label'], xalign=0)
        act_lbl.set_hexpand(True)
        act_lbl.get_style_context().add_class("row-lbl")
        act_lbl.set_max_width_chars(36)
        act_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        act_lbl.set_tooltip_text(entry['command'])   # full command on hover

        kb_entry = Gtk.Entry(
            text=entry['keybind'],
            width_request=210,
            valign=Gtk.Align.CENTER)
        kb_entry.get_style_context().add_class("kbd-entry")

        cap_btn = Gtk.Button(label="⌨", valign=Gtk.Align.CENTER)
        cap_btn.get_style_context().add_class("capture-btn")
        cap_btn.set_tooltip_text("Click then press your key combo")
        setup_key_capture(cap_btn, kb_entry)

        row_box.pack_start(act_lbl,  True,  True,  0)
        row_box.pack_start(kb_entry, False, False, 0)
        row_box.pack_start(cap_btn,  False, False, 0)

        current_rows.append(row_box)
        row_data.append({'entry': entry, 'kb_widget': kb_entry})

    flush_section(current_title, current_rows)   # flush last section

    # ── Save button ────────────────────────────────────────────────────────
    save_btn = apply_btn("Save & Reload sxhkd")

    def save(btn):
        if not orig_lines:
            flash_btn(btn, "✗ No file!"); return
        new_lines = list(orig_lines)
        for rd in row_data:
            if rd is None: continue
            line_idx = rd['entry']['keybind_line']
            if 0 <= line_idx < len(new_lines):
                new_lines[line_idx] = rd['kb_widget'].get_text().strip() + '\n'
        with open(SXHKDRC, 'w') as f:
            f.writelines(new_lines)
        # Use absolute path for pkill — bypasses junest wrappers, finds host sxhkd
        subprocess.Popen(["/usr/bin/pkill", "-USR1", "-x", "sxhkd"])
        flash_btn(btn, "✓ Saved & Reloaded!")
        notify("Keybinds saved and sxhkd reloaded.")

    save_btn.connect("clicked", safe_apply(save))

    btn_box = Gtk.Box(halign=Gtk.Align.END)
    btn_box.set_margin_top(6)
    btn_box.pack_start(save_btn, False, False, 0)

    note = Gtk.Label(
        label="Click ⌨ then press your desired combo to capture it.  "
              "Hover an action label to see its command.",
        xalign=0, wrap=True)
    note.get_style_context().add_class("row-sub")
    note.set_margin_bottom(16)

    return page_wrap(
        "Keybinds",
        SXHKDRC,
        [note, groups_vbox, btn_box],
    )

# ── Sidebar nav ───────────────────────────────────────────────────────────────

PAGES = [
    ("●", "Colors",    colors_page),
    ("▣", "Borders",   borders_page),
    ("✦", "Picom",     picom_page),
    ("▬", "Bar",       bar_page),
    ("◆", "Dunst",     dunst_page),
    ("◈", "Wallpaper", wallpaper_page),
    ("◉", "GTK",       gtk_page),
    ("▶", "Terminal",  terminal_page),
    ("⌨", "Keybinds",  keybinds_page),
]

def nav_button(icon, label):
    btn = Gtk.Button()
    btn.set_relief(Gtk.ReliefStyle.NONE)
    btn.get_style_context().add_class("nav-btn")
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    ico = Gtk.Label(label=icon)
    ico.get_style_context().add_class("nav-icon")
    ico.set_width_chars(2)
    lbl = Gtk.Label(label=label, xalign=0)
    lbl.get_style_context().add_class("nav-label")
    lbl.set_hexpand(True)
    box.pack_start(ico, False, False, 0)
    box.pack_start(lbl, True,  True,  0)
    btn.add(box)
    return btn

# ── Window ────────────────────────────────────────────────────────────────────

def build_window(cfg):
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    win = Gtk.Window(title="Rice Settings")
    win.set_default_size(980, 700)
    win.connect("destroy", Gtk.main_quit)

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

    # Topbar
    topbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    topbar.get_style_context().add_class("topbar")
    topbar.set_margin_start(18); topbar.set_margin_end(18)
    info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
    info.set_hexpand(True); info.set_valign(Gtk.Align.CENTER)
    t1 = Gtk.Label(label="Rice Settings", xalign=0)
    t1.get_style_context().add_class("topbar-title")
    t2 = Gtk.Label(label="SaruM4N3", xalign=0)
    t2.get_style_context().add_class("topbar-sub")
    info.pack_start(t1, False, False, 0)
    info.pack_start(t2, False, False, 0)
    close = Gtk.Button(label="✕")
    close.get_style_context().add_class("close-btn")
    close.set_valign(Gtk.Align.CENTER)
    close.connect("clicked", lambda _: win.destroy())
    topbar.pack_start(info,  True,  True,  0)
    topbar.pack_end(close,   False, False, 0)
    root.pack_start(topbar, False, False, 0)
    root.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 0)

    # Body
    body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    body.set_vexpand(True)

    sb_scroll = Gtk.ScrolledWindow()
    sb_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    sb_scroll.set_size_request(210, -1)
    sb_scroll.set_hexpand(False); sb_scroll.set_vexpand(True)
    sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    sidebar.get_style_context().add_class("sidebar")
    sidebar.set_hexpand(False)
    sb_scroll.add(sidebar)

    stack = Gtk.Stack()
    stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
    stack.set_transition_duration(150)
    stack.set_hexpand(True); stack.set_vexpand(True)

    sl = Gtk.Label(label="SETTINGS", xalign=0)
    sl.get_style_context().add_class("section-lbl")
    sidebar.pack_start(sl, False, False, 0)

    buttons = []

    def switch_page(btn, name):
        stack.set_visible_child_name(name)
        for b in buttons:
            b.get_style_context().remove_class("active")
        btn.get_style_context().add_class("active")

    for icon, label, builder in PAGES:
        stack.add_named(builder(cfg), label.lower())
        btn = nav_button(icon, label)
        btn.connect("clicked", switch_page, label.lower())
        sidebar.pack_start(btn, False, False, 0)
        buttons.append(btn)

    if buttons:
        buttons[0].get_style_context().add_class("active")

    body.pack_start(sb_scroll, False, False, 0)
    body.pack_start(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL), False, False, 0)
    body.pack_start(stack, True, True, 0)
    root.pack_start(body, True, True, 0)
    win.add(root)
    return win

def main():
    cfg = ThemeConfig(THEME_CFG)
    win = build_window(cfg)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
