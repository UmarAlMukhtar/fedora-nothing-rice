import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "../prefs"

Page {
    id: root
    property bool live
    property string status: ""
    signal done
    caption: "firewall · firewalld"

    onLiveChanged: if (live) probe.running = true
    Process {
        id: probe
        command: ["sh", "-c", "firewall-cmd --state 2>/dev/null; firewall-cmd --get-active-zones 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.status = text.trim() }
    }

    Lb {
        text: root.status || "Could not read firewalld status"
        textFormat: Text.PlainText
    }
    Act {
        text: "Open firewall settings"
        onHit: {
            root.done();
            Quickshell.execDetached(["sh", "-c", "command -v firewall-config >/dev/null && exec firewall-config; notify-send 'Install firewall-config to edit firewall rules'"]);
        }
    }
}
