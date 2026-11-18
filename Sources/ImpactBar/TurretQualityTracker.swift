import Foundation

struct TurretQualityTracker {
    static let windowSize = 10
    static let inactivityTimeout: TimeInterval = 30

    private(set) var activeTarget: String?
    private(set) var lastEventAt: Date?
    private(set) var samples: [Double] = []

    var rollingScore: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    mutating func record(
        target: String,
        quality: HitQuality,
        at date: Date
    ) {
        let targetChanged = activeTarget != target
        let timedOut = lastEventAt.map {
            date.timeIntervalSince($0) >= Self.inactivityTimeout
        } ?? false

        if targetChanged || timedOut {
            samples.removeAll(keepingCapacity: true)
        }

        activeTarget = target
        lastEventAt = date

        guard let value = quality.rollingValue else { return }

        samples.append(value)
        if samples.count > Self.windowSize {
            samples.removeFirst(samples.count - Self.windowSize)
        }
    }

    mutating func reset() {
        activeTarget = nil
        lastEventAt = nil
        samples.removeAll(keepingCapacity: true)
    }
}
