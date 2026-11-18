import AppKit
import SwiftUI

struct HitQualityPaletteColor {
    let red: Double
    let green: Double
    let blue: Double

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    var appKitColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1)
    }

    static func interpolated(for score: Double) -> HitQualityPaletteColor {
        let anchors: [(Double, HitQualityPaletteColor)] = [
            (0.000, HitQuality.miss.paletteColor),
            (0.411, HitQuality.grazes.paletteColor),
            (0.502, HitQuality.glancesOff.paletteColor),
            (0.639, HitQuality.hits.paletteColor),
            (0.821, HitQuality.penetrates.paletteColor),
            (1.000, HitQuality.smashes.paletteColor)
        ]
        let boundedScore = min(max(score, 0), 1)

        guard let upperIndex = anchors.firstIndex(where: { boundedScore <= $0.0 }) else {
            return anchors[anchors.count - 1].1
        }
        guard upperIndex > 0 else { return anchors[0].1 }

        let lower = anchors[upperIndex - 1]
        let upper = anchors[upperIndex]
        let fraction = (boundedScore - lower.0) / (upper.0 - lower.0)

        return HitQualityPaletteColor(
            red: lower.1.red + (upper.1.red - lower.1.red) * fraction,
            green: lower.1.green + (upper.1.green - lower.1.green) * fraction,
            blue: lower.1.blue + (upper.1.blue - lower.1.blue) * fraction
        )
    }
}

extension HitQuality {
    var paletteColor: HitQualityPaletteColor {
        switch self {
        case .miss: HitQualityPaletteColor(red: 0.71, green: 0.22, blue: 0.22)
        case .grazes: HitQualityPaletteColor(red: 0.66, green: 0.35, blue: 0.15)
        case .glancesOff: HitQualityPaletteColor(red: 0.66, green: 0.56, blue: 0.25)
        case .hits: HitQualityPaletteColor(red: 0.45, green: 0.59, blue: 0.61)
        case .penetrates: HitQualityPaletteColor(red: 0.30, green: 0.66, blue: 0.70)
        case .smashes: HitQualityPaletteColor(red: 0.21, green: 0.76, blue: 0.79)
        case .wrecks: HitQualityPaletteColor(red: 0.85, green: 0.97, blue: 0.98)
        }
    }

    var legendTitle: String {
        switch self {
        case .miss: "Miss · 0%"
        case .grazes: "Grazes · 41%"
        case .glancesOff: "Glances Off · 50%"
        case .hits: "Hits · 64%"
        case .penetrates: "Penetrates · 82%"
        case .smashes: "Smashes · 100%"
        case .wrecks: "Wrecks · Special"
        }
    }
}
