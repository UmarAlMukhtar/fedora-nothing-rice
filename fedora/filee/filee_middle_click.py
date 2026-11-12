"""Open Filee for the local file middle-clicked in a Nautilus window."""
from pathlib import Path

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
gi.require_version("Nautilus", "4.1")
from gi.repository import Gdk, Gio, GLib, GObject, Gtk, Nautilus


class FileeMiddleClick(GObject.Object, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        self.filee = Path(GLib.get_user_data_dir()) / "filee/application/Filee"
        self.windows = Gtk.Window.get_toplevels()
        self.windows.connect("items-changed", self.attach_windows)
        self.attach_windows(self.windows, 0, 0, self.windows.get_n_items())

    def get_file_items(self, files):
        return []

    def get_background_items(self, folder):
        return []

    def attach_windows(self, windows, start, removed, added):
        for index in range(start, start + added):
            window = windows.get_item(index)
            if window.__gtype__.name != "NautilusWindow" or getattr(window, "_filee_middle_click", False):
                continue
            gesture = Gtk.GestureClick.new()
            gesture.set_button(Gdk.BUTTON_MIDDLE)
            gesture.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
            gesture.connect("pressed", self.open_filee)
            window.add_controller(gesture)
            window._filee_middle_click = True

    def open_filee(self, gesture, presses, x, y):
        modifiers = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.SUPER_MASK
        if presses != 1 or gesture.get_current_event_state() & modifiers:
            return
        widget = gesture.get_widget().pick(x, y, Gtk.PickFlags.DEFAULT)
        # The view cell owns the actual file, including in search results and inactive selections.
        while widget and not GObject.type_is_a(widget.__gtype__, "NautilusViewCell"):
            widget = widget.get_parent()
        if not widget:
            return
        item = widget.get_property("item")
        file = item.get_property("file") if item else None
        if file is None or Nautilus.FileInfo.get_file_type(file) != Gio.FileType.REGULAR:
            return
        path = Nautilus.FileInfo.get_location(file).get_path()
        if not path:
            return
        try:
            Gio.Subprocess.new([str(self.filee), "--convert", path], Gio.SubprocessFlags.NONE)
        except GLib.Error:
            return
        gesture.set_state(Gtk.EventSequenceState.CLAIMED)
