import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Calendar and focus timer. Hover the clock to preview, or click it to pin the panel.
// The month as a 7×6 grid (today — a white circle), the arrows and ←→ page through, a click on the month — back to today. Below, the timer:
// a ring of dots fills clockwise, minute presets, start/pause (and space), reset. While running — Glyph fills the bottom bar.
// Esc or a click outside — close
PanelWindow {
    id: root

    property bool open: false
    property bool pinned: false
    property bool clockHovered: false
    function preview(hovered) {
        clockHovered = hovered;
        if (hovered && !dismissed.running) open = true;
    }
    function pin() {
        pinned = true;
        open = true;
    }
    function close() {
        if (pinned) dismissed.restart();
        open = false;
        pinned = false;
        clockHovered = false;
    }
    // Releasing the click-catching backdrop can expose the clock under a stationary pointer.
    Timer { id: dismissed; interval: 180 }
    Timer {
        interval: 300
        running: root.open && !root.pinned && !root.clockHovered && !panelHover.hovered
        onTriggered: root.close()
    }
    property int shift: 0 // months from the current one
    onOpenChanged: {
        hoverDate = null;
        if (open) {
            shift = 0;
            refreshEvents();
        }
    }

    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: open && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0 || open
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: root.pinned ? backdrop : panel }
    WlrLayershell.keyboardFocus: open && pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-cal"

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property var en: Qt.locale("en_US")
    readonly property var month: new Date(clock.date.getFullYear(), clock.date.getMonth() + shift, 1)
    readonly property int lead: (month.getDay() + 6) % 7 // days of the previous month before Monday
    readonly property string firstDay: dateKey(new Date(month.getFullYear(), month.getMonth(), 1 - lead))
    property var eventDays: ({})
    property var hoverDate: null
    readonly property var hoverEvents: hoverDate ? eventDays[dateKey(hoverDate)] ?? [] : []
    property bool calendarUnavailable: false

    function dateKey(date) { return Qt.formatDate(date, "yyyy-MM-dd"); }
    function refreshEvents() {
        if (!open || eventLookup.running) return;
        eventLookup.requestedDay = firstDay;
        eventLookup.running = true;
    }
    onFirstDayChanged: {
        hoverDate = null;
        eventDays = {};
        calendarUnavailable = false;
        refreshEvents();
    }
    Process {
        id: eventLookup
        property string requestedDay
        command: ["timeout", "20s", "/usr/bin/python3", Quickshell.shellPath("cal/calendar_events.py"), requestedDay]
        stdout: StdioCollector {
            onStreamFinished: {
                if (eventLookup.requestedDay !== root.firstDay || !text.trim()) return;
                root.eventDays = JSON.parse(text);
            }
        }
        onExited: code => {
            if (requestedDay !== root.firstDay) Qt.callLater(root.refreshEvents);
            else root.calendarUnavailable = code !== 0;
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.dim
        opacity: root.pinned ? 0.35 * root.t : 0
        MouseArea { anchors.fill: parent; enabled: root.pinned; onClicked: root.close() }
    }

    Stage {
        Rectangle {
            id: panel
            // the inner edge of the bar pill (14 + 64) and a 14 gap, slides out from the bar; across — centered, where the clock is
            readonly property real off: 92 - 24 * (1 - root.t)
            readonly property bool onTop: Theme.state.barAt === "top"
            x: onTop ? (parent.width - width) / 2 : Theme.barRight ? parent.width - width - off : off
            y: onTop ? off : (parent.height - height) / 2
            width: 440
            height: col.height + 52
            opacity: root.t
            radius: Theme.corner(36)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Left) root.shift--;
                else if (e.key === Qt.Key_Right) root.shift++;
                else if (e.key === Qt.Key_Space) Focus.toggle();
                else return;
                e.accepted = true;
            }
            MouseArea { anchors.fill: parent } // a click on the panel doesn't close it
            HoverHandler {
                id: panelHover
                onHoveredChanged: if (!hovered) root.hoverDate = null
            }

            Column {
                id: col
                x: 26
                y: 26
                width: parent.width - 52
                spacing: 18

                Item {
                    width: parent.width
                    height: 44
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Num { anchors.verticalCenter: parent.verticalCenter; text: root.en.standaloneMonthName(root.month.getMonth(), Locale.ShortFormat); font.pixelSize: 44 }
                        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.month.getFullYear() }
                        Item {
                            id: loader
                            anchors.verticalCenter: parent.verticalCenter
                            visible: eventLookup.running
                            width: 24
                            height: 16
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Loading calendar events"

                            property real phase: 0
                            NumberAnimation on phase {
                                running: root.open && loader.visible
                                from: 0; to: 1
                                duration: 620
                                easing.type: Easing.InOutSine
                                loops: Animation.Infinite
                            }
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    x: 10 * (index === 0 ? 2 * loader.phase : index - loader.phase)
                                    y: 11 - (index === 0 ? 8 * Math.sin(Math.PI * loader.phase) : 0)
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.grey
                                }
                            }
                        }
                        TapHandler { onTapped: root.shift = 0 }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Round { icon: "\u{F0141}"; onClicked: root.shift-- }
                        Round { icon: "\u{F0142}"; onClicked: root.shift++ }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Text {
                            required property string modelData
                            width: col.width / 7
                            height: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font { family: Theme.mono; pixelSize: 11 }
                            color: Theme.grey
                        }
                    }
                    Repeater {
                        model: 42
                        Item {
                            id: day
                            required property int index
                            readonly property var d: new Date(root.month.getFullYear(), root.month.getMonth(), index - root.lead + 1)
                            readonly property bool own: d.getMonth() === root.month.getMonth()
                            readonly property bool today: d.toDateString() === clock.date.toDateString()
                            readonly property int eventCount: root.eventDays[root.dateKey(d)]?.length ?? 0
                            width: col.width / 7
                            height: 46
                            activeFocusOnTab: eventCount > 0
                            Accessible.role: Accessible.StaticText
                            Accessible.name: Qt.formatDate(d, "dddd, d MMMM") + (eventCount ? `, ${eventCount} events` : "")
                            onActiveFocusChanged: if (activeFocus) root.hoverDate = d
                            HoverHandler { onHoveredChanged: if (hovered) root.hoverDate = day.d }
                            Rectangle {
                                anchors.centerIn: parent
                                visible: day.today || day.activeFocus
                                width: 38
                                height: 38
                                radius: 19
                                color: day.today ? Theme.fg : "transparent"
                                border { width: day.activeFocus ? 1 : 0; color: Theme.accent }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: day.d.getDate()
                                font { family: Theme.mono; pixelSize: 14 }
                                color: day.today ? Theme.ink : !day.own ? Theme.mute : day.index % 7 > 4 ? Theme.grey : Theme.fg
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height / 2 + 12
                                visible: day.eventCount > 0
                                width: 5
                                height: 5
                                radius: 2.5
                                color: day.today ? Theme.ink : Theme.accent
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.s2 }

                Lb { visible: root.calendarUnavailable; text: "Google Calendar unavailable"; px: 10 }

                Column {
                    visible: root.hoverEvents.length > 0
                    width: parent.width
                    height: 164
                    spacing: 8
                    Lb {
                        id: agendaDate
                        text: root.hoverDate ? Qt.formatDate(root.hoverDate, "dddd, d MMM") : ""
                    }
                    ListView {
                        width: parent.width
                        height: parent.height - agendaDate.height - parent.spacing
                        clip: true
                        spacing: 8
                        model: root.hoverEvents
                        onModelChanged: positionViewAtBeginning()
                        delegate: Row {
                            id: eventRow
                            required property var modelData
                            width: ListView.view.width
                            spacing: 12
                            Lb { id: eventTime; width: 92; text: eventRow.modelData.time; px: 10 }
                            Text {
                                width: eventRow.width - eventTime.width - eventRow.spacing
                                text: eventRow.modelData.title
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                font { family: Theme.ui; pixelSize: 14 }
                                color: Theme.fg
                            }
                        }
                    }
                }

                Row {
                    visible: root.hoverEvents.length === 0
                    spacing: 24
                    Item {
                        width: 164
                        height: 164
                        Ring { anchors.fill: parent; n: 44; dot: 5; f: Focus.f }
                        Column {
                            anchors.centerIn: parent
                            Num { anchors.horizontalCenter: parent.horizontalCenter; text: Focus.mmss(Focus.left); font.pixelSize: 38 }
                            Lb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 10
                                text: Focus.running ? "focus" : Focus.paused ? "paused" : "ready"
                                color: Focus.running ? Theme.fg : Theme.grey
                                px: 10
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16
                        Lb { text: "focus · min" }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [15, 25, 45, 60]
                                Rectangle {
                                    id: chip
                                    required property int modelData
                                    readonly property bool on: Focus.minutes === modelData
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: on ? Theme.fg : chipHov.hovered ? Theme.s3 : Theme.s2
                                    Text { anchors.centerIn: parent; text: chip.modelData; font { family: Theme.mono; pixelSize: 13 } color: chip.on ? Theme.ink : Theme.fg }
                                    HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: Focus.set(chip.modelData) }
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 146
                                height: 44
                                radius: Theme.corner(22)
                                color: Focus.running ? Theme.s2 : Theme.fg
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Icon { anchors.verticalCenter: parent.verticalCenter; text: Focus.running ? "\u{F03E4}" : "\u{F040A}"; color: Focus.running ? Theme.fg : Theme.ink }
                                    Lb {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Focus.running ? "pause" : Focus.paused ? "resume" : "start"
                                        color: Focus.running ? Theme.fg : Theme.ink
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Focus.toggle() }
                            }
                            Round { icon: "\u{F0450}"; opacity: Focus.running || Focus.paused ? 1 : 0.4; onClicked: Focus.reset() }
                        }
                    }
                }
            }
        }
    }

    component Round: Rectangle {
        property string icon
        signal clicked
        width: 44
        height: 44
        radius: 22
        color: Theme.s2
        Icon { anchors.centerIn: parent; text: parent.icon }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.clicked() }
    }
}
