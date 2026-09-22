import Foundation

/// Minimal HTML character-entity decoding for dict.cc term text.
///
/// dict.cc files encode non-ASCII glyphs as numeric entities, e.g.
/// `&#945;-Keratin` for `α-Keratin`. We decode numeric (decimal and hex) forms
/// plus the handful of named entities that can appear in term text. This is
/// deliberately small and dependency-free rather than pulling in a full HTML
/// parser we do not need.
public enum HTMLEntities {
    private static let named: [String: String] = [
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&nbsp;": "\u{00A0}",
    ]

    /// Decode entities in `text`. Returns the input unchanged when it contains
    /// no `&`, so the common case (the vast majority of lines) stays cheap.
    public static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var result = ""
        result.reserveCapacity(text.count)

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            guard char == "&" else {
                result.append(char)
                index = text.index(after: index)
                continue
            }

            // Find the terminating ';' within a short window; entities are short,
            // so cap the scan to avoid swallowing a stray '&' in normal prose.
            guard let semicolon = text[index...].firstIndex(of: ";"),
                  text.distance(from: index, to: semicolon) <= 12 else {
                result.append(char)
                index = text.index(after: index)
                continue
            }

            let entity = String(text[index...semicolon])
            if let decoded = decodeEntity(entity) {
                result.append(decoded)
                index = text.index(after: semicolon)
            } else {
                // Not a recognised entity: emit the '&' literally and continue.
                result.append(char)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func decodeEntity(_ entity: String) -> String? {
        if let named = named[entity] { return named }

        // Numeric: &#945; (decimal) or &#x3B1; (hex).
        guard entity.hasPrefix("&#"), entity.hasSuffix(";") else { return nil }
        let body = entity.dropFirst(2).dropLast() // strip "&#" and ";"
        let scalarValue: UInt32?
        if body.first == "x" || body.first == "X" {
            scalarValue = UInt32(body.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(body, radix: 10)
        }
        guard let value = scalarValue, let scalar = Unicode.Scalar(value) else {
            return nil
        }
        return String(scalar)
    }
}
