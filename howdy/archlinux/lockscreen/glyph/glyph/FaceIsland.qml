import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// остров распознавания лица: чёрная пилюля сверху, пока howdy ищет лицо (sudo, polkit и т.п.), как Face ID на айфоне.
// Ищет — кольцо из точек бежит по кругу; узнал — галочка и «unlocked»; не узнал — крестик и причина из лога howdy.
// Статус пишет compare.py в /run/howdy/status.json (под экраном блокировки он не виден: там свой индикатор в lock.qml)
Scope {
    id: root

    // сколько места занято выше: если живой остров уже на экране, опускаемся ниже
    property real offset: 0

    property string phase: "idle" // idle | scanning | success | failed
    property string reason: ""
    readonly property bool shown: phase !== "idle"
    readonly property var ignored: ["lock", "lockface", "sddm", "sddm-greeter", "sddm-autologin"]

    function apply(text) {
        let s;
        try { s = JSON.parse(text); } catch (e) { return; }
        if (!s || !s.state) return;
        if (Date.now() / 1000 - (s.time ?? 0) > 20) return; // старый статус после перезапуска шелла
        if (s.user && s.user !== Quickshell.env("USER")) return;
        if (root.ignored.includes(s.service)) return;
        root.reason = s.reason ?? "";
        if (s.state === "scanning") { root.phase = "scanning"; hideT.interval = 15000; }
        else if (s.state === "success") { root.phase = "success"; hideT.interval = 1400; }
        else { root.phase = "failed"; hideT.interval = 3200; }
        hideT.restart();
    }
    Timer { id: hideT; onTriggered: root.phase = "idle" }

    FileView {
        id: status
        path: "/run/howdy/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.apply(text())
    }

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
        WlrLayershell.namespace: "glyph-face"

        Stage {
            Rectangle {
                id: pill
                readonly property real wantW: root.phase === "scanning" ? 230 : root.phase === "success" ? 180 : 250
                width: wantW
                height: 44
                Behavior on width { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                x: (520 - width) / 2
                y: root.shown ? 8 + root.offset : -(height + 8)
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                radius: height / 2
                color: "#000000"
                border { width: 1; color: root.phase === "failed" ? Theme.red : Theme.s2 }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                clip: true
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.6
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
                    opacity: root.phase === "scanning" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Timer { running: root.phase === "scanning"; interval: 70; repeat: true; onTriggered: ring.ph = (ring.ph + 1) % 12 }
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
                    text: root.phase === "success" ? "\u{F012C}" : "\u{F0156}"
                    font.pixelSize: 24
                    color: root.phase === "success" ? Theme.accent : Theme.red
                    opacity: root.phase === "scanning" ? 0 : 1
                    scale: root.phase === "scanning" ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    text: root.label()
                    font { family: Theme.ui; pixelSize: 14; weight: Font.DemiBold }
                    color: root.phase === "failed" ? Theme.red : Theme.fg
                }
            }
        }
    }
}
