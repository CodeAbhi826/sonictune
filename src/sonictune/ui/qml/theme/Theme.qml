// theme/Theme.qml — SonicTune's design tokens.
//
// Deliberately not generic Material-You purple: the palette is built
// around the idea of a hi-fi component / mixing desk — a near-black
// chassis, a warm amber accent (the "VU needle"), and a cool signal-teal
// used sparingly for anything actually live (current playback, active
// levels). Three modes: dark (default), light, and archive (a warm
// analog/paper variant for people who want something less "screen-like").
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
            background:        "#0C0D10",
            surface:            "#141519",
            surfaceContainer:   "#1B1D22",
            surfaceContainerHigh: "#25272E",
            primary:            "#EFAB47",
            onPrimary:          "#241500",
            primaryContainer:   "#3D2B0B",
            signal:             "#4FD3C4",
            onSignal:           "#001414",
            signalContainer:    "#0E3A33",
            onSignalContainer:  "#ADF1E6",
            onSurface:          "#EDEEF0",
            onSurfaceVariant:   "#9AA0AC",
            outline:            "#2E313A",
            outlineStrong:      "#454954",
            error:              "#F0685E",
            onError:            "#2B0704",
            success:            "#6FCF97",
            scrim:              "#000000",
        },
        light: {
            background:        "#FAF7F2",
            surface:            "#FFFFFF",
            surfaceContainer:   "#F1ECE2",
            surfaceContainerHigh: "#E7E0D2",
            primary:            "#95591A",
            onPrimary:          "#FFFFFF",
            primaryContainer:   "#FFDDB0",
            signal:             "#0E7C6E",
            onSignal:           "#FFFFFF",
            signalContainer:    "#A6F0E5",
            onSignalContainer:  "#00201B",
            onSurface:          "#221A10",
            onSurfaceVariant:   "#6F6357",
            outline:            "#E3DACA",
            outlineStrong:      "#C9BCA5",
            error:              "#B3261E",
            onError:            "#FFFFFF",
            success:            "#2E7D46",
            scrim:              "#000000",
        },
        archive: {
            // Warm analog: aged paper + brass, deliberately screen-quiet.
            background:        "#181310",
            surface:            "#221B16",
            surfaceContainer:   "#2C231C",
            surfaceContainerHigh: "#392E24",
            primary:            "#E3A25E",
            onPrimary:          "#241505",
            primaryContainer:   "#4A3018",
            signal:             "#7FBFA0",
            onSignal:           "#1B0500",
            signalContainer:    "#2E5246",
            onSignalContainer:  "#CCEBDD",
            onSurface:          "#F1E6D6",
            onSurfaceVariant:   "#B4A28A",
            outline:            "#3C3126",
            outlineStrong:      "#544534",
            error:              "#E08070",
            onError:            "#2B0704",
            success:            "#8FBF8A",
            scrim:              "#000000",
        }
    })

    // --- Convenience accessors — bind to these from components -------------
    readonly property color background: palettes[mode].background
    readonly property color surface: palettes[mode].surface
    readonly property color surfaceContainer: palettes[mode].surfaceContainer
    readonly property color surfaceContainerHigh: palettes[mode].surfaceContainerHigh
    // Legacy alias kept because a few older bindings still use it.
    readonly property color surfaceVariant: palettes[mode].surfaceContainer
    readonly property color primary: palettes[mode].primary
    readonly property color onPrimary: palettes[mode].onPrimary
    readonly property color primaryContainer: palettes[mode].primaryContainer
    readonly property color accent: palettes[mode].primary
    readonly property color signal: palettes[mode].signal
    // Material 3 "secondary" token set — mapped to the signal teal. The
    // theme's own palette calls it `signal`; these spec-compliant names are
    // kept as aliases so components can use the standard M3 token names.
    readonly property color secondary: palettes[mode].signal
    readonly property color onSecondary: palettes[mode].onSignal
    readonly property color secondaryContainer: palettes[mode].signalContainer
    readonly property color onSecondaryContainer: palettes[mode].onSignalContainer
    readonly property color onSurface: palettes[mode].onSurface
    readonly property color foreground: palettes[mode].onSurface
    readonly property color onSurfaceVariant: palettes[mode].onSurfaceVariant
    readonly property color outline: palettes[mode].outline
    readonly property color outlineStrong: palettes[mode].outlineStrong
    readonly property color error: palettes[mode].error
    readonly property color onError: palettes[mode].onError
    readonly property color success: palettes[mode].success
    readonly property color scrim: palettes[mode].scrim

    // --- Typography ----------------------------------------------------
    // Humanist sans for UI text; a monospace face reserved specifically for
    // numeric/technical readouts (timestamps, bitrate, counts) — the one
    // place a second type family is earned, since that content really is
    // tabular/technical rather than prose.
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyMono: "JetBrains Mono"

    readonly property font fontDisplay: Qt.font({ family: fontFamily, pixelSize: 40, weight: Font.DemiBold, letterSpacing: -0.5 })
    readonly property font fontHeadlineLarge: Qt.font({ family: fontFamily, pixelSize: 28, weight: Font.DemiBold, letterSpacing: -0.25 })
    readonly property font fontHeadlineMedium: Qt.font({ family: fontFamily, pixelSize: 24, weight: Font.DemiBold, letterSpacing: -0.25 })
    readonly property font fontHeadlineSmall: Qt.font({ family: fontFamily, pixelSize: 20, weight: Font.DemiBold })
    readonly property font fontTitleLarge: Qt.font({ family: fontFamily, pixelSize: 18, weight: Font.DemiBold })
    readonly property font fontTitleMedium: Qt.font({ family: fontFamily, pixelSize: 15, weight: Font.DemiBold })
    readonly property font fontBodyLarge: Qt.font({ family: fontFamily, pixelSize: 15, weight: Font.Normal })
    readonly property font fontBodyMedium: Qt.font({ family: fontFamily, pixelSize: 13, weight: Font.Normal })
    readonly property font fontBodySmall: Qt.font({ family: fontFamily, pixelSize: 12, weight: Font.Normal })
    readonly property font fontLabelLarge: Qt.font({ family: fontFamily, pixelSize: 13, weight: Font.DemiBold, letterSpacing: 0.2 })
    readonly property font fontLabelSmall: Qt.font({ family: fontFamily, pixelSize: 11, weight: Font.DemiBold, letterSpacing: 0.6 })
    readonly property font fontMono: Qt.font({ family: fontFamilyMono, pixelSize: 12, weight: Font.Normal })
    readonly property font fontMonoLarge: Qt.font({ family: fontFamilyMono, pixelSize: 15, weight: Font.Medium })

    // --- Spacing tokens --------------------------------------------------
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
    readonly property int spacingXl: 32
    readonly property int spacingXxl: 48

    // --- Radii -------------------------------------------------------------
    readonly property int radiusSm: 4
    readonly property int radiusMd: 8
    readonly property int radiusLg: 12
    readonly property int radiusXl: 16
    readonly property int radiusPill: 9999
    readonly property int radiusFull: 9999

    // --- Motion ------------------------------------------------------------
    readonly property int durationFast: 100
    readonly property int durationBase: 180
    readonly property int durationSlow: 320
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
