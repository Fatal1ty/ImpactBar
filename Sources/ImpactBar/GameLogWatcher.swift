import Foundation

struct CharacterLogSource: Equatable {
    let character: String
    let fileURL: URL
}

final class GameLogWatcher {
    typealias LineHandler = (String) -> Void
    typealias SourcesHandler = ([CharacterLogSource], String?) -> Void

    let directoryURL: URL

    private let queue = DispatchQueue(label: "ImpactBar.GameLogWatcher")
    private var timer: DispatchSourceTimer?
    private var activeFileURL: URL?
    private var preferredCharacter: String?
    private var byteOffset: UInt64 = 0
    private var partialLine = ""
    private var lastDirectoryScan = Date.distantPast
    private var publishedSourceSignature = ""
    private var onLine: LineHandler?
    private var onSourcesChanged: SourcesHandler?

    init(directoryURL: URL = GameLogWatcher.defaultDirectoryURL) {
        self.directoryURL = directoryURL
    }

    static var defaultDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/EVE/logs/Gamelogs", isDirectory: true)
    }

    func start(
        preferredCharacter: String?,
        onLine: @escaping LineHandler,
        onSourcesChanged: @escaping SourcesHandler
    ) {
        stop()
        self.preferredCharacter = preferredCharacter
        self.onLine = onLine
        self.onSourcesChanged = onSourcesChanged

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(120), leeway: .milliseconds(30))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        timer.resume()
    }

    func selectCharacter(_ character: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.preferredCharacter = character
            self.activeFileURL = nil
            self.lastDirectoryScan = .distantPast
            self.discoverAndSelectSource()
        }
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        onLine = nil
        onSourcesChanged = nil
    }

    deinit {
        stop()
    }

    static func listenerName(inHeader header: String) -> String? {
        for line in header.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Listener:") else { continue }

            let name = trimmed
                .dropFirst("Listener:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private func poll() {
        if activeFileURL == nil || Date().timeIntervalSince(lastDirectoryScan) >= 1.5 {
            discoverAndSelectSource()
            lastDirectoryScan = Date()
        }

        guard let activeFileURL else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: activeFileURL.path)
            guard let fileSize = attributes[.size] as? NSNumber else { return }
            let size = fileSize.uint64Value

            if size < byteOffset {
                byteOffset = 0
                partialLine = ""
            }

            guard size > byteOffset else { return }

            let handle = try FileHandle(forReadingFrom: activeFileURL)
            try handle.seek(toOffset: byteOffset)
            let data = try handle.readToEnd() ?? Data()
            try handle.close()

            byteOffset += UInt64(data.count)
            consume(data)
        } catch {
            // A log can briefly disappear while the client starts a new session.
            // The next directory scan will select the new active file.
        }
    }

    private func discoverAndSelectSource() {
        let sources = discoverSources()

        let selectedSource = preferredCharacter
            .flatMap { preferred in sources.first { $0.character == preferred } }
            ?? sources.first

        preferredCharacter = selectedSource?.character
        switchActiveFile(to: selectedSource?.fileURL)
        publishSourcesIfNeeded(sources, selectedCharacter: selectedSource?.character)
    }

    func discoverSources() -> [CharacterLogSource] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let datedFiles = files
            .filter { $0.pathExtension.lowercased() == "txt" }
            .compactMap { url -> (URL, Date)? in
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true else {
                    return nil
                }
                return (url, values.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.1 > $1.1 }

        let recentCutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let recentFiles = datedFiles.filter { $0.1 >= recentCutoff }
        let candidates = recentFiles.isEmpty
            ? Array(datedFiles.prefix(20))
            : Array(recentFiles.prefix(100))

        var seenCharacters = Set<String>()
        var sources: [CharacterLogSource] = []

        // Candidates are newest first, so the first file for a character is its
        // current session. Older sessions are intentionally ignored.
        for (url, _) in candidates {
            guard let character = listenerName(from: url),
                  seenCharacters.insert(character).inserted else {
                continue
            }
            sources.append(CharacterLogSource(character: character, fileURL: url))
        }

        return sources
    }

    private func listenerName(from url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            let data = try handle.read(upToCount: 4_096) ?? Data()
            try handle.close()
            return Self.listenerName(inHeader: String(decoding: data, as: UTF8.self))
        } catch {
            return nil
        }
    }

    private func switchActiveFile(to newURL: URL?) {
        guard newURL != activeFileURL else { return }

        activeFileURL = newURL
        partialLine = ""

        if let newURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: newURL.path),
           let fileSize = attributes[.size] as? NSNumber {
            // Tail from EOF: selecting a character must not replay an old fight.
            byteOffset = fileSize.uint64Value
        } else {
            byteOffset = 0
        }
    }

    private func publishSourcesIfNeeded(
        _ sources: [CharacterLogSource],
        selectedCharacter: String?
    ) {
        let signature = sources
            .map { "\($0.character)|\($0.fileURL.path)" }
            .joined(separator: "\n") + "\nselected=\(selectedCharacter ?? "")"

        guard signature != publishedSourceSignature else { return }
        publishedSourceSignature = signature
        onSourcesChanged?(sources, selectedCharacter)
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }

        let text = partialLine + String(decoding: data, as: UTF8.self)
        var lines = text.components(separatedBy: .newlines)

        if text.last?.isNewline == true {
            partialLine = ""
        } else {
            partialLine = lines.popLast() ?? ""
        }

        for line in lines where !line.isEmpty {
            onLine?(line)
        }
    }
}
