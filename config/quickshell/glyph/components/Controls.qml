import QtQuick
import qs
import qs.services

// back · play/pause · forward
Row {
    id: root

    property real size: 22
    property real play: 52

    spacing: root.size

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AE}"
        font.pixelSize: root.size
        color: Media.player?.canGoPrevious ? Theme.fg : Theme.mute
        TapHandler { onTapped: Media.player?.previous() }
    }
    Rectangle {
        id: playButton
        width: root.play
        height: root.play
        radius: root.play / 2
        color: Theme.accent
        function activate() {
            if (Media.player?.canTogglePlaying)
                Media.player.togglePlaying();
            else
                Media.spotify(false);
        }
        Accessible.role: Accessible.Button
        Accessible.name: Media.playing ? "Pause" : "Play"
        Accessible.onPressAction: activate()
        Icon { anchors.centerIn: parent; text: Media.playing ? "\u{F03E4}" : "\u{F040A}"; color: Theme.on(Theme.accent); font.pixelSize: root.play * 0.46 }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: playButton.activate() }
    }
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AD}"
        font.pixelSize: root.size
        color: Media.player?.canGoNext ? Theme.fg : Theme.mute
        TapHandler { onTapped: Media.player?.next() }
    }
}
