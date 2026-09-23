import AppKit

/// Draws the menu-bar icon: an italic uppercase "D" inside a square with subtly
/// rounded corners. Rendered as a template image so macOS tints it correctly for
/// light/dark menu bars (only the alpha channel matters for template images).
enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // Rounded-square border.
        let inset: CGFloat = 1.5
        let rect = NSRect(x: inset, y: inset,
                          width: size.width - inset * 2,
                          height: size.height - inset * 2)
        let border = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        border.lineWidth = 1.5
        NSColor.black.setStroke()
        border.stroke()

        // Italic uppercase "D", centered.
        let baseFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: italicFont,
            .foregroundColor: NSColor.black,
        ]
        let letter = NSAttributedString(string: "D", attributes: attributes)
        let textSize = letter.size()
        let origin = NSPoint(x: (size.width - textSize.width) / 2,
                             y: (size.height - textSize.height) / 2)
        letter.draw(at: origin)

        image.unlockFocus()

        image.isTemplate = true
        return image
    }
}
