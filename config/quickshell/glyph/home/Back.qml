import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// home's underlay, a separate window on the background layer: the dot grid, the halftone orb, the wallpaper. Home itself (clock, bento) — a layer
// above, transparent: it repaints often (the colon, the rings, the spinning cover), and the wallpaper is a fullscreen shader,
// in one window it would be computed on every one of its frames. Here a frame happens only for the wave, a look change and the orb breathing.
// The image covered everything — we don't draw the grid and orb, the orb doesn't breathe: the window stands still
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "glyph-back"

    readonly property bool home: (Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.length ?? 1) === 0
    readonly property bool showingVideo: live.item?.ready ?? false

    Loader {
        id: live
        anchors.fill: parent
        active: Theme.state.useLiveWall && Theme.state.liveWall !== "" && !Theme.state.lite
        visible: root.showingVideo
        // The still theme never instantiates a media player.
        source: "LiveWallpaper.qml"
        onLoaded: {
            item.path = Qt.binding(() => Theme.state.liveWall);
            item.shouldPlay = Qt.binding(() => root.home && !Sys.wallOpen);
        }
    }
    property real phase: 0
    Timer { running: root.home && orb.visible && !Theme.state.lite; interval: 100; repeat: true; onTriggered: root.phase += 0.1 }

    Stage {
        id: stage
        Image {
            visible: Theme.state.grid && !wall.opaque && !root.showingVideo
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        Orb { id: orb; visible: Theme.state.orb && !wall.opaque && !root.showingVideo; x: stage.width - 720; y: stage.height - 580; phase: root.phase }
        Wall {
            id: wall
            visible: !root.showingVideo
            anchors.fill: parent
            path: Theme.wallSrc(Theme.state.wall)
            animate: root.home && !root.showingVideo && !Sys.wallOpen && !Theme.state.lite
            // the music's bass, only on this monitor's empty workspace — under windows a full-screen pass for nothing
            beat: Theme.state.wallPulse && root.home && !root.showingVideo ? Cava.bass : 0
        }
    }
}
