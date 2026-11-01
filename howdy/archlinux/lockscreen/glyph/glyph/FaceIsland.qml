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
            FacePill { id: pill; phase: root.phase; reason: root.reason; offset: root.offset }
        }
    }
}
