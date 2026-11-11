#!/usr/bin/python3
"""Graphical front-end of install.sh (GTK 3 + VTE, runs on the host python3).

It asks the questions of install.sh / install_prerequisites_pacman.sh, writes
the answers to ~/.cache/bspwm-install-answers, then runs
`install.sh --answers <file>` in an embedded terminal. Both scripts append
progress lines ("step N title", "info msg", "warn msg", "done") to
$BSPWM_STATUS, which drives the progress bar.

Usage (normally started by install.sh): install_gui.py [--update|--fresh]
Kept compatible with Ubuntu 22.04: python 3.10, GTK 3.24, VTE 0.68.
"""

import os
import shlex
import shutil
import signal
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Vte", "2.91")
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Pango, Vte  # noqa: E402

HOME = os.path.expanduser("~")
REPO = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
JUNEST_BIN = os.path.join(HOME, ".local/share/junest/bin/junest")
ANSWERS = os.path.join(HOME, ".cache/bspwm-install-answers")
STATUS = os.path.join(HOME, ".cache/bspwm-install-status")
SAVED_CHOICES = os.path.join(HOME, ".local/state/bspwm/install-choices")
LOG_DIR = os.path.join(HOME, ".BspwmLogs")

TERMINALS = [("alacritty", "Alacritty", "Fast, GPU rendered (default)"),
             ("kitty", "kitty", "GPU rendered, tabs and images")]
EDITORS = [("micro", "micro", "Terminal, simple keybinds (already included)"),
           ("neovim", "Neovim", "Terminal, vim keybinds"),
           ("vscode", "VS Code", "visual-studio-code-bin"),
           ("zed", "Zed", "GUI, zed-preview-bin")]
BROWSERS = [("brave", "Brave", "Default"),
            ("firefox", "Firefox", ""),
            ("chromium", "Chromium", ""),
            ("google-chrome", "Google Chrome", "")]
# install-choices values (binary names) -> answers above
EDITOR_FROM_BIN = {"micro": "micro", "nvim": "neovim", "code": "vscode", "zed": "zed"}
BROWSER_FROM_BIN = {"brave": "brave", "firefox": "firefox", "chromium": "chromium",
                    "google-chrome-stable": "google-chrome"}

CSS = b"""
.title { font-size: 20px; font-weight: bold; }
.subtitle { opacity: 0.7; }
.section { font-weight: bold; font-size: 14px; margin-top: 6px; }
.card, .card:hover, .card:checked, .card:active {
        border: 1px solid alpha(@theme_fg_color, 0.15); border-radius: 10px; padding: 12px;
        background-image: none; box-shadow: none; text-shadow: none;
        background-color: alpha(@theme_fg_color, 0.03); color: @theme_fg_color; }
.card label, .card:checked label { color: @theme_fg_color; }
.card:hover { background-color: alpha(@theme_fg_color, 0.07); }
.card:checked { border: 2px solid @theme_selected_bg_color;
                background-color: alpha(@theme_selected_bg_color, 0.18); }
.danger { color: #e06c75; }
.ok { color: #98c379; }
.warnbox { border-radius: 8px; padding: 10px; background-color: alpha(#e5c07b, 0.15); }
.errbox { border-radius: 8px; padding: 10px; background-color: alpha(#e06c75, 0.15); }
.dot { min-width: 10px; min-height: 10px; border-radius: 5px;
       background-color: alpha(currentColor, 0.2); }
.dot.active { background-color: @theme_selected_bg_color; }
.mono { font-family: monospace; }
"""


DEMO = r"""
s() { printf '%s\n' "$*" >> "$BSPWM_STATUS"; }
echo -e "\033[1;32m[+]\033[0m demo run, nothing is installed"
for n in 1 2 3 4 5 6 7; do
    s "step $n Demo step $n"; echo -e "\033[1;32m[+]\033[0m Step $n/7"
    for i in 1 2 3 4 5 6 7 8 9 10; do s "info line $i of step $n"; echo "  line $i"; sleep 0.1; done
done
s done
"""


def run(cmd, timeout=10):
    """Output of a command, "" on any failure."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                              check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def read_shell_vars(path):
    """KEY=value lines written by bash printf %q (simple values only)."""
    out = {}
    try:
        with open(path) as f:
            for line in f:
                key, sep, val = line.strip().partition("=")
                if sep and key.isidentifier():
                    try:
                        out[key] = " ".join(shlex.split(val))
                    except ValueError:
                        pass
    except OSError:
        pass
    return out


class State:
    """What is already on this PC."""

    def __init__(self):
        self.config = os.path.isdir(os.path.join(HOME, ".config/bspwm"))
        self.junest = os.path.isfile(os.path.join(HOME, ".junest/usr/bin/pacman"))
        self.installed = self.config and self.junest and os.access(JUNEST_BIN, os.X_OK)
        self.zshrc_mine = os.path.isfile(os.path.join(HOME, ".zshrc.bak"))
        self.free_gb = shutil.disk_usage(HOME).free // (1024 ** 3)
        self.saved = read_shell_vars(SAVED_CHOICES)
        self.bspwm_running = bool(run(["pgrep", "-x", "bspwm"]))
        self.in_junest = bool(os.environ.get("JUNEST_ENV"))
        self.commit = run(["git", "-C", REPO, "log", "-1", "--format=%h — %s (%cr)"])
        self.upstream = bool(run(["git", "-C", REPO, "rev-parse", "--abbrev-ref", "@{u}"]))
        self.behind = None  # filled by fetch_upstream()
        rices_dir = os.path.join(REPO, ".config/bspwm/rices")
        try:
            self.rices = sorted(d for d in os.listdir(rices_dir)
                                if os.path.isfile(os.path.join(rices_dir, d, "theme-config.bash")))
        except OSError:
            self.rices = []
        self.rices_dir = rices_dir

    def fetch_upstream(self):
        """Commits on GitHub not pulled yet (None = unknown)."""
        if not self.upstream:
            return
        try:
            subprocess.run(["git", "-C", REPO, "fetch", "--quiet"], capture_output=True,
                           timeout=15, check=True)
        except (OSError, subprocess.SubprocessError):
            return
        n = run(["git", "-C", REPO, "rev-list", "--count", "HEAD..@{u}"])
        self.behind = int(n) if n.isdigit() else None


def label(text, css=None, wrap=True, xalign=0.0, markup=False):
    w = Gtk.Label()
    if markup:
        w.set_markup(text)
    else:
        w.set_text(text)
    w.set_xalign(xalign)
    w.set_line_wrap(wrap)
    if wrap:
        w.set_max_width_chars(70)
    if css:
        for c in css.split():
            w.get_style_context().add_class(c)
    return w


def card_radio(group, title, desc, extra=None):
    """Radio button drawn as a card: bold title + description."""
    rb = Gtk.RadioButton.new_from_widget(group)
    rb.set_mode(False)  # a toggle button, styled by .card
    rb.get_style_context().add_class("card")
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    box.pack_start(label(f"<b>{GLib.markup_escape_text(title)}</b>", markup=True), False, False, 0)
    if desc:
        box.pack_start(label(desc, "subtitle"), False, False, 0)
    if extra:
        box.pack_start(extra, False, False, 4)
    rb.add(box)
    return rb


class Installer(Gtk.Window):
    def __init__(self, argv):
        super().__init__(title="bspwm installer")
        self.set_default_size(860, 640)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("delete-event", self.on_close)

        self.st = State()
        self.child_pid = None
        self.running = False
        self.finished = False
        self.stopped = False
        self.status_pos = 0
        self.step = 0
        self.step1_infos = 0
        # --demo: fake run of the steps, to try the window from anywhere (even inside bspwm)
        self.demo = "--demo" in argv
        self.start_mode = "update" if "--update" in argv or "-u" in argv else \
            "fresh" if "--fresh" in argv or "-f" in argv else None

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(outer)

        # Header: title + page dots
        head = Gtk.Box(spacing=12, margin=18, margin_bottom=6)
        tbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.title_lbl = label("", "title", wrap=False)
        self.sub_lbl = label("", "subtitle")
        tbox.pack_start(self.title_lbl, False, False, 0)
        tbox.pack_start(self.sub_lbl, False, False, 0)
        head.pack_start(tbox, True, True, 0)
        self.dots_box = Gtk.Box(spacing=6, valign=Gtk.Align.CENTER)
        head.pack_end(self.dots_box, False, False, 0)
        outer.pack_start(head, False, False, 0)
        outer.pack_start(Gtk.Separator(), False, False, 0)

        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
                               transition_duration=180)
        outer.pack_start(self.stack, True, True, 0)

        outer.pack_start(Gtk.Separator(), False, False, 0)
        bar = Gtk.Box(spacing=8, margin=12)
        self.back_btn = Gtk.Button(label="Back")
        self.back_btn.connect("clicked", lambda *_: self.go(-1))
        self.next_btn = Gtk.Button(label="Next")
        self.next_btn.get_style_context().add_class("suggested-action")
        self.next_btn.connect("clicked", lambda *_: self.go(1))
        self.cancel_btn = Gtk.Button(label="Quit")
        self.cancel_btn.connect("clicked", lambda *_: self.on_close())
        bar.pack_start(self.cancel_btn, False, False, 0)
        bar.pack_end(self.next_btn, False, False, 0)
        bar.pack_end(self.back_btn, False, False, 0)
        outer.pack_start(bar, False, False, 0)

        if (self.st.in_junest or self.st.bspwm_running) and not self.demo:
            self.build_blocked()
            return
        self.build_mode_page()
        self.build_apps_page()
        self.build_options_page()
        self.build_summary_page()
        self.build_run_page()
        self.pages = []
        self.page_i = 0
        self.refresh_pages()
        self.show_page()
        if self.st.upstream:
            threading.Thread(target=self.fetch_thread, daemon=True).start()

    # ── Pages ────────────────────────────────────────────────────────────────
    def scroll_page(self, name):
        # Centred column, so wide screens don't stretch the cards across
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=24,
                      halign=Gtk.Align.CENTER)
        box.set_size_request(780, -1)
        sw = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        sw.add(box)
        self.stack.add_named(sw, name)
        return box

    def build_blocked(self):
        box = self.scroll_page("blocked")
        self.title_lbl.set_text("Can't install from here")
        if self.st.in_junest:
            msg = "This window runs inside bspwm (junest). Go back to GNOME and run install.sh from a GNOME terminal."
        else:
            msg = "bspwm is running. Quit it first (back to GNOME), then start the installer again."
        box.pack_start(label(msg, "errbox"), False, False, 0)
        self.back_btn.hide()
        self.next_btn.hide()
        self.show_all()
        self.back_btn.hide()
        self.next_btn.hide()

    def build_mode_page(self):
        box = self.scroll_page("mode")
        st = self.st
        # What is on this PC
        facts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        facts.get_style_context().add_class("card")
        if st.installed:
            facts.pack_start(label("✓ bspwm is installed on this account", "ok"), False, False, 0)
        elif st.config:
            facts.pack_start(label("• A bspwm config exists, but no junest: a full install is needed"), False, False, 0)
        else:
            facts.pack_start(label("• bspwm is not installed yet"), False, False, 0)
        facts.pack_start(label(f"• Free space in your home: {st.free_gb} GB"), False, False, 0)
        if st.commit:
            facts.pack_start(label(f"• Dotfiles version: {st.commit}"), False, False, 0)
        self.upstream_lbl = label("• Checking GitHub for a newer version…" if st.upstream else "")
        facts.pack_start(self.upstream_lbl, False, False, 0)
        box.pack_start(facts, False, False, 0)

        box.pack_start(label("What do you want to do?", "section"), False, False, 0)
        self.rb_update = card_radio(None, "Update",
                                    "New version of the dotfiles and scripts. Your Rice Settings, keybinds, "
                                    "picom, wallpaper and choices stay as they are; only the packages the "
                                    "new version needs are installed (a few minutes).")
        self.rb_full = card_radio(self.rb_update, "Full install",
                                  "junest + all the packages, then the dotfiles. About 7 GB and "
                                  "20-40 minutes the first time." if not st.junest else
                                  "Packages upgraded and checked, apps chosen again, dotfiles redeployed.")
        self.wipe_cb = Gtk.CheckButton(label="Also wipe the junest Arch environment (~/.junest): "
                                             "packages you installed yourself with pacman are lost too")
        self.wipe_cb.get_style_context().add_class("danger")
        self.wipe_cb.set_sensitive(False)
        self.rb_fresh = card_radio(self.rb_update, "Fresh reinstall",
                                   "Like a full install, but ~/.bspwminstaller (and ~/.oh-my-zsh if this "
                                   "installer put it there) is rebuilt from scratch instead of upgraded in place.", self.wipe_cb)
        self.rb_uninstall = card_radio(self.rb_update, "Uninstall everything",
                                       "Removes the packages, configs, junest and the GNOME shortcut. "
                                       "This repository is kept.")
        for rb in (self.rb_update, self.rb_full, self.rb_fresh, self.rb_uninstall):
            box.pack_start(rb, False, False, 0)
            rb.connect("toggled", self.on_mode_changed)
        if not st.installed:
            self.rb_update.set_sensitive(False)
            self.rb_update.set_tooltip_text("Nothing to update: no install found (junest + ~/.config/bspwm)")
        if not (st.installed or st.junest or st.config):
            self.rb_uninstall.set_sensitive(False)
        if self.start_mode == "fresh":
            self.rb_fresh.set_active(True)
        elif st.installed and self.start_mode != "full":
            self.rb_update.set_active(True)
        else:
            self.rb_full.set_active(True)

    def choice_group(self, box, title, items, selected):
        box.pack_start(label(title, "section"), False, False, 0)
        flow = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, column_spacing=8,
                           row_spacing=8, homogeneous=True, max_children_per_line=4)
        group = None
        buttons = {}
        for key, name, desc in items:
            rb = card_radio(group, name, desc)
            group = group or rb
            buttons[key] = rb
            flow.add(rb)
        (buttons.get(selected) or group).set_active(True)
        box.pack_start(flow, False, False, 0)
        return buttons

    def build_apps_page(self):
        box = self.scroll_page("apps")
        saved = self.st.saved
        self.term_btns = self.choice_group(box, "Terminal", TERMINALS, saved.get("TERM_BIN"))
        self.editor_btns = self.choice_group(box, "Editor (Super+E)", EDITORS,
                                             EDITOR_FROM_BIN.get(saved.get("EDITOR_BIN")))
        self.browser_btns = self.choice_group(box, "Browser (Super+W)", BROWSERS,
                                              BROWSER_FROM_BIN.get(saved.get("BROWSER_BIN")))

        box.pack_start(label("Rice", "section"), False, False, 0)
        self.rice_cbs = {}
        flow = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, column_spacing=12,
                           row_spacing=12, max_children_per_line=3)
        for rice in self.st.rices:
            vb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            img = self.rice_preview(rice)
            if img:
                vb.pack_start(img, False, False, 0)
            cb = Gtk.CheckButton(label=rice, active=True)
            cb.connect("toggled", lambda *_: self.update_active_rice())
            if len(self.st.rices) == 1:
                cb.set_sensitive(False)
            self.rice_cbs[rice] = cb
            vb.pack_start(cb, False, False, 0)
            vb.get_style_context().add_class("card")
            flow.add(vb)
        box.pack_start(flow, False, False, 0)
        self.active_rice = Gtk.ComboBoxText()
        self.active_row = Gtk.Box(spacing=8)
        self.active_row.pack_start(label("Active rice:", wrap=False), False, False, 0)
        self.active_row.pack_start(self.active_rice, False, False, 0)
        box.pack_start(self.active_row, False, False, 0)
        self.update_active_rice()

    def rice_preview(self, rice):
        path = os.path.join(self.st.rices_dir, rice, "preview.webp")
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 220, 290, True)
        except GLib.Error:
            # Ubuntu's gdk-pixbuf has no webp loader by default
            return label("(no preview: webp images not supported here)", "subtitle")
        return Gtk.Image.new_from_pixbuf(pb)

    def update_active_rice(self):
        cur = self.active_rice.get_active_text()
        self.active_rice.remove_all()
        chosen = [r for r, cb in self.rice_cbs.items() if cb.get_active()]
        for r in chosen:
            self.active_rice.append_text(r)
        if chosen:
            self.active_rice.set_active(chosen.index(cur) if cur in chosen else 0)
        if hasattr(self, "next_btn") and self.stack.get_visible_child_name() == "apps":
            self.next_btn.set_sensitive(bool(chosen))
        self.active_row.set_visible(len(self.st.rices) > 1)

    def build_options_page(self):
        box = self.scroll_page("options")
        self.zsh_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.zsh_box.pack_start(label("zsh config inside bspwm", "section"), False, False, 0)
        self.rb_zsh_mine = card_radio(None, "Use the bspwm one",
                                      "Prompt, fzf-tab, aliases of these dotfiles inside bspwm. "
                                      "Your ~/.zshrc stays as it is in GNOME.")
        self.rb_zsh_keep = card_radio(self.rb_zsh_mine, "Keep my own ~/.zshrc everywhere",
                                      "bspwm uses your zsh config too.")
        (self.rb_zsh_mine if self.st.zshrc_mine or not self.st.config else self.rb_zsh_keep).set_active(True)
        self.zsh_box.pack_start(self.rb_zsh_mine, False, False, 0)
        self.zsh_box.pack_start(self.rb_zsh_keep, False, False, 0)
        box.pack_start(self.zsh_box, False, False, 0)

        self.keep_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.keep_box.pack_start(label("Your current bspwm settings", "section"), False, False, 0)
        self.rb_keep = card_radio(None, "Keep them",
                                  "Rice Settings, keybinds, picom, wallpaper, mouse… are restored "
                                  "after the new dotfiles are deployed.")
        self.rb_reset = card_radio(self.rb_keep, "Back to the defaults",
                                   "Your old config stays in ~/.config-backup-<date>.")
        self.keep_box.pack_start(self.rb_keep, False, False, 0)
        self.keep_box.pack_start(self.rb_reset, False, False, 0)
        box.pack_start(self.keep_box, False, False, 0)

        self.pull_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.pull_box.pack_start(label("Version", "section"), False, False, 0)
        self.pull_cb = Gtk.CheckButton(label="Download the latest version from GitHub first (git pull)",
                                       active=True)
        self.pull_box.pack_start(self.pull_cb, False, False, 0)
        box.pack_start(self.pull_box, False, False, 0)

    def build_summary_page(self):
        box = self.scroll_page("summary")
        self.summary_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.summary_box.get_style_context().add_class("card")
        box.pack_start(self.summary_box, False, False, 0)
        self.space_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.space_box.get_style_context().add_class("warnbox")
        self.space_lbl = label("")
        self.space_cb = Gtk.CheckButton(label="Continue anyway")
        self.space_cb.connect("toggled", lambda *_: self.next_btn.set_sensitive(self.space_cb.get_active()))
        self.space_box.pack_start(self.space_lbl, False, False, 0)
        self.space_box.pack_start(self.space_cb, False, False, 0)
        box.pack_start(self.space_box, False, False, 0)
        box.pack_start(label("The install runs in a terminal on the next page: if it ever asks something, "
                             "click in it and type the answer.", "subtitle"), False, False, 0)

    def build_run_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin=18)
        self.stack.add_named(box, "run")
        self.progress = Gtk.ProgressBar(show_text=False)
        self.step_lbl = label("", "section", wrap=False)
        self.step_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        self.info_lbl = label("", "subtitle mono", wrap=False)
        self.info_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        box.pack_start(self.step_lbl, False, False, 0)
        box.pack_start(self.progress, False, False, 0)
        box.pack_start(self.info_lbl, False, False, 0)
        self.result_lbl = label("", wrap=True)
        self.result_lbl.set_no_show_all(True)
        box.pack_start(self.result_lbl, False, False, 0)

        self.term = Vte.Terminal()
        self.term.set_scrollback_lines(-1)
        self.term.set_font(Pango.FontDescription("Monospace 10"))
        self.term.connect("child-exited", self.on_child_exited)
        fg, bg = Gdk.RGBA(), Gdk.RGBA()
        fg.parse("#d8dee9")
        bg.parse("#1e222a")
        pal = []
        for c in ("#3b4252 #e06c75 #98c379 #e5c07b #61afef #c678dd #56b6c2 #d8dee9 "
                  "#4c566a #e06c75 #98c379 #e5c07b #61afef #c678dd #56b6c2 #eceff4").split():
            rgba = Gdk.RGBA()
            rgba.parse(c)
            pal.append(rgba)
        self.term.set_colors(fg, bg, pal)
        frame = Gtk.Frame()
        sw = Gtk.Box()
        sw.pack_start(self.term, True, True, 0)
        sb = Gtk.Scrollbar(orientation=Gtk.Orientation.VERTICAL, adjustment=self.term.get_vadjustment())
        sw.pack_start(sb, False, False, 0)
        frame.add(sw)
        box.pack_start(frame, True, True, 0)

        self.launch_btn = Gtk.Button(label="Launch bspwm now")
        self.launch_btn.get_style_context().add_class("suggested-action")
        self.launch_btn.connect("clicked", self.on_launch)
        self.launch_btn.set_no_show_all(True)

    # ── Navigation ───────────────────────────────────────────────────────────
    def mode(self):
        for name, rb in (("update", self.rb_update), ("full", self.rb_full),
                         ("fresh", self.rb_fresh), ("uninstall", self.rb_uninstall)):
            if rb.get_active():
                return name
        return "full"

    def on_mode_changed(self, *_):
        self.wipe_cb.set_sensitive(self.rb_fresh.get_active())
        if not self.rb_fresh.get_active():
            self.wipe_cb.set_active(False)
        if hasattr(self, "pages"):
            self.refresh_pages()

    def refresh_pages(self):
        m = self.mode()
        if m == "uninstall":
            self.pages = ["mode", "summary", "run"]
        elif m == "update":
            self.pages = ["mode"] + (["options"] if self.st.upstream else []) + ["summary", "run"]
        else:
            self.pages = ["mode", "apps", "options", "summary", "run"]
        self.zsh_box.set_visible(m in ("full", "fresh"))
        self.keep_box.set_visible(m in ("full", "fresh") and self.st.config)
        self.pull_box.set_visible(m == "update" and self.st.upstream)
        self.draw_dots()

    def draw_dots(self):
        for c in self.dots_box.get_children():
            self.dots_box.remove(c)
        for i, _ in enumerate(self.pages):
            d = Gtk.Box()
            d.get_style_context().add_class("dot")
            if i <= self.page_i:
                d.get_style_context().add_class("active")
            self.dots_box.pack_start(d, False, False, 0)
        self.dots_box.show_all()

    def go(self, delta):
        if self.finished:
            Gtk.main_quit()
            return
        nxt = self.page_i + delta
        if self.pages[self.page_i] == "summary" and delta > 0:
            if self.mode() == "uninstall" and not self.confirm(
                    "Uninstall everything?",
                    "Packages, configs, junest and the GNOME shortcut are removed. This can't be undone."):
                return
            self.page_i = nxt
            self.show_page()
            self.start()
            return
        if 0 <= nxt < len(self.pages):
            self.page_i = nxt
            self.show_page()

    def show_page(self):
        name = self.pages[self.page_i]
        m = self.mode()
        titles = {
            "mode": ("bspwm dotfiles", "42 school / junest edition"),
            "apps": ("Apps", "Installed inside junest. You can change them later in Rice Settings or sxhkdrc."),
            "options": ("Options", ""),
            "summary": ("Ready", "Check what is going to happen."),
            "run": ({"update": "Updating…", "uninstall": "Uninstalling…"}.get(m, "Installing…"),
                    "You can keep using the PC meanwhile."),
        }
        t, s = titles[name]
        self.title_lbl.set_text(t)
        self.sub_lbl.set_text(s)
        self.sub_lbl.set_visible(bool(s))
        self.stack.set_visible_child_name(name)
        self.back_btn.set_visible(self.page_i > 0 and name != "run")
        self.next_btn.set_sensitive(True)
        self.next_btn.set_label("Next")
        if name == "apps":
            self.update_active_rice()
        if name == "summary":
            self.fill_summary()
            self.next_btn.set_label({"update": "Update", "uninstall": "Uninstall"}.get(m, "Install"))
            ctx = self.next_btn.get_style_context()
            if m == "uninstall":
                ctx.remove_class("suggested-action")
                ctx.add_class("destructive-action")
            else:
                ctx.remove_class("destructive-action")
                ctx.add_class("suggested-action")
        if name == "run":
            self.next_btn.hide()
            self.cancel_btn.set_label("Stop")
        self.draw_dots()

    def need_gb(self):
        m = self.mode()
        if m in ("update", "uninstall"):
            return 1 if m == "update" else 0
        if self.st.junest and not (m == "fresh" and self.wipe_cb.get_active()):
            return 1
        return 7

    def fill_summary(self):
        for c in self.summary_box.get_children():
            self.summary_box.remove(c)
        m = self.mode()
        lines = []
        if m == "uninstall":
            lines = ["Remove every package installed inside junest, then junest itself (~/.junest)",
                     "Remove the deployed configs (~/.config/bspwm, ~/.bspwminstaller…)",
                     "Remove the GNOME Super+Shift+B shortcut",
                     f"Keep this repository ({REPO})"]
        else:
            if m == "update":
                if self.st.upstream and self.pull_cb.get_active():
                    lines.append("Download the latest version from GitHub (git pull)")
                lines.append("Install only the packages the new version needs (no system upgrade)")
            else:
                if m == "fresh":
                    lines.append("Wipe ~/.bspwminstaller (and ~/.oh-my-zsh if the installer put it there)"
                                 + (", and the junest environment" if self.wipe_cb.get_active() else ""))
                lines.append("Install junest and all the packages" if not self.st.junest or
                             self.wipe_cb.get_active() else "Upgrade junest and install all the packages")
                def name(items, btns):
                    return dict((k, n) for k, n, _ in items)[self.pick(btns)]
                apps = (f"terminal {name(TERMINALS, self.term_btns)}, editor {name(EDITORS, self.editor_btns)}, "
                        f"browser {name(BROWSERS, self.browser_btns)}, rice {self.active_rice.get_active_text()}")
                lines.append("Apps: " + apps)
            lines.append("Back up the current configs to ~/.config-backup-<date> (3 newest kept)")
            keep = m == "update" or (self.st.config and self.rb_keep.get_active())
            lines.append("Deploy the dotfiles" + (", keeping your settings" if keep else " with the default settings"))
            lines.append("Fonts, desktop entries, scripts, GNOME Super+Shift+B shortcut, oh-my-zsh")
            if m != "update":
                lines.append("zsh in bspwm: " + ("the bspwm config" if self.rb_zsh_mine.get_active()
                                                 else "your own ~/.zshrc"))
        for ln in lines:
            self.summary_box.pack_start(label("• " + ln), False, False, 0)
        self.summary_box.show_all()

        need = self.need_gb()
        low = need and self.st.free_gb < need
        self.space_box.set_visible(bool(low))
        if low:
            self.space_lbl.set_text(f"Only {self.st.free_gb} GB free in your home, about {need} GB are needed: "
                                    "pacman could stop half-way. Free some space first "
                                    "(du -sh ~/* ~/.[!.]* | sort -h).")
            self.space_cb.set_active(False)
            GLib.idle_add(lambda: self.next_btn.set_sensitive(False))

    @staticmethod
    def pick(btns):
        for key, rb in btns.items():
            if rb.get_active():
                return key
        return next(iter(btns))

    def fetch_thread(self):
        self.st.fetch_upstream()
        GLib.idle_add(self.show_upstream)

    def show_upstream(self):
        b = self.st.behind
        if b is None:
            self.upstream_lbl.set_text("• Couldn't reach GitHub (no network?)")
        elif b == 0:
            self.upstream_lbl.set_text("• Up to date with GitHub")
        else:
            self.upstream_lbl.set_markup(f"• <b>{b} new commit{'s' if b > 1 else ''} on GitHub</b>: "
                                         "choose Update to get them")
        return False

    # ── Running install.sh ───────────────────────────────────────────────────
    def write_answers(self):
        m = self.mode()
        a = {
            "A_GIT_PULL": "1" if self.pull_cb.get_active() else "0",
            "A_WIPE_JUNEST": "1" if self.wipe_cb.get_active() else "0",
            "A_ZSHRC": "mine" if self.rb_zsh_mine.get_active() else "keep",
            "A_KEEP_SETTINGS": "1" if self.rb_keep.get_active() else "0",
            "A_LOW_SPACE_OK": "1" if self.space_cb.get_active() else "0",
        }
        if m in ("full", "fresh"):
            chosen = [r for r, cb in self.rice_cbs.items() if cb.get_active()]
            active = self.active_rice.get_active_text()
            rices = [active] + [r for r in chosen if r != active] if active else chosen
            a.update(A_TERM=self.pick(self.term_btns), A_EDITOR=self.pick(self.editor_btns),
                     A_BROWSER=self.pick(self.browser_btns), A_RICES=" ".join(rices))
        os.makedirs(os.path.dirname(ANSWERS), exist_ok=True)
        with open(ANSWERS, "w") as f:
            f.write("# bspwm graphical installer answers (removed at the end of the install)\n")
            for k, v in a.items():
                f.write(f"{k}={shlex.quote(v)}\n")

    def start(self):
        m = self.mode()
        open(STATUS, "w").close()
        self.status_pos = 0
        if m == "uninstall":
            argv = ["/bin/bash", os.path.join(REPO, "uninstall_all.sh")]
            self.step_lbl.set_text("Uninstalling…")
        else:
            self.write_answers()
            argv = ["/bin/bash", os.path.join(REPO, "install.sh"), "--answers", ANSWERS]
            if m == "update":
                argv.append("--update")
            elif m == "fresh":
                argv.append("--fresh")
            self.step_lbl.set_text("Starting…")
        if self.demo:
            argv = ["/bin/bash", "-c", DEMO]
        env = dict(os.environ, BSPWM_STATUS=STATUS, UNINSTALL_SKIP_CONFIRM="1")
        envv = [f"{k}={v}" for k, v in env.items()]
        self.running = True
        self.term.spawn_async(Vte.PtyFlags.DEFAULT, REPO, argv, envv, GLib.SpawnFlags.DEFAULT,
                              None, None, -1, None, self.on_spawned)
        GLib.timeout_add(300, self.poll_status)
        self.term.grab_focus()

    def on_spawned(self, term, pid, error, *_):
        if error or pid == -1:
            self.running = False
            self.finish(False, f"Could not start the installer: {error.message if error else '?'}")
            return
        self.child_pid = pid

    def poll_status(self):
        if self.finished:
            return False
        try:
            with open(STATUS) as f:
                f.seek(self.status_pos)
                data = f.read()
                self.status_pos = f.tell()
        except OSError:
            data = ""
        for line in data.splitlines():
            kind, _, msg = line.partition(" ")
            if kind == "step":
                n, _, title = msg.partition(" ")
                self.step = int(n) if n.isdigit() else self.step
                self.step_lbl.set_text(f"Step {self.step}/7 — {title}")
            elif kind in ("info", "warn"):
                if self.step == 1:
                    self.step1_infos += 1
                self.info_lbl.set_text(msg)
            elif kind == "error":
                self.info_lbl.set_text(msg)
        if self.mode() == "uninstall":
            self.progress.pulse()
        else:
            self.progress.set_fraction(self.fraction())
        return self.running

    def fraction(self):
        """Step 1 (packages) is most of a full install."""
        s1 = 0.3 if self.mode() == "update" else 0.75
        if self.step == 0:
            return 0.0
        if self.step == 1:
            # progress lines counted in step 1: ~52 for a full install, ~4 for an update
            n = 5 if self.mode() == "update" else 55
            return s1 * min(0.97, self.step1_infos / n)
        return s1 + (1 - s1) * (self.step - 1) / 7

    def on_child_exited(self, term, status):
        self.running = False
        self.child_pid = None
        try:
            code = os.waitstatus_to_exitcode(status)
        except ValueError:
            code = 1
        self.poll_status()
        if not self.demo:
            self.save_log()
        if code == 0:
            if self.mode() == "uninstall":
                self.finish(True, "bspwm was removed. This repository is still here.")
            else:
                self.finish(True, "Done! Launch bspwm with <b>Super+Shift+B</b> from GNOME, or with the "
                            "button below." + GLib.markup_escape_text(self.sxhkd_note()), markup=True)
        elif self.stopped:
            self.finish(False, "Stopped. Run the installer again later to finish the job: "
                        "the steps already done are quick the second time.")
        else:
            self.finish(False, f"The installer stopped (exit code {code}). The full output is above and in "
                        f"{self.log_path()}. You can run it again: it picks up where it was.")

    def sxhkd_note(self):
        if os.path.isfile(os.path.join(HOME, ".config/bspwm/config/sxhkdrc.new")):
            return ("\nYour keybinds were kept: the new ones of this version are in "
                    "~/.config/bspwm/config/sxhkdrc.new")
        return ""

    def log_path(self):
        return os.path.join(LOG_DIR, "install.log")

    def save_log(self):
        """Terminal text (no colour codes) → ~/.BspwmLogs/install.log (Rice Settings → Logs)."""
        try:
            os.makedirs(LOG_DIR, exist_ok=True)
            f = Gio.File.new_for_path(self.log_path())
            stream = f.replace(None, False, Gio.FileCreateFlags.NONE, None)
            self.term.write_contents_sync(stream, Vte.WriteFlags.DEFAULT, None)
            stream.close(None)
        except GLib.Error:
            pass

    def finish(self, ok, msg, markup=False):
        self.finished = True
        for p in (STATUS, ANSWERS):
            try:
                os.remove(p)
            except OSError:
                pass
        self.progress.set_fraction(1.0 if ok else self.progress.get_fraction())
        self.title_lbl.set_text("Finished" if ok else "Something went wrong")
        self.sub_lbl.hide()
        if ok:
            self.step_lbl.set_text("✓ " + ("Update complete" if self.mode() == "update" else
                                           "Uninstall complete" if self.mode() == "uninstall" else
                                           "Installation complete"))
            self.step_lbl.get_style_context().add_class("ok")
            self.info_lbl.set_text("")
        else:
            self.step_lbl.get_style_context().add_class("danger")
        self.result_lbl.set_markup(msg if markup else GLib.markup_escape_text(msg))
        self.result_lbl.get_style_context().add_class("ok" if ok else "errbox")
        self.result_lbl.show()
        self.cancel_btn.set_label("Close")
        if ok and not self.demo and self.mode() != "uninstall" and os.path.isfile(os.path.join(HOME, ".bspwminstaller/bspwm.sh")):
            bar = self.next_btn.get_parent()
            bar.pack_end(self.launch_btn, False, False, 0)
            self.launch_btn.show()

    def on_launch(self, *_):
        # Detached like the GNOME shortcut: bspwm.sh stops gnome-shell and outlives this window
        subprocess.Popen(["setsid", "-f", os.path.join(HOME, ".bspwminstaller/bspwm.sh")],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         cwd=HOME)
        Gtk.main_quit()

    def confirm(self, title, text):
        d = Gtk.MessageDialog(transient_for=self, modal=True, message_type=Gtk.MessageType.WARNING,
                              buttons=Gtk.ButtonsType.YES_NO, text=title)
        d.format_secondary_text(text)
        r = d.run()
        d.destroy()
        return r == Gtk.ResponseType.YES

    def on_close(self, *_):
        if self.running:
            if not self.confirm("Stop the installer?",
                                "It stops in the middle of a step. Running it again later finishes the job."):
                return True
            self.stopped = True
            if self.child_pid:
                try:
                    os.killpg(os.getpgid(self.child_pid), signal.SIGTERM)
                except OSError:
                    pass
            return True  # child-exited shows the result, then Close quits
        for p in (STATUS, ANSWERS):
            if not self.finished and os.path.exists(p):
                try:
                    os.remove(p)
                except OSError:
                    pass
        Gtk.main_quit()
        return False


def main():
    settings = Gtk.Settings.get_default()
    if settings:
        settings.set_property("gtk-application-prefer-dark-theme", True)
    prov = Gtk.CssProvider()
    prov.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    win = Installer(sys.argv[1:])
    win.show_all()
    if hasattr(win, "pages"):
        win.refresh_pages()
        win.show_page()
    Gtk.main()


if __name__ == "__main__":
    main()
