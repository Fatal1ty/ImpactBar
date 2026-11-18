import SwiftUI

struct ImpactBarView: View {
    @ObservedObject var model: ImpactBarModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var displayedProgress = 0.0
    @State private var hasDisplayedResult = false
    @State private var eventPulseOpacity = 1.0
    @State private var eventPulseGeneration = 0
    @State private var eventPulseWorkItem: DispatchWorkItem?
    @State private var wreckBorderOpacity = 0.0
    @State private var wreckBorderWidth = 1.0
    @State private var wreckPulseGeneration = 0
    @State private var barOpacity = 0.0
    @State private var visibilityGeneration = 0
    @State private var visibilityWorkItem: DispatchWorkItem?

    private var isVertical: Bool {
        model.orientation == .vertical
    }

    private var barSize: CGSize {
        isVertical
            ? CGSize(width: 8, height: 180)
            : CGSize(width: 180, height: 8)
    }

    private var containerSize: CGSize {
        isVertical
            ? CGSize(width: 32, height: 202)
            : CGSize(width: 202, height: 32)
    }

    var body: some View {
        ZStack {
            qualityBar
                .opacity(barOpacity * eventPulseOpacity)

            if model.isEditing {
                Rectangle()
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: barSize.width + 10, height: barSize.height + 10)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .onAppear {
            displayedProgress = model.rollingScore ?? 0
            hasDisplayedResult = model.rollingScore != nil
            scheduleVisibilityChange(revealCurrentEvent: true)
        }
        .onChange(of: model.eventID) { _ in
            replayAnimation(
                shouldPulse: model.quality != nil && model.quality != .wrecks
            )
            scheduleVisibilityChange(revealCurrentEvent: true)
        }
        .onChange(of: model.wreckEventID) { _ in
            replayWreckAnimation()
        }
        .onChange(of: model.hidesWhenIdle) { _ in
            scheduleVisibilityChange()
        }
        .onChange(of: model.isEditing) { _ in
            scheduleVisibilityChange()
        }
        .onDisappear {
            eventPulseWorkItem?.cancel()
            visibilityWorkItem?.cancel()
            wreckPulseGeneration &+= 1
        }
    }

    private var qualityBar: some View {
        ZStack(alignment: isVertical ? .bottom : .leading) {
            Rectangle()
                .fill(
                    Color(red: 0.018, green: 0.035, blue: 0.043)
                        .opacity(reduceTransparency ? 1 : 0.92)
                )

            GeometryReader { geometry in
                ZStack(alignment: isVertical ? .bottom : .leading) {
                    Color.clear
                    Rectangle()
                        .fill(color(for: displayedProgress))
                        .frame(
                            width: isVertical
                                ? geometry.size.width
                                : fillLength(for: geometry.size.width),
                            height: isVertical
                                ? fillLength(for: geometry.size.height)
                                : geometry.size.height
                        )
                }
                .clipShape(Rectangle())
            }

            Rectangle()
                .stroke(
                    Color(red: 0.31, green: 0.42, blue: 0.45)
                        .opacity(colorSchemeContrast == .increased ? 1 : 0.72),
                    lineWidth: 1
                )

            Rectangle()
                .stroke(
                    HitQuality.wrecks.paletteColor.swiftUIColor.opacity(wreckBorderOpacity),
                    lineWidth: wreckBorderWidth
                )
                .shadow(
                    color: model.showsShadow
                        ? HitQuality.wrecks.paletteColor.swiftUIColor.opacity(wreckBorderOpacity * 0.72)
                        : .clear,
                    radius: model.showsShadow ? 4 : 0
                )
        }
        .frame(width: barSize.width, height: barSize.height)
        .shadow(
            color: model.showsShadow && displayedProgress > 0
                ? color(for: displayedProgress).opacity(0.28)
                : .clear,
            radius: model.showsShadow ? 2 : 0
        )
        .shadow(
            color: model.showsShadow ? .black.opacity(0.85) : .clear,
            radius: model.showsShadow ? 2 : 0,
            y: model.showsShadow ? 1 : 0
        )
    }

    private func replayAnimation(shouldPulse: Bool) {
        let target = model.rollingScore ?? 0
        eventPulseWorkItem?.cancel()
        eventPulseGeneration &+= 1
        let generation = eventPulseGeneration

        withAnimation(.easeInOut(duration: 0.22)) {
            displayedProgress = target
            hasDisplayedResult = model.rollingScore != nil
        }

        guard !reduceMotion else {
            eventPulseOpacity = 1
            return
        }

        guard shouldPulse else {
            withAnimation(.easeOut(duration: 0.08)) {
                eventPulseOpacity = 1
            }
            return
        }

        withAnimation(.easeOut(duration: 0.08)) {
            eventPulseOpacity = 0.75
        }

        let workItem = DispatchWorkItem {
            guard generation == eventPulseGeneration else { return }
            withAnimation(.easeInOut(duration: 0.14)) {
                eventPulseOpacity = 1
            }
        }
        eventPulseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func replayWreckAnimation() {
        guard !reduceMotion else {
            wreckBorderOpacity = 0
            wreckBorderWidth = 1
            return
        }

        wreckPulseGeneration &+= 1
        let generation = wreckPulseGeneration

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            wreckBorderOpacity = 0
            wreckBorderWidth = 1
        }

        withAnimation(.easeOut(duration: 0.06)) {
            wreckBorderOpacity = 1
            wreckBorderWidth = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            guard generation == wreckPulseGeneration else { return }
            withAnimation(.easeIn(duration: 0.05)) {
                wreckBorderOpacity = 0.05
                wreckBorderWidth = 1.2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard generation == wreckPulseGeneration else { return }
            withAnimation(.easeOut(duration: 0.06)) {
                wreckBorderOpacity = 1
                wreckBorderWidth = 2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            guard generation == wreckPulseGeneration else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                wreckBorderOpacity = 0
                wreckBorderWidth = 1
            }
        }
    }

    private func scheduleVisibilityChange(revealCurrentEvent: Bool = false) {
        visibilityWorkItem?.cancel()
        visibilityGeneration &+= 1
        let generation = visibilityGeneration

        if model.isEditing {
            withAnimation(.easeOut(duration: 0.15)) {
                barOpacity = 1
            }
            return
        }

        guard let lastEventAt = model.lastEventAt else {
            withAnimation(.easeOut(duration: 0.25)) {
                barOpacity = model.hidesWhenIdle ? 0 : 0.28
            }
            return
        }

        if revealCurrentEvent {
            barOpacity = 1
        }
        let idleTime = Date().timeIntervalSince(lastEventAt)
        let delay = max(0, 5 - idleTime)
        let targetOpacity = model.hidesWhenIdle ? 0.0 : 0.38
        let fadeDuration = model.hidesWhenIdle ? 2.0 : 0.35

        let workItem = DispatchWorkItem {
            guard generation == visibilityGeneration else { return }
            withAnimation(.linear(duration: fadeDuration)) {
                barOpacity = targetOpacity
            }
        }
        visibilityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func color(for score: Double) -> Color {
        HitQualityPaletteColor.interpolated(for: score).swiftUIColor
    }

    private func fillLength(for availableLength: CGFloat) -> CGFloat {
        guard hasDisplayedResult else { return 0 }
        return min(availableLength, max(6, availableLength * displayedProgress))
    }
}
