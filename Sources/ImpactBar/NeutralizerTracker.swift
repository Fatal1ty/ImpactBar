import Foundation

enum NeutralizerState: String, CaseIterable {
    case draining = "DRAINING"
    case dry = "DRY"
    case pinned = "PINNED"
    case recovered = "RECOVERED"
}

struct NeutralizerSnapshot: Equatable {
    let lastAmountGJ: Int
    let totalAmountGJ: Int
    let state: NeutralizerState
    let cadenceIndex: Int
    let cadenceEventCount: Int
    let lastEventAt: Date
    let idleAfter: TimeInterval
}

struct NeutralizerTracker {
    static let volleyWindow: TimeInterval = 2
    static let inactivityTimeout: TimeInterval = 10 * 60
    static let cadenceSegmentCount = 3
    private static let pinnedThreshold = 0.50
    private static let recoveryThreshold = 0.75

    private(set) var activeTarget: String?
    private(set) var lastAmountGJ = 0
    private(set) var totalAmountGJ = 0
    private(set) var state: NeutralizerState?
    private(set) var cadenceIndex = 0
    private(set) var cadenceEventCount = 0
    private(set) var lastEventAt: Date?
    private(set) var estimatedCycleDuration: TimeInterval = 15
    private var drainCeilingGJ = 0
    private var peakDrainGJ = 0

    mutating func record(event: NeutralizerEvent, at date: Date) -> NeutralizerSnapshot {
        let timedOut = lastEventAt.map {
            date.timeIntervalSince($0) >= Self.inactivityTimeout
        } ?? false
        if activeTarget != event.targetKey || timedOut {
            reset()
            activeTarget = event.targetKey
        }

        let joinsCurrentVolley = lastEventAt.map {
            date.timeIntervalSince($0) <= Self.volleyWindow
        } ?? false

        if joinsCurrentVolley {
            lastAmountGJ += event.amountGJ
        } else {
            updateCycleEstimate(with: date)
            lastAmountGJ = event.amountGJ
            cadenceIndex = cadenceEventCount == 0
                ? 0
                : (cadenceIndex + 1) % Self.cadenceSegmentCount
            cadenceEventCount = min(Self.cadenceSegmentCount, cadenceEventCount + 1)
        }

        totalAmountGJ += event.amountGJ
        state = nextState(
            for: event.amountGJ,
            joinsCurrentVolley: joinsCurrentVolley
        )
        lastEventAt = date

        return NeutralizerSnapshot(
            lastAmountGJ: lastAmountGJ,
            totalAmountGJ: totalAmountGJ,
            state: state ?? .draining,
            cadenceIndex: cadenceIndex,
            cadenceEventCount: cadenceEventCount,
            lastEventAt: date,
            idleAfter: min(45, max(8, estimatedCycleDuration * 1.7))
        )
    }

    mutating func reset() {
        activeTarget = nil
        lastAmountGJ = 0
        totalAmountGJ = 0
        state = nil
        cadenceIndex = 0
        cadenceEventCount = 0
        lastEventAt = nil
        estimatedCycleDuration = 15
        drainCeilingGJ = 0
        peakDrainGJ = 0
    }

    private mutating func updateCycleEstimate(with date: Date) {
        guard let lastEventAt else { return }
        let interval = date.timeIntervalSince(lastEventAt)
        guard interval > Self.volleyWindow, interval <= 60 else { return }

        estimatedCycleDuration = estimatedCycleDuration * 0.65 + interval * 0.35
    }

    private mutating func nextState(
        for amountGJ: Int,
        joinsCurrentVolley: Bool
    ) -> NeutralizerState {
        if amountGJ == 0 {
            switch state {
            case .dry, .pinned:
                return .pinned
            default:
                return .dry
            }
        }

        if peakDrainGJ == 0 {
            peakDrainGJ = amountGJ
            drainCeilingGJ = amountGJ
            return .draining
        }

        if Double(amountGJ) <= Double(drainCeilingGJ) * Self.pinnedThreshold {
            return .pinned
        }

        // Bound downward adjustments by the peak so a series of partial drains cannot ratchet down the ceiling.
        guard Double(amountGJ) >= Double(peakDrainGJ) * Self.recoveryThreshold else {
            return state ?? .draining
        }

        peakDrainGJ = max(peakDrainGJ, amountGJ)
        drainCeilingGJ = amountGJ

        switch state {
        case .dry, .pinned:
            return .recovered
        case .recovered where joinsCurrentVolley:
            return .recovered
        default:
            return .draining
        }
    }
}
