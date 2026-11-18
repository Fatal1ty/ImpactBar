import Foundation

enum HitQuality: String, CaseIterable, Equatable {
    case miss
    case grazes
    case glancesOff
    case hits
    case penetrates
    case smashes
    case wrecks

    var rollingValue: Double? {
        switch self {
        case .miss: 0.000
        case .grazes: 0.411
        case .glancesOff: 0.502
        case .hits: 0.639
        case .penetrates: 0.821
        case .smashes: 1.000
        case .wrecks: nil
        }
    }

    var label: String {
        switch self {
        case .miss: "Miss"
        case .grazes: "Grazes"
        case .glancesOff: "Glances Off"
        case .hits: "Hits"
        case .penetrates: "Penetrates"
        case .smashes: "Smashes"
        case .wrecks: "Wrecks"
        }
    }

    init?(logLabel: String) {
        switch logLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "grazes": self = .grazes
        case "glances off": self = .glancesOff
        case "hits": self = .hits
        case "penetrates": self = .penetrates
        case "smashes": self = .smashes
        case "wrecks": self = .wrecks
        default: return nil
        }
    }
}
