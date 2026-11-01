import QtQuick
import qs

// пилюля распознавания лица, как у Face ID на айфоне: ищет — остров раздаётся в скруглённый квадрат с зелёным вращающимся
// каркасным шаром; узнал — вытянутая пилюля, замок слева открывается и подпись «Unlocked»; не узнал — красный закрытый замок и причина.
// Общая для острова на рабочем столе (FaceIsland) и для экрана блокировки. Кладётся внутрь Stage;
// holderWidth — ширина холста, по которой пилюля центрируется
Rectangle {
    id: pill

    property string phase: "idle" // idle | scanning | success | failed
    property string reason: ""
    property real holderWidth: 520
    property real offset: 0
    readonly property bool shown: phase !== "idle"
    readonly property color orbGreen: "#4ADE80"

    // понятная подпись вместо ярлыка из лога
    function label() {
        const r = reason;
        if (r.includes("dark") || r.includes("black")) return "too dark";
        if (r.includes("liveness")) return "not a live face";
        if (r.includes("no match")) return "not recognised";
        if (r.includes("no face model")) return "no face enrolled";
        return "face scan failed";
    }

    width: phase === "scanning" ? 92 : phase === "success" ? 190 : 250
    height: phase === "scanning" ? 92 : 44
    Behavior on width { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    x: (holderWidth - width) / 2
    y: shown ? 8 + offset : -(height + 8)
    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    radius: phase === "scanning" ? 30 : height / 2
    Behavior on radius { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    color: "#000000"
    border { width: 1; color: phase === "failed" ? Theme.red : Theme.s2 }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    clip: true
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.6
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

    // ---- ищет: каркасный шар из вращающихся окружностей ----
    Item {
        id: orb
        anchors.centerIn: parent
        width: 52
        height: 52
        opacity: pill.phase === "scanning" ? 1 : 0
        scale: pill.phase === "scanning" ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
        property real a: 0
        NumberAnimation on a { running: pill.phase === "scanning"; from: 0; to: 180; duration: 2600; loops: Animation.Infinite }
        rotation: -24

        // мягкое свечение внутри
        Rectangle { anchors.centerIn: parent; width: 40; height: 40; radius: 20; color: pill.orbGreen; opacity: 0.10 }
        // меридианы: окружности вокруг вертикальной оси
        Repeater {
            model: 5
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 42
                height: 42
                radius: 21
                color: "transparent"
                border { width: 1.5; color: pill.orbGreen }
                opacity: 0.85
                transform: Rotation { origin.x: 21; origin.y: 21; axis { x: 0; y: 1; z: 0 } angle: orb.a + index * 36 }
            }
        }
        // параллели: три окружности вокруг горизонтальной оси
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 42
                height: 42
                radius: 21
                color: "transparent"
                border { width: 1.2; color: pill.orbGreen }
                opacity: 0.5
                transform: Rotation { origin.x: 21; origin.y: 21; axis { x: 1; y: 0; z: 0 } angle: orb.a * 0.7 + index * 60 }
            }
        }
    }

    // ---- результат: замок слева ----
    Canvas {
        id: lock
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 28
        opacity: pill.phase === "success" || pill.phase === "failed" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        // 0 — закрыт, 1 — дужка поднята и отведена; на успехе открывается пружиной
        property real open: pill.phase === "success" ? 1 : 0
        Behavior on open { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        property color ink: pill.phase === "failed" ? Theme.red : Theme.fg
        onOpenChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = ink;
            ctx.fillStyle = ink;
            ctx.lineWidth = 2.8;
            ctx.lineCap = "round";
            const o = Math.max(0, Math.min(1, open));
            const cx = 13, r = 6.5, bodyTop = 14;
            const topY = bodyTop - 3 - 4 * o; // центр дуги поднимается
            // дужка: левая ножка, дуга, правая ножка отрывается от корпуса
            const legEnd = topY + 3 + (1 - o) * (bodyTop - topY - 3);
            ctx.beginPath();
            ctx.moveTo(cx - r, bodyTop);
            ctx.lineTo(cx - r, topY);
            ctx.arc(cx, topY, r, Math.PI, 2 * Math.PI);
            ctx.lineTo(cx + r, legEnd);
            ctx.stroke();
            // корпус
            const x = 2, y = bodyTop, w = 22, h = 13, rr = 4;
            ctx.beginPath();
            ctx.moveTo(x + rr, y);
            ctx.lineTo(x + w - rr, y);
            ctx.arcTo(x + w, y, x + w, y + rr, rr);
            ctx.lineTo(x + w, y + h - rr);
            ctx.arcTo(x + w, y + h, x + w - rr, y + h, rr);
            ctx.lineTo(x + rr, y + h);
            ctx.arcTo(x, y + h, x, y + h - rr, rr);
            ctx.lineTo(x, y + rr);
            ctx.arcTo(x, y, x + rr, y, rr);
            ctx.closePath();
            ctx.fill();
        }
    }
    // промах: замок вздрагивает
    SequentialAnimation {
        running: pill.phase === "failed"
        NumberAnimation { target: lock; property: "x"; to: 8; duration: 60 }
        NumberAnimation { target: lock; property: "x"; to: 20; duration: 90 }
        NumberAnimation { target: lock; property: "x"; to: 10; duration: 80 }
        NumberAnimation { target: lock; property: "x"; to: 14; duration: 70 }
    }
    Text {
        visible: pill.phase === "failed" || pill.phase === "success"
        anchors { left: parent.left; leftMargin: 52; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: pill.phase === "success" ? "Unlocked" : pill.label()
        font { family: Theme.ui; pixelSize: 14; weight: Font.DemiBold }
        color: pill.phase === "success" ? Theme.fg : Theme.red
    }
}
