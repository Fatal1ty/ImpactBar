import Combine
import Foundation

enum OverlayOrientation: String, CaseIterable {
    case horizontal
    case vertical
}

@MainActor
final class ImpactBarModel: ObservableObject {
    private static let showsShadowKey = "ImpactBar.ShowsShadow"
    private static let hidesWhenIdleKey = "ImpactBar.HidesWhenIdle"
    private static let orientationKey = "ImpactBar.Orientation"
    private static let turretFeatureEnabledKey = "ImpactBar.Features.Turrets.Enabled"
    private static let neutralizerFeatureEnabledKey = "ImpactBar.Features.Neutralizers.Enabled"

    @Published private(set) var quality: HitQuality?
    @Published private(set) var rollingScore: Double?
    @Published private(set) var eventID = 0
    @Published private(set) var wreckEventID = 0
    @Published private(set) var lastEventAt: Date?
    @Published private(set) var weapon = ""
    @Published private(set) var target = ""
    @Published private(set) var neutralizerLastAmountGJ: Int?
    @Published private(set) var neutralizerTotalAmountGJ: Int?
    @Published private(set) var neutralizerState: NeutralizerState?
    @Published private(set) var neutralizerCadenceIndex = 0
    @Published private(set) var neutralizerCadenceEventCount = 0
    @Published private(set) var neutralizerEventID = 0
    @Published private(set) var neutralizerLastEventAt: Date?
    @Published private(set) var neutralizerIdleAfter: TimeInterval = 25.5
    @Published var isEditing = false
    @Published var showsShadow: Bool {
        didSet {
            defaults.set(showsShadow, forKey: Self.showsShadowKey)
        }
    }
    @Published var hidesWhenIdle: Bool {
        didSet {
            defaults.set(hidesWhenIdle, forKey: Self.hidesWhenIdleKey)
        }
    }
    @Published var orientation: OverlayOrientation {
        didSet {
            defaults.set(orientation.rawValue, forKey: Self.orientationKey)
        }
    }
    @Published var turretFeatureEnabled: Bool {
        didSet {
            defaults.set(turretFeatureEnabled, forKey: Self.turretFeatureEnabledKey)
        }
    }
    @Published var neutralizerFeatureEnabled: Bool {
        didSet {
            defaults.set(
                neutralizerFeatureEnabled,
                forKey: Self.neutralizerFeatureEnabledKey
            )
        }
    }
    private let defaults: UserDefaults
    private let parser = CombatLogParser()
    private let classifier = TurretClassifier()
    private var tracker = TurretQualityTracker()
    private var neutralizerTracker = NeutralizerTracker()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsShadow = defaults.object(forKey: Self.showsShadowKey) as? Bool ?? true
        hidesWhenIdle = defaults.object(forKey: Self.hidesWhenIdleKey) as? Bool ?? true
        orientation = defaults.string(forKey: Self.orientationKey)
            .flatMap(OverlayOrientation.init(rawValue:)) ?? .horizontal
        turretFeatureEnabled = defaults.object(
            forKey: Self.turretFeatureEnabledKey
        ) as? Bool ?? true
        neutralizerFeatureEnabled = defaults.object(
            forKey: Self.neutralizerFeatureEnabledKey
        ) as? Bool ?? true
    }

    func consume(logLine: String) {
        if parser.indicatesTargetGone(logLine) {
            reset()
            return
        }

        if neutralizerFeatureEnabled,
           let event = parser.parseNeutralizer(logLine) {
            publish(event)
            return
        }

        guard turretFeatureEnabled,
              let event = parser.parse(logLine),
              classifier.isTurret(event.weapon) else {
            return
        }

        publish(event)
    }

    func previewNextQuality() {
        let qualities = HitQuality.allCases
        let nextIndex: Int

        if let quality,
           let currentIndex = qualities.firstIndex(of: quality) {
            nextIndex = qualities.index(after: currentIndex) == qualities.endIndex
                ? qualities.startIndex
                : qualities.index(after: currentIndex)
        } else {
            nextIndex = qualities.startIndex
        }

        publish(
            TurretHitEvent(
                quality: qualities[nextIndex],
                weapon: "Preview Turret",
                target: "Preview Target \(nextIndex)"
            )
        )
    }

    func previewNextNeutralizerState() {
        let states = NeutralizerState.allCases
        let nextIndex: Int

        if let neutralizerState,
           let currentIndex = states.firstIndex(of: neutralizerState) {
            nextIndex = states.index(after: currentIndex) == states.endIndex
                ? states.startIndex
                : states.index(after: currentIndex)
        } else {
            nextIndex = states.startIndex
        }

        let nextState = states[nextIndex]
        let previewAmount: Int
        switch nextState {
        case .draining: previewAmount = 360
        case .dry: previewAmount = 0
        case .pinned: previewAmount = 4
        case .recovered: previewAmount = 175
        }

        neutralizerLastAmountGJ = previewAmount
        neutralizerTotalAmountGJ = (neutralizerTotalAmountGJ ?? 0) + previewAmount
        neutralizerState = nextState
        neutralizerCadenceIndex = neutralizerCadenceEventCount == 0
            ? 0
            : (neutralizerCadenceIndex + 1) % NeutralizerTracker.cadenceSegmentCount
        neutralizerCadenceEventCount = min(
            NeutralizerTracker.cadenceSegmentCount,
            neutralizerCadenceEventCount + 1
        )
        neutralizerLastEventAt = Date()
        neutralizerEventID &+= 1
    }

    func reset() {
        tracker.reset()
        quality = nil
        rollingScore = nil
        weapon = ""
        target = ""
        lastEventAt = nil
        eventID &+= 1

        neutralizerTracker.reset()
        neutralizerLastAmountGJ = nil
        neutralizerTotalAmountGJ = nil
        neutralizerState = nil
        neutralizerCadenceIndex = 0
        neutralizerCadenceEventCount = 0
        neutralizerLastEventAt = nil
        neutralizerIdleAfter = 25.5
        neutralizerEventID &+= 1
    }

    private func publish(_ event: TurretHitEvent) {
        let now = Date()
        tracker.record(target: event.target, quality: event.quality, at: now)

        quality = event.quality
        rollingScore = tracker.rollingScore
        weapon = event.weapon
        target = event.target
        lastEventAt = now
        eventID &+= 1

        if event.quality == .wrecks {
            wreckEventID &+= 1
        }
    }

    private func publish(_ event: NeutralizerEvent) {
        let snapshot = neutralizerTracker.record(event: event, at: Date())

        neutralizerLastAmountGJ = snapshot.lastAmountGJ
        neutralizerTotalAmountGJ = snapshot.totalAmountGJ
        neutralizerState = snapshot.state
        neutralizerCadenceIndex = snapshot.cadenceIndex
        neutralizerCadenceEventCount = snapshot.cadenceEventCount
        neutralizerLastEventAt = snapshot.lastEventAt
        neutralizerIdleAfter = snapshot.idleAfter
        neutralizerEventID &+= 1
    }
}
