import XCTest
@testable import ImpactBar

@MainActor
final class FeatureToggleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "FeatureToggleTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFeaturesAreEnabledByDefaultAndPersistChanges() {
        let model = ImpactBarModel(defaults: defaults)

        XCTAssertTrue(model.turretFeatureEnabled)
        XCTAssertTrue(model.neutralizerFeatureEnabled)

        model.turretFeatureEnabled = false
        model.neutralizerFeatureEnabled = false

        let restored = ImpactBarModel(defaults: defaults)
        XCTAssertFalse(restored.turretFeatureEnabled)
        XCTAssertFalse(restored.neutralizerFeatureEnabled)
    }

    func testDisabledTurretFeatureIgnoresTurretEvents() {
        let model = ImpactBarModel(defaults: defaults)
        model.turretFeatureEnabled = false

        model.consume(
            logLine: #"[ 2026.10.28 14:26:31 ] (combat) 91 to Example Target - Dual Light Pulse Laser II - Penetrates"#
        )

        XCTAssertNil(model.quality)
        XCTAssertNil(model.rollingScore)
    }

    func testDisabledNeutralizerFeatureIgnoresNeutralizerEvents() {
        let model = ImpactBarModel(defaults: defaults)
        model.neutralizerFeatureEnabled = false

        model.consume(
            logLine: #"[ 2026.11.17 18:44:44 ] (combat) 180 GJ energy neutralized Gila [Example] - Medium Energy Neutralizer II"#
        )

        XCTAssertNil(model.neutralizerState)
        XCTAssertNil(model.neutralizerTotalAmountGJ)
    }
}
