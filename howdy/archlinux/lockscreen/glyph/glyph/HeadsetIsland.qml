import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs
import qs.components

// подключились наушники — пилюля сверху, как у AirPods на айфоне: значок слева, имя, справа кольцо заряда.
// Любые bluetooth-наушники/гарнитуры; у Nothing/CMF/Ear есть своя карточка снизу (buds/Buds.qml), их здесь пропускаем.
// Держится 4.5 с, клик убирает; заряд приходит чуть позже подключения — кольцо обновляется на лету
Scope {
    id: root

    // сколько места занято выше (живой остров), опускаемся ниже него
    property real offset: 0

    property var dev: null
    property bool shown: false
    // на старте шелла устройства уже подключены — не показывать
    property bool armed: false
    Timer { running: true; interval: 3000; onTriggered: root.armed = true }

    function isHeadset(d) {
        if (/^(nothing|cmf|ear)\b/i.test(d.name ?? "")) return false;
        return /headset|headphone/i.test(d.icon ?? "") || /buds|airpods|headphone|headset|hitune|wh-|wf-/i.test(d.name ?? "");
    }
    function show(d) {
        dev = d;
        shown = true;
        hideT.restart();
    }
    Timer { id: hideT; interval: 4500; onTriggered: root.shown = false }

    Repeater {
        model: Bluetooth.devices
        delegate: Item {
            required property var modelData
            Connections {
                target: modelData
                function onConnectedChanged() {
                    if (modelData.connected && root.armed && root.isHeadset(modelData)) root.show(modelData);
                    else if (!modelData.connected && root.dev === modelData) root.shown = false;
                }
            }
        }
    }

    PanelWindow {
        visible: root.shown || pill.opacity > 0.01
        anchors.top: true
        margins.top: Theme.state.barAt === "top" ? Math.ceil(78 * Theme.s) : 0
        implicitWidth: Math.ceil(520 * Theme.s)
        implicitHeight: Math.ceil(120 * Theme.s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: pill }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-headset"

        Stage {
            Rectangle {
                id: pill
                readonly property bool hasBat: !!root.dev && root.dev.batteryAvailable
                readonly property real bat: hasBat ? Math.max(0, Math.min(1, root.dev.battery)) : 0
                readonly property color batColor: bat <= 0.2 ? Theme.red : "#4ADE80"

                width: 14 + 28 + 12 + name.implicitWidth + (hasBat ? 16 + 28 : 0) + 18
                Behavior on width { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                height: 44
                x: (520 - width) / 2
                y: root.shown ? 8 + root.offset : -(height + 8)
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                radius: height / 2
                color: "#000000"
                border { width: 1; color: Theme.s2 }
                clip: true
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.6
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 260 } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                TapHandler { onTapped: root.shown = false }

                Icon {
                    id: ico
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F02CB}" // mdi-headphones
                    font.pixelSize: 26
                    color: Theme.fg
                }
                Text {
                    id: name
                    x: 14 + 28 + 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dev?.name ?? ""
                    font { family: Theme.ui; pixelSize: 15; weight: Font.Bold }
                    color: Theme.fg
                }
                // кольцо заряда справа
                Canvas {
                    id: ring
                    visible: pill.hasBat
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    property real f: pill.bat
                    property color ink: pill.batColor
                    Behavior on f { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    onFChanged: requestPaint()
                    onInkChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineWidth = 3.4;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16);
                        ctx.beginPath();
                        ctx.arc(14, 14, 11, 0, 2 * Math.PI);
                        ctx.stroke();
                        ctx.strokeStyle = ink;
                        ctx.beginPath();
                        ctx.arc(14, 14, 11, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, f));
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
