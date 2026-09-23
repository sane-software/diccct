import SwiftUI
import AppKit

/// A search text field backed by an AppKit `NSTextField`.
///
/// SwiftUI's `TextField` on macOS gives no control over the field's selection,
/// and `NSTextField` selects all of its text when it becomes first responder and
/// again when Return is pressed — which means typing after a search would replace
/// the whole query. This wrapper keeps the caret at the end instead (on both
/// focus and submit), so you can just keep typing.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    /// Changes whenever the field should take focus (e.g. the panel was shown).
    var focusToken: Int
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.isBezeled = true
        field.lineBreakMode = .byClipping
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        // Return is handled in the delegate's doCommandBy (not via target/action),
        // so we can suppress NSTextField's default select-all-on-Return entirely.
        // Stretch to fill the width the layout gives it, rather than hugging its
        // intrinsic content size.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder
        field.isEnabled = isEnabled

        // Take focus when the token changes, placing the caret at the end (never
        // selecting all).
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            guard isEnabled else { return }
            DispatchQueue.main.async {
                guard field.window?.makeFirstResponder(field) == true else { return }
                Self.moveCaretToEnd(of: field)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Collapse the selection to the end of the text (caret after the last char).
    fileprivate static func moveCaretToEnd(of field: NSTextField) {
        guard let editor = field.currentEditor() else { return }
        let end = (field.stringValue as NSString).length
        editor.selectedRange = NSRange(location: end, length: 0)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: SearchField
        var lastFocusToken: Int = .min

        init(_ parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        /// Intercept keys the field editor is about to act on. For Return we run
        /// the submit and return true to say we handled it — so AppKit does NOT
        /// perform its default single-line Return behaviour (end editing and
        /// select the whole text). The caret is therefore left exactly where it
        /// is, with no selection, and typing continues the query.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
