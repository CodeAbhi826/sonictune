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
    property color background:             "#0F0F0F"
    property color onBackground:           "#E6E1E5"
    property color surface:                "#1C1B1F"
    property color surfaceDim:             "#141218"
    property color surfaceBright:          "#3B383E"
    property color surfaceContainerLowest: "#0F0D13"
    property color surfaceContainerLow:    "#1D1B20"
    property color surfaceContainer:       "#211F26"
    property color surfaceContainerHigh:   "#2B2930"
    property color surfaceContainerHighest:"#36343B"
    property color surfaceVariant:         "#49454F"
    property color onSurface:              "#E6E1E5"
    property color onSurfaceVariant:       "#CAC4D0"

    // MATERIAL 3 PRIMARY (Purple accent)
    property color primary:                "#D0BCFF"
    property color onPrimary:              "#381E72"   // dark text on light-lavender primary
    property color primaryContainer:       "#4F378B"
    property color onPrimaryContainer:     "#EADDFF"
    property color inversePrimary:         "#6750A4"

    // MATERIAL 3 SECONDARY
    property color secondary:              "#CCC2DC"
    property color onSecondary:            "#332D41"
    property color secondaryContainer:     "#4A4458"
    property color onSecondaryContainer:   "#E8DEF8"

    // MATERIAL 3 TERTIARY (Pink accent)
    property color tertiary:               "#EFB8C8"
    property color onTertiary:             "#492532"
    property color tertiaryContainer:      "#633B48"
    property color onTertiaryContainer:    "#FFD8E4"

    // MATERIAL 3 ERROR
    property color error:                  "#F2B8B5"
    property color onError:                "#601410"
    property color errorContainer:         "#8C1D18"
    property color onErrorContainer:       "#F9DEDC"

    // OUTLINES
    property color outline:                "#938F99"
    property color outlineVariant:         "#49454F"

    // EXTENDED TOKENS
    property color success:                "#B9E0C2"
    property color scrim:                  Qt.rgba(0, 0, 0, 0.6)

    // PLAYER SPECIFIC
    property color playerBarBg:            "#1C1B1F"
    property color playerBarBorder:        "#2B2930"
    property color playerProgress:         "#D0BCFF"
    property color playerProgressBg:       "#49454F"

    // DYNAMIC PALETTE UPDATE (Material You)
    function updateDynamicPalette(palette) {
        if (!palette) return

        theme.primary = palette.primary || theme.primary
        theme.onPrimary = palette.onPrimary || theme.onPrimary
        theme.primaryContainer = palette.primaryContainer || theme.primaryContainer
        theme.onPrimaryContainer = palette.onPrimaryContainer || theme.onPrimaryContainer
        theme.inversePrimary = palette.inversePrimary || theme.inversePrimary

        theme.secondary = palette.secondary || theme.secondary
        theme.onSecondary = palette.onSecondary || theme.onSecondary
        theme.secondaryContainer = palette.secondaryContainer || theme.secondaryContainer
        theme.onSecondaryContainer = palette.onSecondaryContainer || theme.onSecondaryContainer

        theme.tertiary = palette.tertiary || theme.tertiary
        theme.onTertiary = palette.onTertiary || theme.onTertiary
        theme.tertiaryContainer = palette.tertiaryContainer || theme.tertiaryContainer
        theme.onTertiaryContainer = palette.onTertiaryContainer || theme.onTertiaryContainer

        theme.surface = palette.surface || theme.surface
        theme.onSurface = palette.onSurface || theme.onSurface
        theme.surfaceVariant = palette.surfaceVariant || theme.surfaceVariant
        theme.onSurfaceVariant = palette.onSurfaceVariant || theme.onSurfaceVariant

        theme.background = palette.background || theme.background
        theme.onBackground = palette.onBackground || theme.onBackground

        theme.outline = palette.outline || theme.outline
        theme.outlineVariant = palette.outlineVariant || theme.outlineVariant

        theme.error = palette.error || theme.error
        theme.onError = palette.onError || theme.onError
        theme.errorContainer = palette.errorContainer || theme.errorContainer
        theme.onErrorContainer = palette.onErrorContainer || theme.onErrorContainer

        theme.playerProgress = palette.primary || theme.playerProgress
        theme.playerBarBg = palette.surface || theme.playerBarBg
        theme.playerBarBorder = palette.outline || theme.playerBarBorder
        theme.shadowColor = palette.shadow || theme.shadowColor
        theme.scrim = palette.scrim || theme.scrim
    }

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
    property color shadowColor: Qt.rgba(0, 0, 0, 0.25)

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
