import XCTest
@testable import ImpactBar

final class CombatLogParserTests: XCTestCase {
    private let parser = CombatLogParser()
    private let classifier = TurretClassifier()

    func testParsesOutgoingTurretHitWithMarkup() {
        let line = #"[ 2026.10.28 14:26:31 ] (combat) <color=0xff00ffff><b>91</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Example Target</b><font size=10><color=0x77ffffff> - Dual Light Pulse Laser II - Penetrates"#

        XCTAssertEqual(
            parser.parse(line),
            TurretHitEvent(
                quality: .penetrates,
                weapon: "Dual Light Pulse Laser II",
                target: "Example Target"
            )
        )
    }

    func testParsesGroupedTurretMiss() {
        let line = #"[ 2026.10.12 12:27:41 ] (combat) Your group of Dual Light Pulse Laser II misses Example Target completely - Dual Light Pulse Laser II"#

        XCTAssertEqual(
            parser.parse(line),
            TurretHitEvent(
                quality: .miss,
                weapon: "Dual Light Pulse Laser II",
                target: "Example Target"
            )
        )
    }

    func testParsesUngroupedTurretMiss() {
        let line = #"[ 2026.10.28 14:33:23 ] (combat) Your Heavy Ion Blaster II misses Example Target completely - Heavy Ion Blaster II"#

        XCTAssertEqual(parser.parse(line)?.quality, .miss)
        XCTAssertEqual(parser.parse(line)?.weapon, "Heavy Ion Blaster II")
    }

    func testIgnoresIncomingDamage() {
        let line = #"[ 2026.10.28 14:26:28 ] (combat) 51 from Example Target - Heavy Ion Blaster II - Hits"#
        XCTAssertNil(parser.parse(line))
    }

    func testClassifierRejectsDronesAndMissiles() {
        XCTAssertFalse(classifier.isTurret("Hobgoblin II"))
        XCTAssertFalse(classifier.isTurret("Nova Fury Light Missile"))
    }

    func testClassifierAcceptsTurretFamilies() {
        XCTAssertTrue(classifier.isTurret("Dual Light Pulse Laser II"))
        XCTAssertTrue(classifier.isTurret("Heavy Ion Blaster II"))
        XCTAssertTrue(classifier.isTurret("250mm Railgun II"))
        XCTAssertTrue(classifier.isTurret("800mm Repeating Cannon II Autocannon"))
        XCTAssertTrue(classifier.isTurret("Heavy Entropic Disintegrator II"))
    }

    func testUsesFixedNormalizedQualityValues() {
        XCTAssertEqual(HitQuality.miss.rollingValue, 0.000)
        XCTAssertEqual(HitQuality.grazes.rollingValue, 0.411)
        XCTAssertEqual(HitQuality.glancesOff.rollingValue, 0.502)
        XCTAssertEqual(HitQuality.hits.rollingValue, 0.639)
        XCTAssertEqual(HitQuality.penetrates.rollingValue, 0.821)
        XCTAssertEqual(HitQuality.smashes.rollingValue, 1.000)
        XCTAssertNil(HitQuality.wrecks.rollingValue)
    }

    func testRollingWindowKeepsOnlyLastTenResults() {
        var tracker = TurretQualityTracker()
        let start = Date(timeIntervalSince1970: 1_000)

        tracker.record(target: "Target", quality: .miss, at: start)
        for index in 1...10 {
            tracker.record(
                target: "Target",
                quality: .smashes,
                at: start.addingTimeInterval(Double(index))
            )
        }

        XCTAssertEqual(tracker.samples.count, 10)
        XCTAssertEqual(tracker.rollingScore, 1.0)
    }

    func testTargetChangeClearsWindowWithoutCachingOldTarget() {
        var tracker = TurretQualityTracker()
        let start = Date(timeIntervalSince1970: 2_000)

        tracker.record(target: "Alpha", quality: .smashes, at: start)
        tracker.record(target: "Beta", quality: .miss, at: start.addingTimeInterval(1))
        XCTAssertEqual(tracker.rollingScore, 0.0)

        tracker.record(target: "Alpha", quality: .hits, at: start.addingTimeInterval(2))
        XCTAssertEqual(tracker.samples, [0.639])
        XCTAssertEqual(tracker.rollingScore, 0.639)
    }

    func testInactivityTimeoutClearsWindowBeforeNextResult() {
        var tracker = TurretQualityTracker()
        let start = Date(timeIntervalSince1970: 3_000)

        tracker.record(target: "Target", quality: .smashes, at: start)
        tracker.record(
            target: "Target",
            quality: .miss,
            at: start.addingTimeInterval(TurretQualityTracker.inactivityTimeout)
        )

        XCTAssertEqual(tracker.samples, [0.0])
        XCTAssertEqual(tracker.rollingScore, 0.0)
    }

    func testWreckDoesNotEnterAverageButStillUpdatesActivity() {
        var tracker = TurretQualityTracker()
        let start = Date(timeIntervalSince1970: 4_000)

        tracker.record(target: "Target", quality: .hits, at: start)
        tracker.record(target: "Target", quality: .wrecks, at: start.addingTimeInterval(1))

        XCTAssertEqual(tracker.samples, [0.639])
        XCTAssertEqual(tracker.rollingScore, 0.639)
        XCTAssertEqual(tracker.lastEventAt, start.addingTimeInterval(1))
    }

    func testWreckOnNewTargetLeavesAverageEmpty() {
        var tracker = TurretQualityTracker()
        let start = Date(timeIntervalSince1970: 5_000)

        tracker.record(target: "Alpha", quality: .smashes, at: start)
        tracker.record(target: "Beta", quality: .wrecks, at: start.addingTimeInterval(1))

        XCTAssertTrue(tracker.samples.isEmpty)
        XCTAssertNil(tracker.rollingScore)
    }

    func testDetectsTargetGoneNotificationButIgnoresDroneNotification() {
        let targetGone = #"[ 2026.10.28 14:36:19 ] (notify) You cannot activate that module as the target is no longer present."#
        let droneGone = #"[ 2026.10.28 14:37:13 ] (notify) Combat Drone cannot be commanded to work on a target that is no longer present."#

        XCTAssertTrue(parser.indicatesTargetGone(targetGone))
        XCTAssertFalse(parser.indicatesTargetGone(droneGone))
    }

    func testReadsCharacterNameFromLogHeader() {
        let header = """
        ------------------------------------------------------------
          Gamelog
          Listener: Example Capsuleer
          Session Started: 2026.10.28 14:11:59
        ------------------------------------------------------------
        """

        XCTAssertEqual(
            GameLogWatcher.listenerName(inHeader: header),
            "Example Capsuleer"
        )
    }

    func testDiscoversNewestLogForEveryCharacter() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let oldAlpha = directory.appendingPathComponent("alpha-old.txt")
        let newAlpha = directory.appendingPathComponent("alpha-new.txt")
        let beta = directory.appendingPathComponent("beta.txt")

        try logHeader(for: "Alpha Pilot").write(to: oldAlpha, atomically: true, encoding: .utf8)
        try logHeader(for: "Alpha Pilot").write(to: newAlpha, atomically: true, encoding: .utf8)
        try logHeader(for: "Beta Pilot").write(to: beta, atomically: true, encoding: .utf8)

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-30)],
            ofItemAtPath: oldAlpha.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: newAlpha.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-10)],
            ofItemAtPath: beta.path
        )

        let sources = GameLogWatcher(directoryURL: directory).discoverSources()

        XCTAssertEqual(sources.map(\.character), ["Alpha Pilot", "Beta Pilot"])
        XCTAssertEqual(sources.first?.fileURL.lastPathComponent, newAlpha.lastPathComponent)
    }

    private func logHeader(for character: String) -> String {
        """
        ------------------------------------------------------------
          Gamelog
          Listener: \(character)
          Session Started: 2026.10.28 14:11:59
        ------------------------------------------------------------
        """
    }
}
