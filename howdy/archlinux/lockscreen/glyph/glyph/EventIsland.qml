import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components

// короткие события в острове, как на айфоне: зарядка, низкий заряд, звук/без звука, микрофон, не беспокоить, wifi, vpn.
// Одна пилюля и очередь: события не накладываются, а идут друг за другом. Повтор того же события (громкость) обновляет
// текущую пилюлю на месте. Иконка слева, подпись, справа кольцо или полоска уровня. Клик — убрать.
Scope {
    id: root

    property real offset: 0

    // ---- очередь ----
    property var cur: null
    property var queue: []
    property bool shown: false
    function push(e) {
        if (!armed) return;
        if (cur && e.key && cur.key === e.key) { cur = e; shown = true; hideT.interval = e.hold ?? 2200; hideT.restart(); return; }
        queue = queue.concat([e]);
        if (!cur && !shown) next();
    }
    function next() {
        if (queue.length === 0) { cur = null; return; }
        cur = queue[0];
        queue = queue.slice(1);
        shown = true;
        hideT.interval = cur.hold ?? 2200;
        hideT.restart();
    }
    Timer { id: hideT; onTriggered: { root.shown = false; gapT.restart(); } }
    Timer { id: gapT; interval: 480; onTriggered: root.next() }

    // на старте шелла всё уже подключено/включено — не показывать
    property bool armed: false
    Timer { running: true; interval: 3500; onTriggered: root.armed = true }

    // ---- зарядка и низкий заряд ----
    readonly property var bat: UPower.displayDevice
    readonly property bool onBat: UPower.onBattery
    onOnBatChanged: {
        const p = bat.percentage;
        if (onBat) push({ key: "ac", icon: "\u{F0079}", text: "On battery", ring: p, tone: p <= 0.2 ? "bad" : "ok" });
        else push({ key: "ac", icon: "\u{F0084}", text: "Charging", ring: p, tone: "ok" });
    }
    property int lowStep: 100
    readonly property int batPct: Math.round(bat.percentage * 100)
    onBatPctChanged: {
        if (!onBat) { lowStep = 100; return; }
        for (const step of [5, 10, 20]) {
            if (batPct <= step && lowStep > step) {
                lowStep = step;
                push({ key: "low", icon: "\u{F0079}", text: step <= 10 ? "Battery critical" : "Low battery", ring: bat.percentage, tone: "bad", hold: 4000 });
                return;
            }
        }
    }

    // ---- звук: беззвучный режим и громкость ----
    Connections {
        target: Sys
        function onMutedChanged() {
            if (Sys.muted) root.push({ key: "snd", icon: "\u{F0581}", text: "Silent", tone: "bad" });
            else root.push({ key: "snd", icon: "\u{F057E}", text: "Sound on", level: Sys.vol });
        }
        function onVolChanged() {
            if (Sys.muted) return;
            root.push({ key: "snd", icon: Sys.vol <= 0.01 ? "\u{F0581}" : Sys.vol < 0.34 ? "\u{F057F}" : Sys.vol < 0.67 ? "\u{F0580}" : "\u{F057E}", text: Math.round(Sys.vol * 100) + "%", level: Sys.vol, hold: 1400 });
        }
        function onMicOnChanged() {
            if (Sys.micOn) root.push({ key: "mic", icon: "\u{F036C}", text: "Mic on" });
            else root.push({ key: "mic", icon: "\u{F036D}", text: "Mic muted", tone: "bad" });
        }
        function onVpnChanged() {
            root.push({ key: "vpn", icon: "\u{F0582}", text: Sys.vpn ? "VPN connected" : "VPN off", tone: Sys.vpn ? "ok" : "bad" });
        }
    }

    // ---- не беспокоить ----
    Connections {
        target: Theme.state
        function onDndChanged() {
            root.push({ key: "dnd", icon: Theme.state.dnd ? "\u{F0594}" : "\u{F009A}", text: Theme.state.dnd ? "Do Not Disturb" : "Notifications on", tone: Theme.state.dnd ? "ok" : "" });
        }
    }

    // ---- wifi ----
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property string ssid: wifi?.networks?.values?.find(n => n.connected)?.name ?? ""
    onSsidChanged: if (ssid) push({ key: "wifi", icon: "\u{F05A9}", text: ssid, tone: "ok", hold: 2800 });

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
        WlrLayershell.namespace: "glyph-events"

        Stage {
            Rectangle {
                id: pill
                readonly property var e: root.cur ?? ({})
                readonly property bool hasRing: e.ring !== undefined
                readonly property bool hasLevel: e.level !== undefined
                readonly property color toneColor: e.tone === "bad" ? Theme.red : e.tone === "ok" ? "#4ADE80" : Theme.fg

                width: Math.min(460, 14 + 28 + 12 + label.implicitWidth + (hasRing ? 16 + 28 : 0) + (hasLevel ? 16 + 70 : 0) + 18)
                Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                height: 44
                x: (520 - width) / 2
                y: root.shown ? 8 + root.offset : -(height + 8)
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                radius: height / 2
                color: "#000000"
                border { width: 1; color: pill.e.tone === "bad" ? Theme.red : Theme.s2 }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                clip: true
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.6
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 260 } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                TapHandler { onTapped: { root.shown = false; gapT.restart(); } }

                Icon {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.e.icon ?? ""
                    font.pixelSize: 26
                    color: pill.toneColor
                }
                Text {
                    id: label
                    x: 14 + 28 + 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.e.text ?? ""
                    font { family: Theme.ui; pixelSize: 15; weight: Font.Bold }
                    color: Theme.fg
                }
                // кольцо (заряд)
                Canvas {
                    id: ring
                    visible: pill.hasRing
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    property real f: pill.e.ring ?? 0
                    property color ink: pill.toneColor
                    Behavior on f { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
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
                        ctx.arc(14, 14, 11, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, Math.min(1, f)));
                        ctx.stroke();
                    }
                }
                // полоска уровня (громкость)
                Rectangle {
                    visible: pill.hasLevel
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    width: 70
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, pill.e.level ?? 0))
                        height: parent.height
                        radius: 3
                        color: Theme.fg
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }
    }
}
