import QtQuick
import qs

// пилюля распознавания лица, как Face ID: ищет — кольцо из точек бежит по кругу; узнал — галочка и «unlocked»;
// не узнал — красный крестик и причина. Общая для острова на рабочем столе (FaceIsland) и для экрана блокировки.
// Кладётся внутрь Stage; holderWidth — ширина холста, по которой пилюля центрируется
Rectangle {
    id: pill

    property string phase: "idle" // idle | scanning | success | failed
    property string reason: ""
    property real holderWidth: 520
    property real offset: 0
    readonly property bool shown: phase !== "idle"

    // понятная подпись вместо ярлыка из лога
    function label() {
        if (phase === "scanning") return "looking for you";
        if (phase === "success") return "unlocked";
        const r = reason;
        if (r.includes("dark") || r.includes("black")) return "too dark";
        if (r.includes("liveness")) return "not a live face";
        if (r.includes("no match")) return "not recognised";
        if (r.includes("no face model")) return "no face enrolled";
        return "face scan failed";
    }

    width: phase === "scanning" ? 230 : phase === "success" ? 180 : 250
    height: 44
    Behavior on width { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    x: (holderWidth - width) / 2
    y: shown ? 8 + offset : -(height + 8)
    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    radius: height / 2
    color: "#000000"
    border { width: 1; color: phase === "failed" ? Theme.red : Theme.s2 }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    clip: true
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.6
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

    // кольцо из точек: волна яркости бежит по кругу, пока идёт поиск
    Item {
        id: ring
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        property real ph: 0
        opacity: pill.phase === "scanning" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { running: pill.phase === "scanning"; interval: 70; repeat: true; onTriggered: ring.ph = (ring.ph + 1) % 12 }
        Repeater {
            model: 12
            Rectangle {
                required property int index
                readonly property real a: index / 12 * 2 * Math.PI
                width: 3.4
                height: 3.4
                radius: 1.7
                x: ring.width / 2 + Math.sin(a) * 10 - width / 2
                y: ring.height / 2 - Math.cos(a) * 10 - height / 2
                color: Theme.fg
                opacity: 0.18 + 0.82 * ((index - ring.ph + 12) % 12 < 5 ? 1 - ((index - ring.ph + 12) % 12) / 5 : 0)
            }
        }
    }
    // галочка / крестик
    Icon {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: pill.phase === "success" ? "\u{F012C}" : "\u{F0156}"
        font.pixelSize: 24
        color: pill.phase === "success" ? Theme.accent : Theme.red
        opacity: pill.phase === "scanning" ? 0 : 1
        scale: pill.phase === "scanning" ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    }
    Text {
        anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: pill.label()
        font { family: Theme.ui; pixelSize: 14; weight: Font.DemiBold }
        color: pill.phase === "failed" ? Theme.red : Theme.fg
    }
}
