// components/Icon.qml — small monochrome vector icon set, hand-drawn on a
// Canvas at a normalized 24x24 grid (same convention as most icon sets).
//
// Why not an icon font / emoji? Emoji render in full color and inconsistent
// weight depending on the system's emoji font, which reads as unpolished
// next to a deliberate color system. An icon font would need bundling a
// font asset + resource pipeline. Drawing the (small, fixed) set this app
// actually needs on a Canvas keeps everything monochrome, crisp at any
// size, colored via Theme like any other element, and dependency-free.
//
// Usage: Icon { name: "play"; size: 20; color: Theme.onSurface }

import QtQuick

Item {
    id: root
    property string name: "play"
    property color color: "white"
    property real size: 20
    property real strokeWidth: 1.8

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.save()

            var s = Math.min(width, height) / 24.0
            ctx.scale(s, s)
            ctx.lineWidth = root.strokeWidth / s
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            switch (root.name) {
            case "play":
                ctx.beginPath()
                ctx.moveTo(8, 5.5); ctx.lineTo(8, 18.5); ctx.lineTo(18.5, 12)
                ctx.closePath(); ctx.fill()
                break
            case "pause":
                roundRect(ctx, 6.5, 5, 4, 14, 1.5); ctx.fill()
                roundRect(ctx, 13.5, 5, 4, 14, 1.5); ctx.fill()
                break
            case "next":
                ctx.beginPath()
                ctx.moveTo(5.5, 5); ctx.lineTo(5.5, 19); ctx.lineTo(14.5, 12)
                ctx.closePath(); ctx.fill()
                roundRect(ctx, 16, 5, 2.4, 14, 1.0); ctx.fill()
                break
            case "previous":
                ctx.beginPath()
                ctx.moveTo(18.5, 5); ctx.lineTo(18.5, 19); ctx.lineTo(9.5, 12)
                ctx.closePath(); ctx.fill()
                roundRect(ctx, 5.6, 5, 2.4, 14, 1.0); ctx.fill()
                break
            case "shuffle":
                ctx.beginPath()
                ctx.moveTo(3.5, 7.5); ctx.lineTo(9, 7.5); ctx.lineTo(20, 17)
                ctx.stroke()
                arrowHead(ctx, 20, 17, -28)
                ctx.beginPath()
                ctx.moveTo(3.5, 17); ctx.lineTo(9, 17); ctx.lineTo(20, 7.5)
                ctx.stroke()
                arrowHead(ctx, 20, 7.5, 28)
                break
            case "repeat":
            case "sync":
                loopArrow(ctx)
                break
            case "repeatOne":
                loopArrow(ctx)
                ctx.font = "bold " + (10) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("1", 12, 12.5)
                break
            case "home":
                ctx.beginPath()
                ctx.moveTo(12, 3.5); ctx.lineTo(3.5, 11); ctx.lineTo(6, 11)
                ctx.lineTo(6, 20); ctx.lineTo(18, 20); ctx.lineTo(18, 11)
                ctx.lineTo(20.5, 11); ctx.closePath()
                ctx.stroke()
                roundRect(ctx, 10, 14.5, 4, 5.5, 0.6); ctx.fill()
                break
            case "search":
                ctx.beginPath(); ctx.arc(10, 10, 6, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(14.6, 14.6); ctx.lineTo(20.5, 20.5); ctx.stroke()
                break
            case "library":
                roundRect(ctx, 4, 5.2, 16, 2.6, 1.3); ctx.fill()
                roundRect(ctx, 4, 10.7, 16, 2.6, 1.3); ctx.fill()
                roundRect(ctx, 4, 16.2, 10, 2.6, 1.3); ctx.fill()
                break
            case "queue":
                roundRect(ctx, 4, 6.5, 13, 2.2, 1.1); ctx.fill()
                roundRect(ctx, 4, 11, 13, 2.2, 1.1); ctx.fill()
                roundRect(ctx, 4, 15.5, 8.5, 2.2, 1.1); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(19, 12.5); ctx.lineTo(19, 19.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15.5, 16); ctx.lineTo(22.5, 16); ctx.stroke()
                break
            case "stats":
                roundRect(ctx, 4.5, 13, 3.6, 6.5, 1); ctx.fill()
                roundRect(ctx, 10.2, 8.5, 3.6, 11, 1); ctx.fill()
                roundRect(ctx, 15.9, 4.5, 3.6, 15, 1); ctx.fill()
                break
            case "note":
                drawEllipse(ctx, 9, 17.2, 3.1, 2.4); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(11.9, 17.2); ctx.lineTo(11.9, 4.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(11.9, 4.5); ctx.lineTo(18, 7); ctx.lineTo(11.9, 9.6)
                ctx.closePath(); ctx.fill()
                break
            case "settings":
                slider(ctx, 6.5, 9)
                slider(ctx, 12, 16.5)
                break
            case "volumeHigh":
            case "volumeMed":
            case "volumeLow":
            case "volumeMute":
                speaker(ctx)
                if (root.name === "volumeMute") {
                    ctx.beginPath()
                    ctx.moveTo(15, 8.5); ctx.lineTo(20.5, 15.5); ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(20.5, 8.5); ctx.lineTo(15, 15.5); ctx.stroke()
                } else {
                    var levels = root.name === "volumeLow" ? 1 : (root.name === "volumeMed" ? 2 : 3)
                    for (var i = 0; i < levels; i++) {
                        ctx.beginPath()
                        var r = 2.6 + i * 2.6
                        ctx.arc(12.2, 12, r, -0.62, 0.62)
                        ctx.stroke()
                    }
                }
                break
            case "speaker":
                speaker(ctx)
                ctx.fill()
                break
            case "close":
                ctx.beginPath(); ctx.moveTo(6.5, 6.5); ctx.lineTo(17.5, 17.5); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(17.5, 6.5); ctx.lineTo(6.5, 17.5); ctx.stroke()
                break
            case "check":
                ctx.beginPath()
                ctx.moveTo(4.5, 12.5); ctx.lineTo(9.5, 17.5); ctx.lineTo(19.5, 5.5)
                ctx.stroke()
                break
            case "warning":
                ctx.beginPath()
                ctx.moveTo(12, 3.5); ctx.lineTo(2.5, 20); ctx.lineTo(21.5, 20)
                ctx.closePath(); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(12, 9); ctx.lineTo(12, 14.2); ctx.stroke()
                ctx.beginPath(); ctx.arc(12, 17, 0.9, 0, Math.PI * 2); ctx.fill()
                break
            case "add":
                ctx.beginPath()
                ctx.moveTo(12, 5); ctx.lineTo(12, 19); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(5, 12); ctx.lineTo(19, 12); ctx.stroke()
                break
            case "external":
                ctx.beginPath()
                ctx.moveTo(19, 10.5); ctx.lineTo(19, 5); ctx.lineTo(13.5, 5)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(19, 5); ctx.lineTo(10.5, 13.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15.5, 8.5); ctx.lineTo(15.5, 19); ctx.lineTo(5, 19)
                ctx.lineTo(5, 8.5); ctx.lineTo(9.5, 8.5)
                ctx.stroke()
                break
            case "chevronDown":
                ctx.beginPath()
                ctx.moveTo(6, 9); ctx.lineTo(12, 15); ctx.lineTo(18, 9)
                ctx.stroke()
                break
            case "clock":
                ctx.beginPath(); ctx.arc(12, 12, 8, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(12, 12); ctx.lineTo(12, 7); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(12, 12); ctx.lineTo(15.5, 14); ctx.stroke()
                break
            case "arrowBack":
                ctx.beginPath(); ctx.moveTo(19, 12); ctx.lineTo(6, 12); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(11, 6); ctx.lineTo(5.5, 12); ctx.lineTo(11, 18); ctx.stroke()
                break
            case "moreVert":
                ctx.beginPath(); ctx.arc(12, 6, 1.6, 0, Math.PI * 2); ctx.fill()
                ctx.beginPath(); ctx.arc(12, 12, 1.6, 0, Math.PI * 2); ctx.fill()
                ctx.beginPath(); ctx.arc(12, 18, 1.6, 0, Math.PI * 2); ctx.fill()
                break
            case "favorite":
                heart(ctx)
                ctx.fill()
                break
            case "favoriteBorder":
                heart(ctx)
                ctx.stroke()
                break
            case "lyrics":
                roundRect(ctx, 4, 7, 12, 3, 1.5); ctx.fill()
                roundRect(ctx, 4, 11.5, 16, 3, 1.5); ctx.fill()
                roundRect(ctx, 4, 16, 8, 3, 1.5); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(17.5, 12.5); ctx.lineTo(17.5, 19.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(14.5, 16); ctx.lineTo(20.5, 16); ctx.stroke()
                break
            case "timer":
                ctx.beginPath(); ctx.moveTo(10, 4); ctx.lineTo(14, 4); ctx.stroke()
                ctx.beginPath(); ctx.arc(12, 13, 7.5, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(12, 13); ctx.lineTo(12, 9); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(12, 9); ctx.lineTo(14.5, 11); ctx.stroke()
                break
            case "share":
                ctx.beginPath(); ctx.arc(6.5, 12, 3.2, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.arc(17.5, 6.5, 3.2, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.arc(17.5, 17.5, 3.2, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(9.6, 10.8); ctx.lineTo(14.4, 7.7); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(9.6, 13.2); ctx.lineTo(14.4, 16.3); ctx.stroke()
                break
            case "chevronRight":
                ctx.beginPath(); ctx.moveTo(9, 5.5); ctx.lineTo(16, 12); ctx.lineTo(9, 18.5); ctx.stroke()
                break
            case "chevronLeft":
                ctx.beginPath(); ctx.moveTo(15, 5.5); ctx.lineTo(8, 12); ctx.lineTo(15, 18.5); ctx.stroke()
                break
            case "person":
                ctx.beginPath(); ctx.arc(12, 7.5, 4, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(4.5, 20); ctx.quadraticCurveTo(12, 11, 19.5, 20); ctx.stroke()
                break
            case "album":
                ctx.beginPath(); ctx.arc(12, 12, 8, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.arc(12, 12, 3.2, 0, Math.PI * 2); ctx.fill()
                break
            case "musicNote":
                drawEllipse(ctx, 9, 17.2, 3.1, 2.4); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(11.9, 17.2); ctx.lineTo(11.9, 4.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(11.9, 4.5); ctx.lineTo(18, 7); ctx.lineTo(11.9, 9.6)
                ctx.closePath(); ctx.fill()
                break
            case "cast":
                ctx.beginPath()
                ctx.moveTo(3.5, 9); ctx.quadraticCurveTo(3.5, 5.5, 7, 5.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(3.5, 18.5); ctx.quadraticCurveTo(3.5, 20.5, 5.5, 20.5); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(3.5, 12); ctx.quadraticCurveTo(3.5, 8, 7.5, 8); ctx.stroke()
                roundRect(ctx, 7.5, 16.5, 3, 4, 1.5); ctx.fill()
                break
            default:
                ctx.beginPath(); ctx.arc(12, 12, 3, 0, Math.PI * 2); ctx.fill()
            }

            ctx.restore()
        }

        function arrowHead(ctx, x, y, angleDeg) {
            var a = angleDeg * Math.PI / 180
            var len = 4.2
            ctx.save()
            ctx.translate(x, y)
            ctx.rotate(a)
            ctx.beginPath()
            ctx.moveTo(-len, -len * 0.62)
            ctx.lineTo(0, 0)
            ctx.lineTo(-len, len * 0.62)
            ctx.stroke()
            ctx.restore()
        }

        function loopArrow(ctx) {
            ctx.beginPath()
            ctx.arc(12, 12, 7.4, -2.55, 2.05, false)
            ctx.stroke()
            var endAngle = 2.05
            var ex = 12 + 7.4 * Math.cos(endAngle)
            var ey = 12 + 7.4 * Math.sin(endAngle)
            arrowHead(ctx, ex, ey, endAngle * 180 / Math.PI + 90)
        }

        function heart(ctx) {
            ctx.beginPath()
            ctx.moveTo(12, 19.5)
            ctx.bezierCurveTo(6.5, 15, 3.5, 11.5, 3.5, 8.2)
            ctx.bezierCurveTo(3.5, 5.5, 5.6, 4, 7.8, 4)
            ctx.bezierCurveTo(9.8, 4, 11.2, 5, 12, 6.4)
            ctx.bezierCurveTo(12.8, 5, 14.2, 4, 16.2, 4)
            ctx.bezierCurveTo(18.4, 4, 20.5, 5.5, 20.5, 8.2)
            ctx.bezierCurveTo(20.5, 11.5, 17.5, 15, 12, 19.5)
            ctx.closePath()
        }

        function slider(ctx, cy, knobX) {
            ctx.beginPath()
            ctx.moveTo(4, cy); ctx.lineTo(20, cy)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(knobX, cy, 2.4, 0, Math.PI * 2)
            ctx.fill()
        }

        function speaker(ctx) {
            ctx.beginPath()
            ctx.moveTo(3.5, 9.5); ctx.lineTo(7.2, 9.5); ctx.lineTo(11.5, 5.5)
            ctx.lineTo(11.5, 18.5); ctx.lineTo(7.2, 14.5); ctx.lineTo(3.5, 14.5)
            ctx.closePath()
            ctx.fill()
        }

        function drawEllipse(ctx, cx, cy, rx, ry) {
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(rx, ry)
            ctx.beginPath()
            ctx.arc(0, 0, 1, 0, Math.PI * 2)
            ctx.restore()
        }

        function roundRect(ctx, x, y, w, h, r) {
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
            ctx.lineTo(x + w, y + h - r)
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            ctx.lineTo(x + r, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }
    }

    onNameChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
