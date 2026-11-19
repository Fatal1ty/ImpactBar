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

    func testNeutralizerTimeoutClearsDisplayedValuesAtTenMinutes() {
        let model = ImpactBarModel(defaults: defaults)
        model.hidesWhenIdle = false
        let start = Date()
        model.consume(logLine: neutralizerLine(amount: 180), at: start)
        let eventID = model.neutralizerEventID

        model.resetNeutralizerIfInactive(at: start.addingTimeInterval(599))
        XCTAssertEqual(model.neutralizerTotalAmountGJ, 180)
        model.resetNeutralizerIfInactive(at: start.addingTimeInterval(600))

        assertNeutralizerIsCleared(model)
        XCTAssertGreaterThan(model.neutralizerEventID, eventID)
        XCTAssertFalse(model.hidesWhenIdle)

        model.consume(logLine: neutralizerLine(amount: 20), at: start.addingTimeInterval(601))
        XCTAssertEqual(model.neutralizerTotalAmountGJ, 20)
        XCTAssertEqual(model.neutralizerState, .draining)
    }

    func testOnlyNeutralizerActivityExtendsTheNeutralizerTimeout() {
        let model = ImpactBarModel(defaults: defaults)
        let start = Date()
        model.consume(logLine: neutralizerLine(amount: 180), at: start)
        model.consume(logLine: neutralizerLine(amount: 0), at: start.addingTimeInterval(590))
        model.resetNeutralizerIfInactive(at: start.addingTimeInterval(600))
        XCTAssertEqual(model.neutralizerTotalAmountGJ, 180)

        model.consume(
            logLine: "[ 2026.11.19 12:00:00 ] (combat) 91 to Example Target - Dual Light Pulse Laser II - Penetrates",
            at: start.addingTimeInterval(1_189)
        )
        model.resetNeutralizerIfInactive(at: start.addingTimeInterval(1_190))
        assertNeutralizerIsCleared(model)
        XCTAssertEqual(model.quality, .penetrates)
    }

    func testTimerClearsNeutralizerValuesWithoutAnotherLogEvent() async {
        let model = ImpactBarModel(defaults: defaults)
        model.consume(logLine: neutralizerLine(amount: 180), at: Date().addingTimeInterval(-599.9))
        let cleared = expectation(description: "Neutralizer values cleared by the idle timer")
        let subscription = model.$neutralizerLastAmountGJ.dropFirst().sink { value in
            if value == nil { cleared.fulfill() }
        }
        await fulfillment(of: [cleared], timeout: 3)
        assertNeutralizerIsCleared(model)
        withExtendedLifetime(subscription) {}
    }

    func testUndockingClearsOverlayValuesEvenWhenFeatureIsDisabled() {
        let model = ImpactBarModel(defaults: defaults)
        model.hidesWhenIdle = false
        model.consume(logLine: neutralizerLine(amount: 180))
        model.neutralizerFeatureEnabled = false
        model.consume(
            logLine: "[ 2026.11.19 12:00:00 ] (None) Undocking from Jita IV - Moon 4 - Caldari Navy Assembly Plant to Jita solar system."
        )
        assertNeutralizerIsCleared(model)
    }

    func testDockingAndUndockingRequestsDoNotResetNeutralizerValues() {
        let model = ImpactBarModel(defaults: defaults)
        model.consume(logLine: neutralizerLine(amount: 180))
        let messages = [
            "(notify) Docking operation already in progress.<br>Estimated time left: 7 seconds.",
            "(notify) You cannot do that while docking.",
            "(notify) You cannot do that while docked.",
            "(notify) Setting course to docking perimeter",
            "(notify) Docking request denied.",
            "(notify) Please wait while station services processes your undocking request.<br>Estimated 1 seconds left.",
            "(chat) Undocking from Jita IV - Moon 4 - Caldari Navy Assembly Plant to Jita solar system."
        ]
        for message in messages {
            model.consume(logLine: "[ 2026.11.19 12:00:00 ] \(message)")
            XCTAssertEqual(model.neutralizerTotalAmountGJ, 180)
        }
    }

    private func assertNeutralizerIsCleared(_ model: ImpactBarModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(model.neutralizerLastAmountGJ, file: file, line: line)
        XCTAssertNil(model.neutralizerTotalAmountGJ, file: file, line: line)
        XCTAssertNil(model.neutralizerState, file: file, line: line)
        XCTAssertNil(model.neutralizerLastEventAt, file: file, line: line)
        XCTAssertEqual(model.neutralizerCadenceEventCount, 0, file: file, line: line)
    }

    private func neutralizerLine(amount: Int) -> String {
        "[ 2026.11.19 12:00:00 ] (combat) \(amount) GJ energy neutralized Gila [Example] - Medium Energy Neutralizer II"
    }
}
