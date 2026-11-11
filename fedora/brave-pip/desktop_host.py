#!/usr/bin/python3
"""Read desktop visibility for the Brave PiP extension; accepts no commands."""
import json
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import sys


def leaves(node):
    if not node:
        return
    if node.get('client'):
        yield node
    else:
        yield from leaves(node.get('firstChild'))
        yield from leaves(node.get('secondChild'))


def browser_is_away(tree, title):
    for monitor in tree['monitors']:
        for desktop in monitor['desktops']:
            if desktop['id'] != monitor['focusedDesktopId']:
                continue
            for node in leaves(desktop['root']):
                if node['client']['className'] == 'Brave-browser' and not node.get('hidden') and title(node['id']) != 'Picture in picture':
                    return False
    return True


def hyprland_browser_is_away(windows, monitors):
    visible = {m[key]["name"] for m in monitors if not m.get("disabled")
               for key in ("activeWorkspace", "specialWorkspace") if m.get(key, {}).get("name")}
    return not any(
        w.get("class", "").casefold() in ("brave-browser", "brave-browser-stable", "com.brave.browser")
        and w.get("mapped") and not w.get("hidden")
        and w.get("title", "").casefold().replace("-", " ") != "picture in picture"
        and (w.get("pinned") or w.get("workspace", {}).get("name") in visible)
        for w in windows
    )


def watch_hyprland(signature, send):
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    relevant = {b"workspacev2", b"focusedmonv2", b"activespecialv2", b"openwindow",
                b"closewindow", b"movewindowv2", b"windowtitlev2", b"monitoraddedv2", b"monitorremoved"}

    def update():
        def query(name):
            return json.loads(subprocess.check_output(["hyprctl", "-i", signature, "-j", name], timeout=2))
        send(hyprland_browser_is_away(query("clients"), query("monitors")))

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
        events.connect(str(runtime / "hypr" / signature / ".socket2.sock"))
        update()
        pending = b""
        while True:
            ready, _, _ = select.select([sys.stdin.buffer, events], [], [])
            if sys.stdin.buffer in ready:
                return
            data = events.recv(8192)
            if not data:
                return
            *lines, pending = (pending + data).split(b"\n")
            if any(line.partition(b">>")[0] in relevant for line in lines):
                update()


def watch_bspwm(send):
    subscription = subprocess.Popen(['bspc','subscribe','desktop_focus','node_add','node_remove','node_transfer'], stdout=subprocess.PIPE)
    def update():
        tree = json.loads(subprocess.check_output(['bspc','wm','-d'], text=True, timeout=2))
        def title(wid):
            output = subprocess.run(['xprop','-id',str(wid),'_NET_WM_NAME'],capture_output=True,text=True,timeout=2).stdout
            return output.partition('= ')[2].strip().strip('"')
        send(browser_is_away(tree, title))
    try:
        update()
        while True:
            ready,_,_=select.select([sys.stdin.buffer,subscription.stdout],[],[])
            if sys.stdin.buffer in ready:
                # No input protocol: EOF or any input ends this read-only host.
                break
            if subscription.stdout in ready:
                if not subscription.stdout.readline(): break
                update()
    finally:
        subscription.terminate()
        subscription.wait(timeout=2)


def main():
    last = None

    def send(away):
        nonlocal last
        if away != last:
            payload = json.dumps({"away": away}).encode()
            sys.stdout.buffer.write(struct.pack("<I", len(payload)) + payload)
            sys.stdout.buffer.flush()
            last = away

    try:
        signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if signature:
            watch_hyprland(signature, send)
        else:
            watch_bspwm(send)
    except (OSError, subprocess.SubprocessError, ValueError):
        pass

if __name__=='__main__': main()
