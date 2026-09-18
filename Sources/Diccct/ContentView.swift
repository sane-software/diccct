import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DiccctCore

/// The panel's content: a control row (search field · pair picker · import ·
/// minimize) above a two-column results grid.
struct ContentView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            controlRow
            Divider()
            resultsArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focusSearch() }
        .onChange(of: model.focusRequest) { _, _ in focusSearch() }
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
            TextField(searchPlaceholder, text: $model.query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .disabled(!model.hasPairs)
                .onSubmit { model.runSearch() }

            pairPicker

            Button(action: importTapped) {
                Image(systemName: "square.and.arrow.down")
            }
            .help("import translation")

            Button { model.onRequestClose?() } label: {
                Image(systemName: "minus")
            }
            .help("minimize")
        }
        // Top padding doubles as the window's grab area (drag handle).
        .padding(.horizontal, 10)
        .padding(.top, 10)
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

    private func focusSearch() {
        guard model.hasPairs else { return }
        // Defer so focus lands after the panel becomes key and the view is live.
        DispatchQueue.main.async { searchFocused = true }
    }

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
