import QtQuick
import QtMultimedia
import qs

VideoOutput {
    id: video
    property string path: ""
    property bool shouldPlay: false
    readonly property bool ready: player.hasVideo && player.error === MediaPlayer.NoError
    fillMode: VideoOutput.PreserveAspectCrop

    function syncPlayback() {
        if (shouldPlay) player.play();
        else if (player.playbackState === MediaPlayer.PlayingState) player.pause();
    }

    onShouldPlayChanged: syncPlayback()
    onPathChanged: Qt.callLater(syncPlayback)
    Component.onCompleted: syncPlayback()

    MediaPlayer {
        id: player
        source: Theme.url(video.path)
        videoOutput: video
        loops: MediaPlayer.Infinite
        // No audio output: a wallpaper must never claim media keys or play sound.
        onErrorOccurred: (error, message) => console.warn("Live wallpaper:", message)
    }
}
