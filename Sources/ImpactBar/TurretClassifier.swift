import Foundation

struct TurretClassifier {
    private let turretKeywords = [
        "laser",
        "blaster",
        "railgun",
        "autocannon",
        "artillery",
        "disintegrator"
    ]

    func isTurret(_ weapon: String) -> Bool {
        let normalized = weapon.lowercased()
        return turretKeywords.contains { normalized.contains($0) }
    }
}
