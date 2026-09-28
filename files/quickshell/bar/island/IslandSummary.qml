// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S U M M A R Y                                            │
// │   hover summary · read-only                                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The glance: the time large, the day, what is playing and the readings, with
// nothing to press. A click anywhere opens the control centre. Dark LCARS,
// like the rest: beige time, an orange rule, the media block blue, the
// readings orange, all under the windows' own gradient frame.

Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Only when the weather is already shown on the bar or the desktop:
    // touching the service builds it, and building it makes a network request.
    readonly property bool weather: (SettingsService.onBar("weather")
            || DesktopService.placed("weather"))
        && WeatherService.available

    // The spectrum is cava, a process; it is only started for a glance that
    // has a track to show.
    property bool listening: false

    Component.onCompleted: {
        MediaService.subscribe()
        if (MediaService.available) {
            CavaService.subscribe()
            root.listening = true
        }
    }
    Component.onDestruction: {
        MediaService.release()
        if (root.listening)
            CavaService.release()
    }

    readonly property var readings: {
        const out = []
        if (BatteryService.available)
            out.push({ glyph: BatteryService.icon, text: `${BatteryService.percent}%` })
        if (AudioService.ready)
            out.push({ glyph: AudioService.icon,
                       text: AudioService.muted ? Tr.t("Muted") : `${AudioService.volume}%` })
        if (NotificationService.history.length > 0)
            out.push({ glyph: "󰂚", text: `${NotificationService.history.length}` })
        if (RecorderService.recording)
            out.push({ glyph: "●", text: RecorderService.display })
        if (TimerService.running)
            out.push({ glyph: "󰔛", text: TimerService.display })
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: Qt.formatDateTime(clock.date, SettingsService.clockFormat)
                font.family: Theme.fontFamily
                font.pixelSize: 38
                font.weight: Font.DemiBold
                color: Theme.text
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: Qt.locale(SettingsService.language).toString(clock.date, "dddd")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    text: Qt.locale(SettingsService.language).toString(clock.date, "d MMMM")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                visible: root.weather
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${WeatherService.temperature}°`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.accent
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MediaService.available
            spacing: 10

            ClippingRectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: width * Theme.pictureCorner
                color: Theme.islandSurfaceHover

                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.artUrl
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 68
                    sourceSize.height: 68
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 17
                    color: Theme.border
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: MediaService.title || MediaService.identity
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.border
                }

                Text {
                    Layout.fillWidth: true
                    text: MediaService.artist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.border
                }
            }

            Spectrum {
                Layout.preferredHeight: 14
                barWidth: 2
                minimum: 2
                active: MediaService.playing
                barColor: Theme.border
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: root.readings

                Row {
                    required property var modelData

                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.accent
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
