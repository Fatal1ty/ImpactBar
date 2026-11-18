import AppKit
import Combine

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let selectedCharacterKey = "ImpactBar.SelectedCharacter"
    private static let repositoryURL = URL(string: "https://github.com/Fatal1ty/ImpactBar")!

    private var statusItem: NSStatusItem!
    private var charactersRootItem: NSMenuItem!
    private var charactersMenu: NSMenu!
    private var editingMenuItem: NSMenuItem!
    private var visibilityMenuItem: NSMenuItem!
    private var turretFeatureEnabledMenuItem: NSMenuItem!
    private var neutralizerFeatureEnabledMenuItem: NSMenuItem!
    private var shadowMenuItem: NSMenuItem!
    private var idleVisibilityMenuItem: NSMenuItem!
    private var horizontalOrientationMenuItem: NSMenuItem!
    private var verticalOrientationMenuItem: NSMenuItem!
    private var soundsEnabledMenuItem: NSMenuItem!
    private var neutralizerSoundsRootItem: NSMenuItem!
    private var neutralizerSoundsEnabledMenuItem: NSMenuItem!
    private var drySoundEnabledMenuItem: NSMenuItem!
    private var recoveredSoundEnabledMenuItem: NSMenuItem!
    private var turretTestingMenuItem: NSMenuItem!
    private var neutralizerTestingMenuItem: NSMenuItem!
    private var selectedCharacter: String?
    private var selectedLogFileURL: URL?
    private var overlayController: OverlayController!
    private var logWatcher: GameLogWatcher!
    private let soundSettings = SoundSettings()
    private lazy var neutralizerSoundPlayer = NeutralizerSoundPlayer(settings: soundSettings)
    private var cancellables = Set<AnyCancellable>()

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = ImpactBarModel()
        overlayController = OverlayController(model: model)
        overlayController.show()
        configureOverlayObservers()

        configureStatusItem()
        configureSoundPlayback(model: model)

        logWatcher = GameLogWatcher()
        logWatcher.start(
            preferredCharacter: UserDefaults.standard.string(forKey: Self.selectedCharacterKey),
            onLine: { [weak model] line in
                DispatchQueue.main.async {
                    model?.consume(logLine: line)
                }
            },
            onSourcesChanged: { [weak self] sources, selectedCharacter in
                DispatchQueue.main.async {
                    self?.updateCharactersMenu(
                        sources: sources,
                        selectedCharacter: selectedCharacter
                    )
                }
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        logWatcher?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func configureOverlayObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(refreshOverlay),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(refreshOverlay),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshOverlay),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = menuSymbol("scope", description: "ImpactBar")

        let menu = NSMenu()

        charactersRootItem = NSMenuItem(title: "Character: searching…", action: nil, keyEquivalent: "")
        charactersMenu = NSMenu(title: "Character")
        charactersRootItem.submenu = charactersMenu
        menu.addItem(charactersRootItem)
        menu.addItem(.separator())

        editingMenuItem = addItem(
            to: menu,
            title: "Move Overlays",
            symbol: "arrow.up.and.down.and.arrow.left.and.right",
            action: #selector(toggleEditing)
        )
        visibilityMenuItem = addItem(
            to: menu,
            title: "Hide Overlays",
            symbol: "eye.slash",
            action: #selector(toggleVisibility)
        )
        menu.addItem(.separator())

        let turretRootItem = NSMenuItem(title: "Turret Hit Quality", action: nil, keyEquivalent: "")
        turretRootItem.image = menuSymbol("scope", description: "Turret hit quality")
        turretRootItem.submenu = makeTurretFeatureMenu()
        menu.addItem(turretRootItem)

        let neutralizerRootItem = NSMenuItem(title: "Energy Neutralizers", action: nil, keyEquivalent: "")
        neutralizerRootItem.image = menuSymbol("bolt.fill", description: "Energy neutralizers")
        neutralizerRootItem.submenu = makeNeutralizerFeatureMenu()
        menu.addItem(neutralizerRootItem)
        menu.addItem(.separator())

        let appearanceRootItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceRootItem.image = menuSymbol("circle.lefthalf.filled", description: "Appearance")
        appearanceRootItem.submenu = makeAppearanceMenu()
        menu.addItem(appearanceRootItem)

        let soundsRootItem = NSMenuItem(title: "Sounds", action: nil, keyEquivalent: "")
        soundsRootItem.image = menuSymbol("speaker.wave.2", description: "Sounds")
        soundsRootItem.submenu = makeSoundsMenu()
        menu.addItem(soundsRootItem)

        let testingRootItem = NSMenuItem(title: "Testing", action: nil, keyEquivalent: "")
        testingRootItem.image = menuSymbol("play.rectangle", description: "Testing")
        testingRootItem.submenu = makeTestingMenu()
        menu.addItem(testingRootItem)
        menu.addItem(.separator())

        addItem(
            to: menu,
            title: "Open Logs Folder",
            symbol: "folder",
            action: #selector(openLogsDirectory)
        )
        addItem(
            to: menu,
            title: "Reset All Overlay Positions…",
            symbol: "arrow.counterclockwise",
            action: #selector(confirmResetAllPositions)
        )
        addItem(
            to: menu,
            title: "About ImpactBar",
            symbol: "info.circle",
            action: #selector(showAboutPanel)
        )
        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: "Quit ImpactBar",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        statusItem.menu = menu
        updateAllMenuStates()
    }

    private func makeTurretFeatureMenu() -> NSMenu {
        let menu = NSMenu(title: "Turret Hit Quality")

        turretFeatureEnabledMenuItem = menu.addItem(
            withTitle: "Enabled",
            action: #selector(toggleTurretFeature),
            keyEquivalent: ""
        )
        turretFeatureEnabledMenuItem.target = self
        menu.addItem(.separator())

        horizontalOrientationMenuItem = NSMenuItem(
            title: "Horizontal",
            action: #selector(selectOrientation(_:)),
            keyEquivalent: ""
        )
        horizontalOrientationMenuItem.target = self
        horizontalOrientationMenuItem.representedObject = OverlayOrientation.horizontal.rawValue
        menu.addItem(horizontalOrientationMenuItem)

        verticalOrientationMenuItem = NSMenuItem(
            title: "Vertical",
            action: #selector(selectOrientation(_:)),
            keyEquivalent: ""
        )
        verticalOrientationMenuItem.target = self
        verticalOrientationMenuItem.representedObject = OverlayOrientation.vertical.rawValue
        menu.addItem(verticalOrientationMenuItem)

        let legendRootItem = NSMenuItem(title: "Hit Quality Legend", action: nil, keyEquivalent: "")
        legendRootItem.submenu = makeHitQualityLegendMenu()
        menu.addItem(legendRootItem)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Reset Position",
            action: #selector(resetTurretPosition),
            keyEquivalent: ""
        ).target = self

        return menu
    }

    private func makeNeutralizerFeatureMenu() -> NSMenu {
        let menu = NSMenu(title: "Energy Neutralizers")

        neutralizerFeatureEnabledMenuItem = menu.addItem(
            withTitle: "Enabled",
            action: #selector(toggleNeutralizerFeature),
            keyEquivalent: ""
        )
        neutralizerFeatureEnabledMenuItem.target = self
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Reset Position",
            action: #selector(resetNeutralizerPosition),
            keyEquivalent: ""
        ).target = self

        return menu
    }

    private func makeAppearanceMenu() -> NSMenu {
        let menu = NSMenu(title: "Appearance")

        shadowMenuItem = menu.addItem(
            withTitle: "Show Shadow",
            action: #selector(toggleShadow),
            keyEquivalent: ""
        )
        shadowMenuItem.target = self

        idleVisibilityMenuItem = menu.addItem(
            withTitle: "Hide When Idle",
            action: #selector(toggleIdleVisibility),
            keyEquivalent: ""
        )
        idleVisibilityMenuItem.target = self

        return menu
    }

    private func makeSoundsMenu() -> NSMenu {
        let menu = NSMenu(title: "Sounds")

        soundsEnabledMenuItem = menu.addItem(
            withTitle: "Enable Sounds",
            action: #selector(toggleSounds),
            keyEquivalent: ""
        )
        soundsEnabledMenuItem.target = self

        neutralizerSoundsRootItem = NSMenuItem(title: "Neutralizers", action: nil, keyEquivalent: "")
        neutralizerSoundsRootItem.submenu = makeNeutralizerSoundsMenu()
        menu.addItem(neutralizerSoundsRootItem)

        return menu
    }

    private func makeTestingMenu() -> NSMenu {
        let menu = NSMenu(title: "Testing")

        turretTestingMenuItem = menu.addItem(
            withTitle: "Turret Overlay",
            action: #selector(previewPulse),
            keyEquivalent: ""
        )
        turretTestingMenuItem.target = self

        neutralizerTestingMenuItem = menu.addItem(
            withTitle: "Neutralizer Overlay",
            action: #selector(previewNeutralizerOverlay),
            keyEquivalent: ""
        )
        neutralizerTestingMenuItem.target = self

        return menu
    }

    private func makeNeutralizerSoundsMenu() -> NSMenu {
        let menu = NSMenu(title: "Neutralizers")

        neutralizerSoundsEnabledMenuItem = menu.addItem(
            withTitle: "Enable Neutralizer Sounds",
            action: #selector(toggleNeutralizerSounds),
            keyEquivalent: ""
        )
        neutralizerSoundsEnabledMenuItem.target = self
        menu.addItem(.separator())

        drySoundEnabledMenuItem = menu.addItem(
            withTitle: "Target Dry",
            action: #selector(toggleDrySound),
            keyEquivalent: ""
        )
        drySoundEnabledMenuItem.target = self

        recoveredSoundEnabledMenuItem = menu.addItem(
            withTitle: "Target Recovered",
            action: #selector(toggleRecoveredSound),
            keyEquivalent: ""
        )
        recoveredSoundEnabledMenuItem.target = self
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Test Dry Sound",
            action: #selector(testDrySound),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Test Recovered Sound",
            action: #selector(testRecoveredSound),
            keyEquivalent: ""
        ).target = self

        return menu
    }

    private func makeHitQualityLegendMenu() -> NSMenu {
        let menu = NSMenu(title: "Hit Quality Legend")
        menu.autoenablesItems = false

        for quality in HitQuality.allCases {
            let item = NSMenuItem(title: quality.legendTitle, action: nil, keyEquivalent: "")
            item.image = makeColorSwatch(quality.paletteColor.appKitColor)
            item.isEnabled = true
            menu.addItem(item)
        }

        return menu
    }

    @discardableResult
    private func addItem(
        to menu: NSMenu,
        title: String,
        symbol: String,
        action: Selector
    ) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = menuSymbol(symbol, description: title)
        return item
    }

    private func menuSymbol(_ name: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    private func makeColorSwatch(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 20, height: 9)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()

            NSColor.white.withAlphaComponent(0.35).setStroke()
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func updateCharactersMenu(
        sources: [CharacterLogSource],
        selectedCharacter: String?
    ) {
        let selectedLogFileURL = sources.first {
            $0.character == selectedCharacter
        }?.fileURL

        if self.selectedCharacter != selectedCharacter
            || self.selectedLogFileURL != selectedLogFileURL {
            self.selectedCharacter = selectedCharacter
            self.selectedLogFileURL = selectedLogFileURL
            overlayController.model.reset()
        }

        charactersMenu.removeAllItems()

        guard !sources.isEmpty else {
            charactersRootItem.title = "Character: logs not found"
            let emptyItem = NSMenuItem(
                title: "No logs found in the last 24 hours",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            charactersMenu.addItem(emptyItem)
            return
        }

        charactersRootItem.title = selectedCharacter.map { "Character: \($0)" } ?? "Character"

        for source in sources {
            let item = NSMenuItem(
                title: source.character,
                action: #selector(selectCharacter(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = source.character
            item.state = source.character == selectedCharacter ? .on : .off
            charactersMenu.addItem(item)
        }

        if let selectedCharacter {
            UserDefaults.standard.set(selectedCharacter, forKey: Self.selectedCharacterKey)
        }
    }

    private func updateAllMenuStates() {
        updateFeatureMenuState()
        updateOrientationMenuState()
        updateAppearanceMenuState()
        updateSoundMenuState()
        updateOverlayActionState()
    }

    private func updateFeatureMenuState() {
        let model = overlayController.model
        turretFeatureEnabledMenuItem?.state = model.turretFeatureEnabled ? .on : .off
        neutralizerFeatureEnabledMenuItem?.state = model.neutralizerFeatureEnabled ? .on : .off
        horizontalOrientationMenuItem?.isEnabled = model.turretFeatureEnabled
        verticalOrientationMenuItem?.isEnabled = model.turretFeatureEnabled
        turretTestingMenuItem?.isEnabled = model.turretFeatureEnabled
        neutralizerTestingMenuItem?.isEnabled = model.neutralizerFeatureEnabled
    }

    private func updateOrientationMenuState() {
        let orientation = overlayController.model.orientation
        horizontalOrientationMenuItem?.state = orientation == .horizontal ? .on : .off
        verticalOrientationMenuItem?.state = orientation == .vertical ? .on : .off
    }

    private func updateAppearanceMenuState() {
        shadowMenuItem?.state = overlayController.model.showsShadow ? .on : .off
        idleVisibilityMenuItem?.state = overlayController.model.hidesWhenIdle ? .on : .off
    }

    private func updateSoundMenuState() {
        soundsEnabledMenuItem?.state = soundSettings.soundsEnabled ? .on : .off
        neutralizerSoundsEnabledMenuItem?.state = soundSettings.neutralizerSoundsEnabled ? .on : .off
        drySoundEnabledMenuItem?.state = soundSettings.drySoundEnabled ? .on : .off
        recoveredSoundEnabledMenuItem?.state = soundSettings.recoveredSoundEnabled ? .on : .off

        let neutralizersEnabled = overlayController.model.neutralizerFeatureEnabled
        let soundsEnabled = soundSettings.soundsEnabled
        neutralizerSoundsRootItem?.isEnabled = neutralizersEnabled
        neutralizerSoundsEnabledMenuItem?.isEnabled = soundsEnabled && neutralizersEnabled
        drySoundEnabledMenuItem?.isEnabled = soundsEnabled
            && neutralizersEnabled
            && soundSettings.neutralizerSoundsEnabled
        recoveredSoundEnabledMenuItem?.isEnabled = soundsEnabled
            && neutralizersEnabled
            && soundSettings.neutralizerSoundsEnabled
    }

    private func updateOverlayActionState() {
        let hasEnabledFeature = overlayController.model.turretFeatureEnabled
            || overlayController.model.neutralizerFeatureEnabled
        editingMenuItem?.isEnabled = hasEnabledFeature
        editingMenuItem?.title = overlayController.model.isEditing
            ? "Finish Moving Overlays"
            : "Move Overlays"
        visibilityMenuItem?.title = overlayController.isVisible
            ? "Hide Overlays"
            : "Show Overlays"
        visibilityMenuItem?.image = menuSymbol(
            overlayController.isVisible ? "eye.slash" : "eye",
            description: visibilityMenuItem?.title ?? "Overlay visibility"
        )
    }

    private func configureSoundPlayback(model: ImpactBarModel) {
        model.$neutralizerState
            .removeDuplicates()
            .compactMap { $0 }
            .sink { [weak self, weak model] state in
                guard model?.neutralizerFeatureEnabled == true else { return }
                switch state {
                case .dry:
                    self?.neutralizerSoundPlayer.playDry()
                case .recovered:
                    self?.neutralizerSoundPlayer.playRecovered()
                case .draining, .pinned:
                    break
                }
            }
            .store(in: &cancellables)
    }

    @objc private func previewPulse() {
        overlayController.model.previewNextQuality()
    }

    @objc private func previewNeutralizerOverlay() {
        overlayController.model.previewNextNeutralizerState()
    }

    @objc private func refreshOverlay() {
        overlayController.bringToFront()
    }

    @objc private func selectCharacter(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? String else { return }
        logWatcher.selectCharacter(character)
    }

    @objc private func toggleEditing() {
        overlayController.toggleEditing()
        updateOverlayActionState()
    }

    @objc private func toggleVisibility() {
        overlayController.toggleVisibility()
        updateOverlayActionState()
    }

    @objc private func toggleTurretFeature() {
        overlayController.model.turretFeatureEnabled.toggle()
        finishEditingIfAllFeaturesAreDisabled()
        overlayController.updateFeatureVisibility()
        updateAllMenuStates()
    }

    @objc private func toggleNeutralizerFeature() {
        overlayController.model.neutralizerFeatureEnabled.toggle()
        finishEditingIfAllFeaturesAreDisabled()
        overlayController.updateFeatureVisibility()
        updateAllMenuStates()
    }

    private func finishEditingIfAllFeaturesAreDisabled() {
        let model = overlayController.model
        guard model.isEditing,
              !model.turretFeatureEnabled,
              !model.neutralizerFeatureEnabled else {
            return
        }
        overlayController.toggleEditing()
    }

    @objc private func toggleShadow() {
        overlayController.model.showsShadow.toggle()
        updateAppearanceMenuState()
    }

    @objc private func toggleIdleVisibility() {
        overlayController.model.hidesWhenIdle.toggle()
        updateAppearanceMenuState()
    }

    @objc private func toggleSounds() {
        soundSettings.soundsEnabled.toggle()
        updateSoundMenuState()
    }

    @objc private func toggleNeutralizerSounds() {
        soundSettings.neutralizerSoundsEnabled.toggle()
        updateSoundMenuState()
    }

    @objc private func toggleDrySound() {
        soundSettings.drySoundEnabled.toggle()
        updateSoundMenuState()
    }

    @objc private func toggleRecoveredSound() {
        soundSettings.recoveredSoundEnabled.toggle()
        updateSoundMenuState()
    }

    @objc private func testDrySound() {
        neutralizerSoundPlayer.playDry(force: true)
    }

    @objc private func testRecoveredSound() {
        neutralizerSoundPlayer.playRecovered(force: true)
    }

    @objc private func selectOrientation(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let orientation = OverlayOrientation(rawValue: rawValue),
              orientation != overlayController.model.orientation else {
            return
        }

        overlayController.model.orientation = orientation
        overlayController.updateOrientationLayout()
        updateOrientationMenuState()
    }

    @objc private func resetTurretPosition() {
        overlayController.resetTurretPosition()
    }

    @objc private func resetNeutralizerPosition() {
        overlayController.resetNeutralizerPosition()
    }

    @objc private func confirmResetAllPositions() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset Overlay Positions?"
        alert.informativeText = "Both overlays will return to their default positions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reset Positions")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            overlayController.resetAllPositions()
        }
    }

    @objc private func openLogsDirectory() {
        NSWorkspace.shared.open(logWatcher.directoryURL)
    }

    @objc private func showAboutPanel() {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let credits = NSMutableAttributedString(
            string: "A native macOS combat-log overlay for EVE Online.\n\nGitHub"
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        credits.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: credits.length)
        )
        let githubRange = (credits.string as NSString).range(of: "GitHub")
        credits.addAttribute(.link, value: Self.repositoryURL, range: githubRange)
        credits.addAttribute(.foregroundColor, value: NSColor.linkColor, range: githubRange)

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "ImpactBar",
            .applicationVersion: version,
            .version: "Build \(build)",
            .credits: credits
        ])
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
