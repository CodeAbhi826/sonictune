// components/Icon.qml — Material Symbols Rounded font-based icons.
// GPU-accelerated (font glyphs are cached as textures by Qt). Zero CPU
// cost per icon — solves the Canvas-based performance problem that
// froze the render thread with 30+ simultaneous paint operations.
//
// Font file: data/fonts/MaterialSymbolsRounded.ttf
// License:   OFL-1.1 (data/fonts/OFL-MaterialSymbols.txt)
// Family:    "Material Symbols Rounded" — auto-registered by app.py via
//            QFontDatabase.addApplicationFont() at startup.
//
// The map below covers the Material Symbols codepoints used across the
// codebase, plus legacy aliases (camelCase, snake_case, Material You
// names) so every existing caller continues to work without change.

import QtQuick
import "../theme"

Text {
    id: root

    property string name: "play"
    property int size: 24

    width: size
    height: size
    font.family: "Material Symbols Rounded"
    font.pixelSize: Math.round(size * 1.15)
    color: Theme.fgSurface
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    text: _glyph(root.name)

    function _glyph(n) {
        const map = {
            // --- Core navigation / app ---
            "home": "\ue88a",
            "search": "\ue8b6",
            "library": "\ue030",
            "settings": "\ue8b8",
            "menu": "\ue5d2",

            // --- Transport ---
            "play": "\ue037",
            "pause": "\ue034",
            "play_circle": "\ue038",
            "pause_circle": "\ue035",
            "play_arrow": "\ue037",
            "stop": "\ue047",
            "skip": "\ue044",
            "skip_next": "\ue044",
            "skip_previous": "\ue045",
            "previous": "\ue045",
            "next": "\ue044",

            // --- Repeat / shuffle ---
            "shuffle": "\ue043",
            "shuffle_on": "\ue043",
            "repeat": "\ue040",
            "repeat_on": "\ue040",
            "repeat_one": "\ue041",
            "repeat_one_on": "\ue041",

            // --- Volume ---
            "volume_up": "\ue050",
            "volumeHigh": "\ue050",
            "volume_down": "\ue04f",
            "volumeMed": "\ue050",
            "volumeLow": "\ue04f",
            "volume_mute": "\ue04e",
            "volumeMute": "\ue04e",
            "volume_off": "\ue04f",
            "speaker": "\ue050",

            // --- Lists / queue / actions ---
            "queue": "\ue03d",
            "queue_music": "\ue03d",
            "playlist": "\ue03d",
            "playlist_add": "\ue03d",
            "playlist_play": "\ue03d",
            "album": "\ue019",
            "artist": "\ue01a",
            "note": "\ue405",
            "musicNote": "\ue405",
            "music_off": "\ue440",
            "track": "\ue405",

            // --- UI controls ---
            "more_vert": "\ue5d4",
            "moreVert": "\ue5d4",
            "close": "\ue5cd",
            "add": "\ue145",
            "remove": "\ue15b",
            "clear": "\ue14c",
            "check": "\ue5ca",
            "edit": "\ue3c9",

            // --- Arrows ---
            "arrow_back": "\ue5c4",
            "arrow_upward": "\ue5d8",
            "arrowUpward": "\ue5d8",
            "arrow_downward": "\ue5db",
            "arrowDownward": "\ue5db",
            "chevronLeft": "\ue5cb",
            "chevronRight": "\ue5cc",
            "chevronDown": "\ue5cf",
            "chevronUp": "\ue5ce",

            // --- Media views ---
            "fullscreen": "\ue5d0",
            "fullscreen_exit": "\ue5d1",
            "closeFullscreen": "\ue5d1",
            "minimize": "\ue15b",
            "maximize": "\ue15a",
            "picture_in_picture": "\ue57f",
            "cast": "\ue307",

            // --- Library categories ---
            "lyrics": "\ue266",
            "history": "\ue889",
            "favorite": "\ue87d",
            "favoriteBorder": "\ue87e",
            "favorite_border": "\ue87e",
            "star": "\ue8ce",

            // --- Status ---
            "warning": "\ue002",
            "error": "\ue000",
            "info": "\ue88f",
            "check_circle": "\ue86c",
            "help": "\ue88f",

            // --- Toolbar / actions ---
            "refresh": "\ue5d5",
            "sync": "\ue627",
            "download": "\ue2bc",
            "download_done": "\ue2bd",
            "upload": "\ue2c6",
            "share": "\ue80d",
            "share_arrow": "\ue80d",
            "link": "\ue157",
            "external": "\ue89e",

            // --- Content ---
            "folder": "\ue2c7",
            "file_open": "\ue2c8",
            "backup": "\ue864",
            "collections": "\ue431",
            "content": "\ue25c",
            "sort": "\ue5d2",
            "filter": "\ue429",
            "tune": "\ue429",
            "settings_tune": "\ue429",
            "equalizer": "\ue429",
            "language": "\ue894",

            // --- Account / security ---
            "logout": "\ue9ba",
            "login": "\uea77",
            "person": "\ue7fd",
            "security": "\ue1f0",
            "keyboard": "\ue312",

            // --- Time ---
            "clock": "\ue8b5",
            "timer": "\ue425",
            "sleep": "\ue1fc",
            "calendar": "\ue935",

            // --- Stats / system ---
            "bar_chart": "\ue26b",
            "stats": "\ue26b",
            "memory": "\ue322",
            "devices": "\ue1b1",
            "device": "\ue1b1",
            "keyboardArrowUp": "\ue316",
            "keyboardArrowDown": "\ue313",
            "headphones": "\ue61c",
            "headset": "\ue310",

            // --- Local / db ---
            "local": "\ue1db",
            "database": "\ue1db",
            "storage": "\ue1db",

            // --- Misc ---
            "more_horiz": "\ue5d3",
            "lightbulb": "\ue0f0",
            "palette": "\ue40a",
            "notifications": "\ue7f4",
            "lock": "\ue897",
            "lock_open": "\ue898",
            "visibility": "\ue8f4",
            "visibility_off": "\ue8f5",
        }
        return map[n] || ""
    }
}
