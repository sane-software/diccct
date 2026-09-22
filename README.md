# SaneDiccct

A tiny macOS menu-bar app for looking up dict.cc translations. Click the menu-bar icon, a small window drops into the top-right corner of the screen, you type a word, press Enter, and get the matching translations — English on the left, German on the right — with selectable text you can copy.

SaneDiccct stays out of the way: it lives only in the menu bar (no Dock icon), floats above other windows without stealing focus, and closes again with a click on the icon or its minimize button.

## Features

- Menu-bar-only app (no Dock icon). Left-click the icon to open/close the window; right-click for a Quit menu.
- Non-activating floating window pinned to the top-right corner. Clicking other windows never sends it to the back.
- Drag it to another screen and it re-pins to that screen's top-right; it also re-pins (and shrinks to fit) when monitors are plugged or unplugged.
- Resizable; the size is remembered across restarts.
- Search matches either language (dict.cc behaviour), is case- and diacritic-insensitive (`grun` finds `grün`), and ranks exact matches first. Results are capped at 50 rows and scroll when they overflow.
- Search runs only on Enter; clearing or editing the field does not re-search. An empty query clears the results.
- Multiple language pairs: the picker lists every dict.cc file you've imported. Only the selected pair is held in memory.
- Light/dark mode follow the system automatically.

## Translation data

SaneDiccct does not ship with any dict.cc data. dict.cc vocabulary files are licensed for **private use only** and may not be redistributed, so they are never bundled with the app or committed to this repo.

You supply the data yourself by downloading a vocabulary file from <https://www.dict.cc/> (see their translation-file request page) and importing it. Files live in:

    ~/Library/Application Support/SaneDiccct/

There are two ways to import:

- In the app: click the import button (⤓) next to the language-pair picker and choose the downloaded `.txt` file.
- From the command line: `scripts/import-translation.sh /path/to/download.txt`

Both validate the dict.cc header and store the file under a canonical name (e.g. `de-en.txt`). Re-importing the same pair updates it. The directory is scanned once at launch; files added while the app is running are picked up on next launch (an in-app import is applied immediately).

Parsing happens directly from the original file every time — there are no derived caches or JSON, so there is nothing to get out of sync.

## Building

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+).

Assemble the app bundle:

    scripts/build-app.sh
    open SaneDiccct.app

Or run directly from the package during development:

    swift run SaneDiccct

## Development

    swift build
    swift test

The logic layer (`SaneDiccctCore`: dict.cc parsing, the search index, data-directory handling) is pure Foundation and fully unit-tested, independent of the AppKit/SwiftUI app shell.

A real-file integration test is skipped by default and runs only when pointed at an actual dict.cc export (which is never committed):

    SANEDICCCT_REAL_FILE=/path/to/export.txt swift test

## Design notes

- Zero third-party dependencies — only Apple's Foundation, AppKit, and SwiftUI.
- Hybrid shell: AppKit drives the status item and a non-activating floating `NSPanel`; SwiftUI renders the content inside it.
- No database. The selected pair's file is parsed into memory and searched with a linear scan over pre-folded UTF-8 bytes, which keeps a full-export search well under 100 ms.

## License

Application code: see repository. dict.cc translation data is **not** covered here and remains subject to dict.cc's own terms (private use, no redistribution).
