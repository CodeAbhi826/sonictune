// theme/Theme.qml — SonicTune's design tokens (ArchiveTune-inspired).
//
// Deep warm charcoal chassis + ArchiveTune sage-green accent, massive
// rounded corners. Three modes: dark (default), light, and archive (a warm
// analog/paper variant).
//
// Usage: `import "theme"` then `color: Theme.background`, etc.
// Theme is a QML singleton (registered via pragma Singleton + qmldir).
// To switch themes at runtime: Theme.setTheme("light").

pragma Singleton

import QtQuick
import QtQuick.Controls.Material

QtObject {
    id: theme

    // Active theme name: "dark" | "light" | "archive"
    property string mode: "dark"

    // Material theme constant for QtQuick.Controls (light/archive both read
    // as "light" chrome to Controls — archive supplies its own dark-enough
    // surfaces so this only really matters for built-in control internals).
    readonly property int materialTheme: mode === "dark" ? Material.Dark : Material.Light

    readonly property var palettes: ({
        dark: {
            background:          "#121212",  // ArchiveTune deep warm charcoal
            surface:             "#1E1E1E",
            surfaceContainer:    "#2A2A2A",
            surfaceContainerHigh: "#333333",
            surfaceElevated:     "#2A2A2A",
            surfaceOverlay:      "#1A1A1A",
            playerBarBg:         "#1E1E1E",
            primary:             "#C4D6B0",  // ArchiveTune sage green
            onPrimary:           "#121212",
            primaryContainer:    "#2A3328",
            onPrimaryContainer:  "#C4D6B0",
            signal:              "#C4D6B0",
            onSignal:            "#121212",
            signalContainer:     "#2A3328",
            onSignalContainer:   "#DCEBD0",
            onSurface:           "#FFFFFF",
            onSurfaceVariant:    "#FFFFFF",
            onSurfaceMuted:      "#FFFFFF",
            outline:             "#333333",
            outlineStrong:       "#4A4A4A",
            error:               "#F2B8B5",
            onError:             "#601410",
            success:             "#6FCF97",
            scrim:               "#000000",
        },
        light: {
            background:          "#F4F2ED",
            surface:             "#FFFFFF",
            surfaceContainer:    "#E9E6DF",
            surfaceContainerHigh: "#DDD8CE",
            surfaceElevated:     "#FFFFFF",
            surfaceOverlay:      "#F4F2ED",
            playerBarBg:         "#FFFFFF",
            primary:             "#4A5D3A",
            onPrimary:           "#FFFFFF",
            primaryContainer:    "#D8E8C8",
            onPrimaryContainer:  "#22351A",
            signal:              "#4A5D3A",
            onSignal:            "#FFFFFF",
            signalContainer:     "#D8E8C8",
            onSignalContainer:   "#22351A",
            onSurface:           "#1B1B1B",
            onSurfaceVariant:    "#555555",
            onSurfaceMuted:      "#8A8A8A",
            outline:             "#C8C4BA",
            outlineStrong:       "#A8A296",
            error:               "#B3261E",
            onError:             "#FFFFFF",
            success:             "#2E7D46",
            scrim:               "#000000",
        },
        archive: {
            // Warm analog: aged paper + sage, deliberately screen-quiet.
            background:          "#17150F",
            surface:             "#201D15",
            surfaceContainer:    "#2A261B",
            surfaceContainerHigh: "#383227",
            surfaceElevated:     "#2A261B",
            surfaceOverlay:      "#17150F",
            playerBarBg:         "#201D15",
            primary:             "#C4D6B0",
            onPrimary:           "#17150F",
            primaryContainer:    "#2A3328",
            onPrimaryContainer:  "#DCEBD0",
            signal:              "#9DB98A",
            onSignal:            "#17150F",
            signalContainer:     "#2A3328",
            onSignalContainer:   "#DCEBD0",
            onSurface:           "#F1E6D6",
            onSurfaceVariant:    "#B4A28A",
            onSurfaceMuted:      "#857560",
            outline:             "#3C3126",
            outlineStrong:       "#544534",
            error:               "#E08070",
            onError:             "#2B0704",
            success:             "#8FBF8A",
            scrim:               "#000000",
        }
    })

    // --- Convenience accessors — bind to these from components -------------
    readonly property color background: palettes[mode].background
    readonly property color surface: palettes[mode].surface
    readonly property color surfaceContainer: palettes[mode].surfaceContainer
    readonly property color surfaceContainerHigh: palettes[mode].surfaceContainerHigh
    readonly property color surfaceElevated: palettes[mode].surfaceElevated
    readonly property color surfaceOverlay: palettes[mode].surfaceOverlay
    readonly property color playerBarBg: palettes[mode].playerBarBg
    // Legacy alias kept because a few older bindings still use it.
    readonly property color surfaceVariant: palettes[mode].surfaceContainer
    readonly property color primary: palettes[mode].primary
    readonly property color onPrimary: palettes[mode].onPrimary
    readonly property color primaryContainer: palettes[mode].primaryContainer
    readonly property color onPrimaryContainer: palettes[mode].onPrimaryContainer
    readonly property color accent: palettes[mode].primary
    readonly property color signal: palettes[mode].signal
    // Material 3 "secondary" token set — mapped to the sage accent.
    readonly property color secondary: palettes[mode].signal
    readonly property color onSecondary: palettes[mode].onSignal
    readonly property color secondaryContainer: palettes[mode].signalContainer
    readonly property color onSecondaryContainer: palettes[mode].onSignalContainer
    readonly property color onSurface: palettes[mode].onSurface
    readonly property color foreground: palettes[mode].onSurface
    readonly property color onSurfaceVariant: palettes[mode].onSurfaceVariant
    readonly property color onSurfaceMuted: palettes[mode].onSurfaceMuted
    readonly property color outline: palettes[mode].outline
    readonly property color outlineStrong: palettes[mode].outlineStrong
    readonly property color error: palettes[mode].error
    readonly property color onError: palettes[mode].onError
    readonly property color success: palettes[mode].success
    readonly property color scrim: palettes[mode].scrim

    // --- Typography ----------------------------------------------------
    // Humanist sans for UI text; a monospace face reserved specifically for
    // numeric/technical readouts (timestamps, bitrate, counts).
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyMono: "JetBrains Mono"

    readonly property font fontDisplay: Qt.font({ family: fontFamily, pixelSize: 45, weight: Font.Bold, letterSpacing: -0.5 })
    readonly property font fontHeadlineLarge: Qt.font({ family: fontFamily, pixelSize: 28, weight: Font.Bold, letterSpacing: -0.25 })
    readonly property font fontHeadlineMedium: Qt.font({ family: fontFamily, pixelSize: 24, weight: Font.Bold, letterSpacing: -0.25 })
    readonly property font fontHeadlineSmall: Qt.font({ family: fontFamily, pixelSize: 20, weight: Font.DemiBold })
    readonly property font fontHeadline: Qt.font({ family: fontFamily, pixelSize: 28, weight: Font.Bold })
    readonly property font fontTitleLarge: Qt.font({ family: fontFamily, pixelSize: 22, weight: Font.Bold })
    readonly property font fontTitleMedium: Qt.font({ family: fontFamily, pixelSize: 16, weight: Font.Medium })
    readonly property font fontBodyLarge: Qt.font({ family: fontFamily, pixelSize: 16, weight: Font.Normal })
    readonly property font fontBodyMedium: Qt.font({ family: fontFamily, pixelSize: 14, weight: Font.Normal })
    readonly property font fontBodySmall: Qt.font({ family: fontFamily, pixelSize: 12, weight: Font.Normal })
    readonly property font fontLabelLarge: Qt.font({ family: fontFamily, pixelSize: 13, weight: Font.DemiBold, letterSpacing: 0.2 })
    readonly property font fontLabelSmall: Qt.font({ family: fontFamily, pixelSize: 11, weight: Font.Medium, letterSpacing: 0.6 })
    readonly property font fontLabel: Qt.font({ family: fontFamily, pixelSize: 11, weight: Font.Medium })
    readonly property font fontMono: Qt.font({ family: fontFamilyMono, pixelSize: 13, weight: Font.Normal })
    readonly property font fontMonoLarge: Qt.font({ family: fontFamilyMono, pixelSize: 15, weight: Font.Medium })

    // --- Spacing tokens (4dp grid) ---------------------------------------
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
    readonly property int spacingXl: 32
    readonly property int spacingXxl: 48

    // --- Radii (massive rounded corners) ------------------------------------
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 24
    readonly property int radiusPill: 9999
    readonly property int radiusFull: 9999

    // --- Motion ------------------------------------------------------------
    readonly property int durationFast: 100
    readonly property int durationBase: 200
    readonly property int durationSlow: 350
    readonly property int easingStandard: Easing.OutCubic

    function setTheme(name: string) {
        if (palettes[name]) {
            mode = name
        }
    }

    // Mix two colors — used for hover/press tonal states without needing
    // per-state colors hand-picked for every surface.
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        )
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
