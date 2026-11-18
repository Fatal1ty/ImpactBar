import AppKit
import CoreGraphics
import SwiftUI

private final class ImpactOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class MovableHostingView<Content: View>: NSHostingView<Content> {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartMouseLocation,
              let dragStartWindowOrigin else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: dragStartWindowOrigin.x + currentLocation.x - dragStartMouseLocation.x,
            y: dragStartWindowOrigin.y + currentLocation.y - dragStartMouseLocation.y
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
    }
}

@MainActor
final class OverlayController {
    private static let fullscreenOverlayLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel()) + 1
    )

    let model: ImpactBarModel
    let panel: NSPanel
    let neutralizerPanel: NSPanel

    private(set) var isVisible = true

    init(model: ImpactBarModel) {
        self.model = model
        let panelSize = Self.panelSize(for: model.orientation)

        let panel = ImpactOverlayPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        Self.configure(panel: panel)
        panel.contentView = MovableHostingView(rootView: ImpactBarView(model: model))
        panel.setFrameAutosaveName("ImpactBar.OverlayFrame")

        let neutralizerPanel = ImpactOverlayPanel(
            contentRect: NSRect(
                origin: .zero,
                size: Self.neutralizerPanelSize
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        Self.configure(panel: neutralizerPanel)
        neutralizerPanel.contentView = MovableHostingView(
            rootView: NeutralizerOverlayView(model: model)
        )
        neutralizerPanel.setFrameAutosaveName("ImpactBar.NeutralizerOverlayFrame")

        self.panel = panel
        self.neutralizerPanel = neutralizerPanel
    }

    func show() {
        if !restoreSavedPosition() {
            positionNearBottomCenter()
        }
        if !restoreNeutralizerPosition() {
            positionNeutralizerNearBottomCenter()
        }
        updateOrientationLayout(saveFrame: false)
        updateNeutralizerLayout(saveFrame: false)
        isVisible = true
        bringToFront()
    }

    func updateOrientationLayout(saveFrame: Bool = true) {
        let currentCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let newSize = Self.panelSize(for: model.orientation)
        let newFrame = NSRect(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        panel.setFrame(newFrame, display: true)
        if saveFrame {
            panel.saveFrame(usingName: "ImpactBar.OverlayFrame")
        }
        bringToFront()
    }

    private func updateNeutralizerLayout(saveFrame: Bool = true) {
        let currentCenter = NSPoint(
            x: neutralizerPanel.frame.midX,
            y: neutralizerPanel.frame.midY
        )
        let newSize = Self.neutralizerPanelSize
        let newFrame = NSRect(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        neutralizerPanel.setFrame(newFrame, display: true)
        if saveFrame {
            neutralizerPanel.saveFrame(usingName: "ImpactBar.NeutralizerOverlayFrame")
        }
        bringToFront()
    }

    func bringToFront() {
        guard isVisible else { return }
        panel.level = Self.fullscreenOverlayLevel
        neutralizerPanel.level = Self.fullscreenOverlayLevel
        updateFeatureVisibility()
    }

    func updateFeatureVisibility() {
        guard isVisible else { return }

        if model.turretFeatureEnabled {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }

        if model.neutralizerFeatureEnabled {
            neutralizerPanel.orderFrontRegardless()
        } else {
            neutralizerPanel.orderOut(nil)
        }
    }

    func toggleVisibility() {
        if isVisible {
            panel.orderOut(nil)
            neutralizerPanel.orderOut(nil)
            isVisible = false
        } else {
            show()
        }
    }

    func toggleEditing() {
        model.isEditing.toggle()
        panel.ignoresMouseEvents = !model.isEditing
        neutralizerPanel.ignoresMouseEvents = !model.isEditing

        if model.isEditing {
            if model.turretFeatureEnabled {
                panel.makeKeyAndOrderFront(nil)
            }
            if model.neutralizerFeatureEnabled {
                neutralizerPanel.orderFrontRegardless()
            }
        } else {
            panel.resignKey()
            neutralizerPanel.resignKey()
            bringToFront()
            panel.saveFrame(usingName: "ImpactBar.OverlayFrame")
            neutralizerPanel.saveFrame(usingName: "ImpactBar.NeutralizerOverlayFrame")
        }
    }

    func resetTurretPosition() {
        NSWindow.removeFrame(usingName: "ImpactBar.OverlayFrame")
        positionNearBottomCenter()
        panel.saveFrame(usingName: "ImpactBar.OverlayFrame")
        bringToFront()
    }

    func resetNeutralizerPosition() {
        NSWindow.removeFrame(usingName: "ImpactBar.NeutralizerOverlayFrame")
        positionNeutralizerNearBottomCenter()
        neutralizerPanel.saveFrame(usingName: "ImpactBar.NeutralizerOverlayFrame")
        bringToFront()
    }

    func resetAllPositions() {
        resetTurretPosition()
        resetNeutralizerPosition()
    }

    private func positionNearBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.minY + 150
        )
        panel.setFrameOrigin(origin)
    }

    private func positionNeutralizerNearBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let visualCenterY = visible.minY + 210
        let origin = NSPoint(
            x: visible.midX - neutralizerPanel.frame.width / 2,
            y: visualCenterY - neutralizerPanel.frame.height / 2
        )
        neutralizerPanel.setFrameOrigin(origin)
    }

    private func restoreSavedPosition() -> Bool {
        panel.setFrameUsingName("ImpactBar.OverlayFrame")
    }

    private func restoreNeutralizerPosition() -> Bool {
        neutralizerPanel.setFrameUsingName("ImpactBar.NeutralizerOverlayFrame")
    }

    private static func configure(panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = fullscreenOverlayLevel
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = true
    }

    private static func panelSize(for orientation: OverlayOrientation) -> NSSize {
        switch orientation {
        case .horizontal: NSSize(width: 202, height: 32)
        case .vertical: NSSize(width: 32, height: 202)
        }
    }

    private static let neutralizerPanelSize = NSSize(width: 202, height: 56)
}
