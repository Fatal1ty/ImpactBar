import AppKit
import Foundation

final class SoundSettings {
    private enum Key {
        static let soundsEnabled = "ImpactBar.Sounds.Enabled"
        static let neutralizerSoundsEnabled = "ImpactBar.Sounds.Neutralizers.Enabled"
        static let drySoundEnabled = "ImpactBar.Sounds.Neutralizers.Dry"
        static let recoveredSoundEnabled = "ImpactBar.Sounds.Neutralizers.Recovered"
    }

    var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Key.soundsEnabled) }
    }
    var neutralizerSoundsEnabled: Bool {
        didSet { defaults.set(neutralizerSoundsEnabled, forKey: Key.neutralizerSoundsEnabled) }
    }
    var drySoundEnabled: Bool {
        didSet { defaults.set(drySoundEnabled, forKey: Key.drySoundEnabled) }
    }
    var recoveredSoundEnabled: Bool {
        didSet { defaults.set(recoveredSoundEnabled, forKey: Key.recoveredSoundEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundsEnabled = defaults.object(forKey: Key.soundsEnabled) as? Bool ?? true
        neutralizerSoundsEnabled = defaults.object(forKey: Key.neutralizerSoundsEnabled) as? Bool ?? true
        drySoundEnabled = defaults.object(forKey: Key.drySoundEnabled) as? Bool ?? true
        recoveredSoundEnabled = defaults.object(forKey: Key.recoveredSoundEnabled) as? Bool ?? true
    }
}

final class NeutralizerSoundPlayer {
    private let settings: SoundSettings
    private var activeSound: NSSound?

    init(settings: SoundSettings) {
        self.settings = settings
    }

    func playDry(force: Bool = false) {
        guard force || shouldPlay(settings.drySoundEnabled) else { return }
        playSystemSound(named: "Glass")
    }

    func playRecovered(force: Bool = false) {
        guard force || shouldPlay(settings.recoveredSoundEnabled) else { return }
        playSystemSound(named: "Submarine")
    }

    private func shouldPlay(_ eventEnabled: Bool) -> Bool {
        settings.soundsEnabled
            && settings.neutralizerSoundsEnabled
            && eventEnabled
    }

    private func playSystemSound(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }

        activeSound?.stop()
        activeSound = sound
        sound.volume = 0.72
        sound.play()
    }
}
