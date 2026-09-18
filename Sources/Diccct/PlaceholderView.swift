import SwiftUI

/// Temporary panel content for the app-shell step. Replaced by the real search
/// UI (search field, language-pair picker, import, results grid) in the next
/// step.
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Diccct")
                .font(.headline)
            Text("UI coming next")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
