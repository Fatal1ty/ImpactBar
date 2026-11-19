import XCTest
@testable import ImpactBar

final class NeutralizerTrackerTests: XCTestCase {
    private let parser = CombatLogParser()

    func testParsesOutgoingNeutralizerAndUsesCharacterAsHiddenTargetKey() {
        let line = #"[ 2026.11.17 18:44:44 ] (combat) <color=0xff7fffff><b>180 GJ</b><color=0x77ffffff><font size=10> energy neutralized </font><b><color=0xffffffff><font size=12><color=0xFFFFFFFF><b>Gila</b></color></font> <font size=11>[Gudbay776] -</font></b><color=0x77ffffff><font size=10> - Medium Energy Neutralizer II</font>"#

        XCTAssertEqual(
            parser.parseNeutralizer(line),
            NeutralizerEvent(
                amountGJ: 180,
                targetKey: "Gudbay776",
                module: "Medium Energy Neutralizer II"
            )
        )
    }

    func testIgnoresIncomingNeutralizer() {
        let line = #"[ 2026.11.17 18:44:37 ] (combat) <color=0xffe57f7f><b>110 GJ</b><color=0x77ffffff><font size=10> energy neutralized </font><b><color=0xffffffff>Counter-Curse</b><color=0x77ffffff><font size=10> - Counter-Curse</font>"#

        XCTAssertNil(parser.parseNeutralizer(line))
    }

    func testAnyNumberOfModulesAggregatesIntoOneVolley() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 1_000)

        let first = tracker.record(event: event(amount: 180), at: start)
        let second = tracker.record(event: event(amount: 180), at: start.addingTimeInterval(0.6))
        let third = tracker.record(event: event(amount: 90), at: start.addingTimeInterval(1.2))

        XCTAssertEqual(first.lastAmountGJ, 180)
        XCTAssertEqual(second.lastAmountGJ, 360)
        XCTAssertEqual(third.lastAmountGJ, 450)
        XCTAssertEqual(third.totalAmountGJ, 450)
        XCTAssertEqual(third.cadenceIndex, 0)
        XCTAssertEqual(third.cadenceEventCount, 1)
    }

    func testCadenceWrapsAcrossThreeSegmentsAndKeepsTwoPrevious() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 2_000)
        var snapshot = tracker.record(event: event(amount: 180), at: start)

        for index in 1...3 {
            snapshot = tracker.record(
                event: event(amount: 180),
                at: start.addingTimeInterval(Double(index) * 10)
            )
        }

        XCTAssertEqual(snapshot.cadenceIndex, 0)
        XCTAssertEqual(snapshot.cadenceEventCount, 3)
    }

    func testDryPinnedRecoveredAndDrainingTransitions() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 3_000)

        XCTAssertEqual(
            tracker.record(event: event(amount: 180), at: start).state,
            .draining
        )
        XCTAssertEqual(
            tracker.record(event: event(amount: 0), at: start.addingTimeInterval(0.5)).state,
            .dry
        )
        XCTAssertEqual(
            tracker.record(event: event(amount: 4), at: start.addingTimeInterval(10)).state,
            .pinned
        )
        XCTAssertEqual(
            tracker.record(event: event(amount: 175), at: start.addingTimeInterval(20)).state,
            .recovered
        )
        XCTAssertEqual(
            tracker.record(event: event(amount: 180), at: start.addingTimeInterval(30)).state,
            .draining
        )
    }

    func testDrainAtHalfTheCeilingPinsImmediatelyWithoutAZero() {
        XCTAssertEqual(
            states(for: [180, 91, 90]),
            [.draining, .draining, .pinned]
        )
    }

    func testPartialDrainsDoNotRatchetDownTheCeiling() {
        XCTAssertEqual(
            states(for: [180, 100, 55, 30, 17]),
            [.draining, .draining, .pinned, .pinned, .pinned]
        )
    }

    func testCeilingCanFallOrRiseAndRecoveryUsesThePeak() {
        XCTAssertEqual(
            states(for: [180, 162, 82, 81, 134, 135, 67, 200, 100]),
            [.draining, .draining, .draining, .pinned, .pinned, .recovered, .pinned, .recovered, .pinned]
        )
    }

    func testSwitchingFromTwoModulesToOneUsesTheSingleDrainCeiling() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 3_500)

        _ = tracker.record(event: event(amount: 180), at: start)
        let volley = tracker.record(event: event(amount: 180), at: start)
        let dry = tracker.record(event: event(amount: 0), at: start.addingTimeInterval(12))
        let pinned = tracker.record(event: event(amount: 50), at: start.addingTimeInterval(24))
        let recovered = tracker.record(event: event(amount: 140), at: start.addingTimeInterval(36))

        XCTAssertEqual(volley.lastAmountGJ, 360)
        XCTAssertEqual(dry.state, .dry)
        XCTAssertEqual(pinned.state, .pinned)
        XCTAssertEqual(pinned.lastAmountGJ, 50)
        XCTAssertEqual(pinned.totalAmountGJ, 410)
        XCTAssertEqual(recovered.state, .recovered)
    }

    func testZeroBeforeTheFirstPositiveDrainDoesNotEstablishACeiling() {
        XCTAssertEqual(states(for: [0, 40, 20]), [.dry, .draining, .pinned])
    }

    func testChangingTargetResetsLastAndTotal() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 4_000)

        _ = tracker.record(event: event(amount: 180, target: "Alpha"), at: start)
        let snapshot = tracker.record(
            event: event(amount: 90, target: "Beta"),
            at: start.addingTimeInterval(10)
        )

        XCTAssertEqual(snapshot.lastAmountGJ, 90)
        XCTAssertEqual(snapshot.totalAmountGJ, 90)
        XCTAssertEqual(snapshot.state, .draining)
        XCTAssertEqual(snapshot.cadenceIndex, 0)
        XCTAssertEqual(snapshot.cadenceEventCount, 1)

        let next = tracker.record(event: event(amount: 68, target: "Beta"), at: start.addingTimeInterval(22))
        let pinned = tracker.record(event: event(amount: 34, target: "Beta"), at: start.addingTimeInterval(34))
        XCTAssertEqual(next.state, .draining)
        XCTAssertEqual(pinned.state, .pinned)
    }

    func testAttachedGilaSequenceEndsPinnedWithCorrectTotals() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 5_000)
        let samples: [(TimeInterval, Int)] = [
            (0, 180), (0, 180),
            (12, 180), (13, 180),
            (24, 175), (25, 0),
            (36, 4), (37, 0),
            (48, 4), (49, 0),
            (60, 4), (61, 0),
            (72, 4), (73, 0)
        ]

        var snapshot: NeutralizerSnapshot?
        for (offset, amount) in samples {
            snapshot = tracker.record(
                event: event(amount: amount, target: "Gudbay776"),
                at: start.addingTimeInterval(offset)
            )
        }

        XCTAssertEqual(snapshot?.lastAmountGJ, 4)
        XCTAssertEqual(snapshot?.totalAmountGJ, 911)
        XCTAssertEqual(snapshot?.state, .pinned)
        XCTAssertEqual(snapshot?.cadenceIndex, 0)
        XCTAssertEqual(snapshot?.cadenceEventCount, 3)
    }

    func testTenMinuteGapResetsTotalsCeilingAndCadenceForTheSameTarget() {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 6_000)
        _ = tracker.record(event: event(amount: 180), at: start)
        _ = tracker.record(event: event(amount: 0), at: start.addingTimeInterval(12))

        let snapshot = tracker.record(event: event(amount: 20), at: start.addingTimeInterval(612))
        XCTAssertEqual(snapshot.lastAmountGJ, 20)
        XCTAssertEqual(snapshot.totalAmountGJ, 20)
        XCTAssertEqual(snapshot.state, .draining)
        XCTAssertEqual(snapshot.cadenceIndex, 0)
        XCTAssertEqual(snapshot.cadenceEventCount, 1)
        XCTAssertEqual(
            tracker.record(event: event(amount: 15), at: start.addingTimeInterval(624)).state,
            .draining
        )
    }

    private func states(for amounts: [Int]) -> [NeutralizerState] {
        var tracker = NeutralizerTracker()
        let start = Date(timeIntervalSince1970: 0)
        return amounts.enumerated().map { index, amount in
            tracker.record(event: event(amount: amount), at: start.addingTimeInterval(12 * Double(index))).state
        }
    }

    private func event(amount: Int, target: String = "Target") -> NeutralizerEvent {
        NeutralizerEvent(
            amountGJ: amount,
            targetKey: target,
            module: "Medium Energy Neutralizer II"
        )
    }
}
