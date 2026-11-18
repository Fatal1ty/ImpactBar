import AppKit
import XCTest
@testable import ImpactBar

final class NeutralizerSoundTests: XCTestCase {
    func testDryUsesAvailableGlassSystemSound() {
        XCTAssertNotNil(NSSound(named: NSSound.Name("Glass")))
    }

    func testRecoveredUsesAvailableSubmarineSystemSound() {
        XCTAssertNotNil(NSSound(named: NSSound.Name("Submarine")))
    }
}
