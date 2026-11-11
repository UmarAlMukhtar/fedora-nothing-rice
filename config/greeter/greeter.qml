import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs
import "lock"

// the Lock greeter, for greetd: the lock screen's own view (lock/LockView, built by install.sh from LockSurface),
// with session, user and power on the left. greetd checks the password; outside greetd it only shows the look
ShellRoot {
    id: shell
    settings.watchFiles: false

    property var sessions: [] // [{ name, exec, type, desktop }]
    property var users: []    // human logins from passwd
    property int session: 0
    property int user: 0
    readonly property string userName: users[user] ?? ""
    readonly property var power: [["sleep", "suspend"], ["reboot", "reboot"], ["power off", "poweroff"]]

    function pick(list, want, fallback) { const i = list.indexOf(want); return i >= 0 ? i : fallback; }
    function step(i, n, d) { return n ? (i + d + n) % n : 0; }
    function setUser(i) { user = i; gate.buffer = ""; gate.fail = false; }

    // last pick lives in the greeter user's home (install.sh makes it)
    FileView {
        id: memo
        path: Quickshell.env("HOME") + "/last.json"
        blockLoading: true
        printErrors: false
        JsonAdapter {
            id: last
            property string user: ""
            property string session: ""
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "field() { sed -n \"s/^$1=//p\" \"$2\" | head -n1; }\nfor f in /usr/share/wayland-sessions/*.desktop; do\n    [ -r \"$f\" ] || continue\n    try_exec=$(field TryExec \"$f\")\n    [ -z \"$try_exec\" ] || command -v \"$try_exec\" >/dev/null 2>&1 || continue\n    desktop=$(field DesktopNames \"$f\" | sed 's/;$//; s/;/:/g')\n    printf '%s\\t%s\\t%s\\t%s\\n' \"$(field Name \"$f\")\" \"$(field Exec \"$f\")\" wayland \"${desktop:-${f##*/}}\"\ndone\nif [ \"$GLYPH_FEDORA_GREETER\" = 1 ] && [ -x /usr/bin/startx ] && [ -x /usr/bin/bspwm ]; then\n    printf '%s\\t%s\\t%s\\t%s\\n' 'bspwm (X11)' '/usr/bin/startx /etc/X11/xinit/Xsession bspwm -- -seat \"${XDG_SEAT:-seat0}\" -keeptty \"vt${XDG_VTNR}\" -nolisten tcp' x11 bspwm\nfi"]
        stdout: StdioCollector {
            onStreamFinished: {
                // desktop-entry field codes (%U and co) mean nothing to a session
                const s = text.split("\n").map(l => l.split("\t")).filter(p => p[1]).map(p => ({ name: p[0], exec: p[1].replace(/ ?%[A-Za-z]/g, ""), type: p[2], desktop: p[3] }));
                const names = s.map(x => x.name);
                shell.sessions = s;
                shell.session = shell.pick(names, last.session, Math.max(0, Quickshell.env("GLYPH_FEDORA_GREETER") === "1" ? names.indexOf("Hyprland") : names.findIndex(n => /uwsm/i.test(n))));
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                shell.users = text.split("\n").filter(Boolean);
                shell.user = shell.pick(shell.users, last.user, 0);
            }
        }
    }

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // accepted: the view plays its exit, then launchT starts the session
        property string why: "" // what PAM said, like how long the account is locked for
        readonly property bool busy: Greetd.state === GreetdState.Authenticating
        function submit() {
            if (!buffer || busy || leaving || !shell.userName || !shell.sessions.length) return;
            why = "";
            Greetd.createSession(shell.userName);
        }
    }
    function failed() {
        gate.buffer = "";
        gate.fail = true;
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
    }
    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(gate.buffer);
            else gate.why = message.trim().replace(/\s*\n\s*/g, " · ");
        }
        function onAuthFailure(message) { shell.failed(); }
        function onError(error) { console.warn("greetd:", error); shell.failed(); }
        function onReadyToLaunch() {
            gate.buffer = "";
            gate.leaving = true;
            last.user = shell.userName;
            last.session = shell.sessions[shell.session].name;
            memo.writeAdapter();
            launchT.start();
        }
    }
    // greetd joins the command with spaces and runs it through sh, so Exec goes in whole and that shell parses it.
    // greetd drops the session's output; systemd-cat keeps it: journalctl -t glyph-session
    Timer {
        id: launchT
        interval: 470
        onTriggered: {
            const session = shell.sessions[shell.session];
            Greetd.launch(["systemd-cat", "-t", "glyph-session", session.exec],
                          [`XDG_SESSION_TYPE=${session.type}`, `XDG_CURRENT_DESKTOP=${session.desktop}`, `XDG_SESSION_DESKTOP=${session.desktop}`]);
        }
    }

    // cage shows it full screen; anywhere else it is a plain window
    FloatingWindow {
        implicitWidth: Quickshell.screens[0]?.width ?? 1920
        implicitHeight: Quickshell.screens[0]?.height ?? 1080
        color: Theme.bg

        Item {
            anchors.fill: parent

            // keys the password field leaves alone bubble up to here
            Keys.onPressed: e => {
                if (gate.leaving) return;
                const k = e.key;
                if (k === Qt.Key_Up || k === Qt.Key_Down) shell.session = shell.step(shell.session, shell.sessions.length, k === Qt.Key_Down ? 1 : -1);
                else if (k === Qt.Key_PageUp || k === Qt.Key_PageDown) shell.setUser(shell.step(shell.user, shell.users.length, k === Qt.Key_PageDown ? 1 : -1));
                else if (k === Qt.Key_F10) Quickshell.execDetached(["systemctl", "suspend"]);
                else if (k === Qt.Key_F11) Quickshell.execDetached(["systemctl", "reboot"]);
                else if (k === Qt.Key_F12) Quickshell.execDetached(["systemctl", "poweroff"]);
                else return;
                e.accepted = true;
            }

            LockView {
                id: view
                anchors.fill: parent
                auth: gate
                layout: (Quickshell.env("XKB_DEFAULT_LAYOUT") || "en").slice(0, 2)
                user: shell.userName
                face: `file:///var/lib/AccountsService/icons/${shell.userName}`
            }

            // in layout pixels, like everything on the stage; bottom-left corner, under the clock, slides in with the corner labels
            Column {
                parent: view.stage
                x: 44
                anchors { bottom: parent.bottom; bottomMargin: 44 }
                spacing: 36
                opacity: view.ph(0.45, 0.85)
                transform: Translate { x: -24 * (1 - view.ph(0.45, 0.85)) }

                Pick { label: "session"; hint: "↑ ↓"; model: shell.sessions.map(s => s.name); current: shell.session; onPicked: i => shell.session = i }
                Pick { label: "user"; hint: "pgup pgdn"; model: shell.users; current: shell.user; onPicked: i => shell.setUser(i) }
                Pick { label: "power"; hint: "f10 f11 f12"; model: shell.power.map(p => p[0]); onPicked: i => Quickshell.execDetached(["systemctl", shell.power[i][1]]) }
            }
        }
    }
}
