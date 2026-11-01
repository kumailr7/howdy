import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// блокировка — отдельный процесс, как в demonshot: qs -p …/glyph/lock.qml (его зовёт `rice lock`). Разблокировались — выходим.
// Упал шелл — лок живёт; упал лок — Hyprland держит экран закрытым, SUPER+ALT+L поднимает его заново
ShellRoot {
    id: shell
    // hot-reload пересоздаёт WlSessionLock: старый умирает, процесс висит без экрана
    settings.watchFiles: false

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // пароль принят: поверхность доигрывает уход, потом unlockT снимает лок
        readonly property bool busy: pam.active || facePam.active
        function submit() {
            if (leaving) return;
            if (facePam.active) {
                if (!buffer) return; // идёт авто-скан лица; пароль его перебивает
                facePam.abort();
            }
            if (pam.active) return; // пустой Enter = попытка по лицу (howdy)
            pam.start();
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: if (responseRequired) respond(gate.buffer)
        onCompleted: res => {
            gate.buffer = "";
            if (res === PamResult.Success) {
                gate.leaving = true;
                unlockT.start();
            } else gate.fail = true;
        }
    }
    // авто-скан лица сразу после блокировки; конфиг lockface — только howdy, промах не трогает faillock
    PamContext {
        id: facePam
        config: "lockface"
        configDirectory: Quickshell.shellPath("pam")
        onCompleted: res => {
            if (res === PamResult.Success && !gate.leaving) {
                gate.buffer = "";
                gate.leaving = true;
                unlockT.start();
            }
        }
    }
    Timer { id: faceT; interval: 600; onTriggered: if (!gate.leaving && !pam.active && !facePam.active) facePam.start() }
    // повторный скан при пробуждении: экран включился после DPMS-сна (hypridle) или система вышла из suspend (logind)
    property bool dpmsOn: true
    Process {
        id: dpmsP
        command: ["sh", "-c", "hyprctl monitors -j | jq -r 'map(.dpmsStatus) | any'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.trim() === "true";
                if (on && !shell.dpmsOn) { faceT.interval = 600; faceT.restart(); }
                shell.dpmsOn = on;
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: true; onTriggered: if (!dpmsP.running) dpmsP.running = true }
    Process {
        running: true
        command: ["sh", "-c", "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket exec gdbus monitor --system -d org.freedesktop.login1 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => { if (line.includes("PrepareForSleep (false")) { faceT.interval = 1500; faceT.restart(); } }
        }
    }
    Timer { id: unlockT; interval: 470; onTriggered: lock.locked = false }

    property string layout: "en"
    function short(name) { return name.slice(0, 2).toLowerCase(); }
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) shell.layout = shell.short(text.trim()) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") shell.layout = shell.short(e.data.split(",").pop()); }
    }

    WlSessionLock {
        id: lock
        locked: true
        // ponytail: lockedChanged после locked = false не приходит (quickshell 0.3.2), а secure падает — выходим по нему
        onSecureChanged: { if (!secure) Qt.quit(); else faceT.start(); }

        LockSurface { auth: gate; layout: shell.layout }
    }
}
