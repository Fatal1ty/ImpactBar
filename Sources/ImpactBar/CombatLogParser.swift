import Foundation

struct TurretHitEvent: Equatable {
    let quality: HitQuality
    let weapon: String
    let target: String
}

struct NeutralizerEvent: Equatable {
    let amountGJ: Int
    let targetKey: String
    let module: String
}

struct CombatLogParser {
    private static let qualityPattern = "Grazes|Glances Off|Hits|Penetrates|Smashes|Wrecks"

    private static let hitRegex = try! NSRegularExpression(
        pattern: #"^[-+]?\d[\d ,.]*\s+to\s+(.+)\s+-\s+(.+)\s+-\s+("# + qualityPattern + #")$"#,
        options: [.caseInsensitive]
    )

    private static let missRegex = try! NSRegularExpression(
        pattern: #"^Your(?: group of)?\s+.+\s+misses\s+(.+)\s+completely\s+-\s+(.+)$"#,
        options: [.caseInsensitive]
    )

    private static let neutralizerRegex = try! NSRegularExpression(
        pattern: #"^([\d ,.]+)\s+GJ\s+energy neutralized\s+(.+)\s+-\s+(.+Energy Neutralizer.*)$"#,
        options: [.caseInsensitive]
    )

    private static let characterRegex = try! NSRegularExpression(
        pattern: #"\[([^\]]+)\]"#
    )

    func parse(_ rawLine: String) -> TurretHitEvent? {
        guard rawLine.contains("(combat)") else { return nil }

        let plain = stripMarkup(from: rawLine)
        guard let message = plain.components(separatedBy: "(combat)").last?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }

        if let groups = captures(in: message, using: Self.hitRegex),
           groups.count == 3,
           let quality = HitQuality(logLabel: groups[2]) {
            return TurretHitEvent(
                quality: quality,
                weapon: groups[1].trimmingCharacters(in: .whitespaces),
                target: groups[0].trimmingCharacters(in: .whitespaces)
            )
        }

        if let groups = captures(in: message, using: Self.missRegex),
           groups.count == 2 {
            return TurretHitEvent(
                quality: .miss,
                weapon: groups[1].trimmingCharacters(in: .whitespaces),
                target: groups[0].trimmingCharacters(in: .whitespaces)
            )
        }

        return nil
    }

    func parseNeutralizer(_ rawLine: String) -> NeutralizerEvent? {
        guard rawLine.contains("(combat)") else { return nil }

        let plain = stripMarkup(from: rawLine)
        guard let message = plain.components(separatedBy: "(combat)").last?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let groups = captures(in: message, using: Self.neutralizerRegex),
              groups.count == 3 else {
            return nil
        }

        let normalizedAmount = groups[0].filter(\.isNumber)
        guard let amountGJ = Int(normalizedAmount) else { return nil }

        let rawTarget = groups[1].trimmingCharacters(in: .whitespaces)
        let targetKey = captures(in: rawTarget, using: Self.characterRegex)?.first
            ?? rawTarget.replacingOccurrences(
                of: #"\s+-\s*$"#,
                with: "",
                options: .regularExpression
            )

        return NeutralizerEvent(
            amountGJ: amountGJ,
            targetKey: targetKey,
            module: groups[2].trimmingCharacters(in: .whitespaces)
        )
    }

    func indicatesTargetGone(_ rawLine: String) -> Bool {
        guard rawLine.contains("(notify)") else { return false }

        let message = stripMarkup(from: rawLine).lowercased()

        // Drone notifications are deliberately ignored in this version.
        guard !message.contains("drone") else { return false }

        return message.contains("the target is no longer present")
            || message.contains("the item it was targeted at is no longer present")
    }

    private func stripMarkup(from line: String) -> String {
        line.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
    }

    private func captures(
        in text: String,
        using regex: NSRegularExpression
    ) -> [String]? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.range.location != NSNotFound else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}
