import Foundation

/// Manages the on-disk location of dict.cc translation files:
/// `~/Library/Application Support/Diccct/`.
///
/// The dict.cc license permits private use only and forbids redistribution, so
/// these files intentionally live outside the app bundle and outside the git
/// repo. The user imports them (via the app or by dropping files in with a
/// script). No derived caches or JSON are written — parsing always happens from
/// the original files, avoiding any out-of-sync state.
public struct DataDirectory {
    public let url: URL

    /// A dataset present in the directory: its language pair and file location.
    public struct Available: Hashable, Sendable {
        public let pair: LanguagePair
        public let fileURL: URL
    }

    public enum ImportError: Error, Equatable {
        /// The chosen file is not a dict.cc vocabulary file (no valid header).
        case notADictccFile
        case copyFailed(String)
    }

    public init(url: URL) {
        self.url = url
    }

    /// Default location under the user's Application Support.
    public static func standard() -> DataDirectory {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DataDirectory(url: base.appendingPathComponent("Diccct", isDirectory: true))
    }

    /// Create the directory if it does not exist yet.
    @discardableResult
    public func ensureExists() throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Scan the directory once for valid dict.cc `.txt` files, returning the
    /// datasets found, sorted deterministically by pair label. Files that are not
    /// valid dict.cc files are silently skipped (they simply do not appear).
    public func availableDatasets() -> [Available] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [Available] = []
        for fileURL in contents where fileURL.pathExtension.lowercased() == "txt" {
            guard let pair = try? DictccParser.detectPair(atPath: fileURL.path) else { continue }
            found.append(Available(pair: pair, fileURL: fileURL))
        }
        // Deterministic order => predictable "first pair wins on launch".
        return found.sorted { $0.pair < $1.pair }
    }

    /// Import a dict.cc file: validate its header, then copy it into the data
    /// directory under the pair's canonical filename (overwriting an existing
    /// file for the same pair, i.e. updating it). Returns the imported pair.
    ///
    /// Fails loud: an invalid file throws rather than being silently ignored.
    @discardableResult
    public func importFile(from sourceURL: URL) throws -> LanguagePair {
        let pair: LanguagePair
        do {
            pair = try DictccParser.detectPair(atPath: sourceURL.path)
        } catch {
            throw ImportError.notADictccFile
        }

        try ensureExists()
        let destination = url.appendingPathComponent(pair.canonicalFileName)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
        } catch {
            throw ImportError.copyFailed(error.localizedDescription)
        }
        return pair
    }
}
