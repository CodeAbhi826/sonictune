// src/sonictune/ui/qml/theme/Theme.qml
pragma Singleton
import QtQuick

QtObject {
    id: theme

    // PERFORMANCE FLAGS — auto-detected on startup, user can override each
    property bool reducedMotion: false
    property bool lowEndMode: false
    property bool disableShadows: false
    property bool disableImageCache: false
    property int imageSourceSize: 512
    property int listCacheBuffer: 200
    property bool smoothScrolling: true

    // MATERIAL 3 DARK SURFACES
    readonly property color background:             "#0F0F0F"
    readonly property color onBackground:           Qt.color("#FFFFFF")
    readonly property color surface:                "#1C1B1F"
    readonly property color surfaceDim:             "#141218"
    readonly property color surfaceBright:          "#3B383E"
    readonly property color surfaceContainerLowest: "#0F0D13"
    readonly property color surfaceContainerLow:    "#1D1B20"
    readonly property color surfaceContainer:       "#211F26"
    readonly property color surfaceContainerHigh:   "#2B2930"
    readonly property color surfaceContainerHighest:"#36343B"
    readonly property color surfaceVariant:         "#49454F"
    readonly property color onSurface:              Qt.color("#E6E0E9")
    readonly property color onSurfaceVariant:       Qt.color("#CAC4D0")

    // MATERIAL 3 PRIMARY (Purple accent)
    readonly property color primary:                "#D0BCFF"
    readonly property color onPrimary:              Qt.color("#381E72")
    readonly property color primaryContainer:       "#4F378B"
    readonly property color onPrimaryContainer:     Qt.color("#EADDFF")
    readonly property color inversePrimary:         "#6750A4"

    // MATERIAL 3 SECONDARY
    readonly property color secondary:              "#CCC2DC"
    readonly property color onSecondary:            Qt.color("#332D41")
    readonly property color secondaryContainer:     "#4A4458"
    readonly property color onSecondaryContainer:   Qt.color("#E8DEF8")

    // MATERIAL 3 TERTIARY (Pink accent)
    readonly property color tertiary:               "#EFB8C8"
    readonly property color onTertiary:             Qt.color("#492532")
    readonly property color tertiaryContainer:      "#633B48"
    readonly property color onTertiaryContainer:    Qt.color("#FFD9E3")

    // MATERIAL 3 ERROR
    readonly property color error:                  "#F2B8B5"
    readonly property color onError:                Qt.color("#601410")
    readonly property color errorContainer:         "#8C1D18"
    readonly property color onErrorContainer:       Qt.color("#F9DEDC")

    // OUTLINES
    readonly property color outline:                "#938F99"
    readonly property color outlineVariant:         "#49454F"

    // EXTENDED TOKENS
    readonly property color success:                "#B9E0C2"
    readonly property color scrim:                  Qt.rgba(0, 0, 0, 0.6)

    // PLAYER SPECIFIC
    readonly property color playerBarBg:            "#1C1B1F"
    readonly property color playerBarBorder:        "#2B2930"
    readonly property color playerProgress:         "#D0BCFF"
    readonly property color playerProgressBg:       "#49454F"

    // TYPOGRAPHY
    property string fontFamily: "Inter"
    property string fontFamilyMono: "JetBrains Mono"

    property font fontDisplayLarge:  Qt.font({ family: fontFamily, pixelSize: 57, weight: Font.Normal })
    property font fontDisplayMedium: Qt.font({ family: fontFamily, pixelSize: 45, weight: Font.Normal })
    property font fontDisplaySmall:  Qt.font({ family: fontFamily, pixelSize: 36, weight: Font.Normal })
    property font fontHeadlineLarge: Qt.font({ family: fontFamily, pixelSize: 32, weight: Font.Normal })
    property font fontHeadlineMedium:Qt.font({ family: fontFamily, pixelSize: 28, weight: Font.Normal })
    property font fontHeadlineSmall: Qt.font({ family: fontFamily, pixelSize: 24, weight: Font.Normal })
    property font fontTitleLarge:    Qt.font({ family: fontFamily, pixelSize: 22, weight: Font.Medium })
    property font fontTitleMedium:   Qt.font({ family: fontFamily, pixelSize: 16, weight: Font.Medium })
    property font fontTitleSmall:    Qt.font({ family: fontFamily, pixelSize: 14, weight: Font.Medium })
    property font fontBodyLarge:     Qt.font({ family: fontFamily, pixelSize: 16, weight: Font.Normal })
    property font fontBodyMedium:    Qt.font({ family: fontFamily, pixelSize: 14, weight: Font.Normal })
    property font fontBodySmall:     Qt.font({ family: fontFamily, pixelSize: 12, weight: Font.Normal })
    property font fontLabelLarge:    Qt.font({ family: fontFamily, pixelSize: 14, weight: Font.Medium })
    property font fontLabelMedium:   Qt.font({ family: fontFamily, pixelSize: 12, weight: Font.Medium })
    property font fontLabelSmall:    Qt.font({ family: fontFamily, pixelSize: 11, weight: Font.Medium })
    property font fontMono:          Qt.font({ family: fontFamilyMono, pixelSize: 13, weight: Font.Normal })

    // SPACING (4dp grid)
    readonly property int space0:  0
    readonly property int space1:  4
    readonly property int space2:  8
    readonly property int space3:  12
    readonly property int space4:  16
    readonly property int space5:  20
    readonly property int space6:  24
    readonly property int space8:  32
    readonly property int space10: 40
    readonly property int space12: 48
    readonly property int space16: 64

    // RADIUS (Material 3)
    readonly property int radiusNone: 0
    readonly property int radiusXs:   4
    readonly property int radiusSm:   8
    readonly property int radiusMd:   12
    readonly property int radiusLg:   16
    readonly property int radiusXl:   28
    readonly property int radiusFull: 9999

    // DURATIONS (respect reducedMotion)
    readonly property int durInstant: 0
    readonly property int durFast:   reducedMotion ? 0 : 150
    readonly property int durNormal: reducedMotion ? 0 : 250
    readonly property int durSlow:   reducedMotion ? 0 : 350
    readonly property int durPage:   reducedMotion ? 0 : 400

    // SHADOWS (disabled if lowEndMode OR disableShadows)
    readonly property int shadowSm:  (lowEndMode || disableShadows) ? 0 : 2
    readonly property int shadowMd:  (lowEndMode || disableShadows) ? 0 : 4
    readonly property int shadowLg:  (lowEndMode || disableShadows) ? 0 : 8

    // HELPERS
    function formatDuration(ms) {
        if (ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function formatDurationShort(ms) {
        if (ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        var sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function formatNumber(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "K"
        return String(n)
    }
}
