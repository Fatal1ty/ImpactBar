import SwiftUI

struct NeutralizerOverlayView: View {
    @ObservedObject var model: ImpactBarModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var overlayOpacity = 0.0
    @State private var cadenceOpacity = 0.0
    @State private var visibilityGeneration = 0
    @State private var visibilityWorkItem: DispatchWorkItem?

    private let panelWidth: CGFloat = 202
    private let cardWidth: CGFloat = 180
    private let panelHeight: CGFloat = 56
    private let cardHeight: CGFloat = 32
    private let cadenceWidth: CGFloat = 160

    var body: some View {
        ZStack {
            inlineOverlay
                .opacity(overlayOpacity)

            if model.isEditing {
                Rectangle()
                    .stroke(
                        Color.white.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .frame(width: cardWidth + 10, height: cardHeight + 10)
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            scheduleVisibilityChange(revealCurrentEvent: model.neutralizerState != nil)
        }
        .onChange(of: model.neutralizerEventID) { _ in
            scheduleVisibilityChange(revealCurrentEvent: model.neutralizerState != nil)
        }
        .onChange(of: model.hidesWhenIdle) { _ in
            scheduleVisibilityChange()
        }
        .onChange(of: model.isEditing) { _ in
            scheduleVisibilityChange()
        }
        .onDisappear {
            visibilityWorkItem?.cancel()
        }
    }

    private var inlineOverlay: some View {
        VStack(spacing: 3) {
            header

            HStack(spacing: 3) {
                ForEach(0..<NeutralizerTracker.cadenceSegmentCount, id: \.self) { index in
                    Rectangle()
                        .fill(segmentColor(at: index))
                        .shadow(
                            color: isCurrentSegment(index)
                                ? stateColor.opacity(model.showsShadow ? 0.55 : 0)
                                : .clear,
                            radius: model.showsShadow ? 3 : 0
                        )
                }
            }
            .frame(width: cadenceWidth, height: 4)
            .opacity(cadenceOpacity)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            Rectangle()
                .fill(
                    Color(red: 0.018, green: 0.035, blue: 0.043)
                        .opacity(reduceTransparency ? 1 : 0.92)
                )
                .overlay {
                    Rectangle()
                        .stroke(
                            Color(red: 0.31, green: 0.42, blue: 0.45)
                                .opacity(colorSchemeContrast == .increased ? 1 : 0.72)
                        )
                }
        )
        .shadow(
            color: model.showsShadow ? .black.opacity(0.85) : .clear,
            radius: model.showsShadow ? 2 : 0,
            y: model.showsShadow ? 1 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(stateColor)
                .frame(width: 7, height: 11, alignment: .center)
                .accessibilityHidden(true)

            amount(model.neutralizerLastAmountGJ)

            Text("·")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(red: 0.51, green: 0.62, blue: 0.65))
                .accessibilityHidden(true)

            amount(model.neutralizerTotalAmountGJ)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func amount(_ value: Int?) -> some View {
        Text(value.map { "\($0) GJ" } ?? "— GJ")
            .font(.system(size: 11, weight: .regular, design: .default))
            .monospacedDigit()
            .foregroundStyle(Color(red: 0.90, green: 0.96, blue: 0.97))
            .fixedSize()
    }

    private var stateColor: Color {
        switch model.neutralizerState {
        case .draining:
            return Color(red: 0.83, green: 0.63, blue: 0.29)
        case .dry:
            return Color(red: 0.89, green: 0.99, blue: 1.0)
        case .pinned:
            return Color(red: 0.26, green: 0.77, blue: 0.79)
        case .recovered:
            return Color(red: 0.89, green: 0.48, blue: 0.38)
        case nil:
            return Color(red: 0.51, green: 0.62, blue: 0.65)
        }
    }

    private func segmentColor(at index: Int) -> Color {
        guard model.neutralizerCadenceEventCount > 0 else {
            return Color(red: 0.06, green: 0.16, blue: 0.20)
        }

        let segmentCount = NeutralizerTracker.cadenceSegmentCount
        let age = (model.neutralizerCadenceIndex - index + segmentCount) % segmentCount
        if age == 0 {
            return stateColor
        }
        if age < model.neutralizerCadenceEventCount {
            return stateColor.opacity(0.32)
        }
        return Color(red: 0.06, green: 0.16, blue: 0.20)
    }

    private func isCurrentSegment(_ index: Int) -> Bool {
        model.neutralizerCadenceEventCount > 0
            && index == model.neutralizerCadenceIndex
    }

    private var accessibilitySummary: String {
        guard let last = model.neutralizerLastAmountGJ,
              let total = model.neutralizerTotalAmountGJ,
              let state = model.neutralizerState else {
            return "Neutralizer waiting for activity"
        }
        return "Neutralizer \(state.rawValue), last \(last) gigajoules, total \(total) gigajoules"
    }

    private func scheduleVisibilityChange(revealCurrentEvent: Bool = false) {
        visibilityWorkItem?.cancel()
        visibilityGeneration &+= 1
        let generation = visibilityGeneration
        let animationDuration = reduceMotion ? 0 : 0.14

        if model.isEditing {
            withAnimation(.easeOut(duration: animationDuration)) {
                overlayOpacity = 1
                cadenceOpacity = 1
            }
            return
        }

        guard let lastEventAt = model.neutralizerLastEventAt else {
            withAnimation(.easeOut(duration: animationDuration)) {
                overlayOpacity = model.hidesWhenIdle ? 0 : 0.28
                cadenceOpacity = 0.08
            }
            return
        }

        if revealCurrentEvent {
            if reduceMotion {
                overlayOpacity = 1
                cadenceOpacity = 1
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    overlayOpacity = 1
                    cadenceOpacity = 1
                }
            }
        }

        let idleTime = Date().timeIntervalSince(lastEventAt)
        let delay = max(0, model.neutralizerIdleAfter - idleTime)
        let targetOpacity = model.hidesWhenIdle ? 0.0 : 0.38
        let fadeDuration = reduceMotion ? 0 : (model.hidesWhenIdle ? 1.5 : 0.35)

        let workItem = DispatchWorkItem {
            guard generation == visibilityGeneration else { return }
            withAnimation(.linear(duration: fadeDuration)) {
                overlayOpacity = targetOpacity
                cadenceOpacity = 0.08
            }
        }
        visibilityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
