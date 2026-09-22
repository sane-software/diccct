import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DiccctCore

/// The panel's content: a control row (search field · pair picker · import ·
/// minimize) above a two-column results grid.
struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            controlRow
            Divider()
            resultsArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { model.importErrorMessage != nil },
                set: { presented in if !presented { model.importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.importErrorMessage ?? "")
        }
    }

    // MARK: - Control row

    private var controlRow: some View {
        HStack(spacing: 8) {
            Button(action: { model.undo() }) {
                Image(systemName: "arrow.left")
            }
            .help("undo")
            .disabled(!model.canUndo)

            Button(action: { model.redo() }) {
                Image(systemName: "arrow.right")
            }
            .help("redo")
            .disabled(!model.canRedo)

            SearchField(
                text: $model.query,
                placeholder: searchPlaceholder,
                isEnabled: model.hasPairs,
                focusToken: model.focusRequest,
                onSubmit: { model.submitFromUser() }
            )
            .frame(maxWidth: .infinity)

            pairPicker

            Button(action: importTapped) {
                Image(systemName: "square.and.arrow.down")
            }
            .help("import translation")

            MinimizeButton { model.onRequestClose?() }
        }
        // The window is borderless (no titlebar); this padding is the only space
        // above the controls, and the empty area around them is the drag region.
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var pairPicker: some View {
        if model.hasPairs {
            Picker(
                "",
                selection: Binding(
                    get: { model.selectedPair },
                    set: { newValue in if let pair = newValue { model.select(pair) } }
                )
            ) {
                ForEach(model.availablePairs, id: \.self) { pair in
                    Text(pair.label).tag(Optional(pair))
                }
            }
            .labelsHidden()
            .fixedSize()
        } else {
            // No files loaded: a clearly-disabled dash signals missing config,
            // not a malfunction.
            Text("—")
                .foregroundStyle(.secondary)
                .frame(minWidth: 44)
                .help("No language pairs loaded")
        }
    }

    private var searchPlaceholder: String {
        model.hasPairs
            ? "Search…"
            : "No language pairs loaded yet, import with button on right side"
    }

    // MARK: - Results

    @ViewBuilder private var resultsArea: some View {
        if !model.hasPairs {
            hint("No language pairs loaded.\nClick the import button to add a dict.cc file.")
        } else if model.isLoading {
            hint("Loading…")
        } else if model.results.isEmpty {
            hint("Type a word and press Enter.")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.results) { entry in
                        ResultRow(entry: entry)
                        Divider()
                    }
                }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func importTapped() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Import"
        panel.message = "Choose a dict.cc translation file to import"
        // Accessory apps need to come forward for the modal dialog to be usable.
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            model.importFile(at: url)
        }
    }
}

/// The circular yellow "minimize" control, matching the traffic-light minimize
/// button used in the SaneWindowList app (14pt yellow circle, heavy minus glyph).
private struct MinimizeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(red: 0.99, green: 0.74, blue: 0.18))
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .help("minimize")
    }
}

/// One result row: left-column language flush to the centre divider, right-column
/// language flush from it — mirroring dict.cc. Both sides are selectable so text
/// can be copied.
struct ResultRow: View {
    let entry: TranslationEntry

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(entry.left)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .textSelection(.enabled)
            Divider()
            Text(entry.right)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .textSelection(.enabled)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
    }
}
