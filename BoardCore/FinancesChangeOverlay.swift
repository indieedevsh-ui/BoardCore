//
//  FinancesChangeOverlay.swift
//  BoardCore
//

import SwiftUI

struct FinancesChangePresentation: Equatable, Identifiable {
    let id = UUID()
    let delta: Int

    var isGain: Bool { delta > 0 }
    var absoluteAmount: Int { abs(delta) }
}

struct FinancesChangeOverlay: View {
    @Environment(AppSettings.self) private var settings

    let presentation: FinancesChangePresentation
    let onDismiss: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var displayedAmount: Int = 0
    @State private var floatOffset: CGFloat = 24

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity * 0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: presentation.isGain ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.5), radius: 16)

                HStack(spacing: 10) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title)
                        .foregroundStyle(.yellow)

                    Text(formattedAmount)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Text(presentation.isGain ? "Monety" : "Utrata monet")
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .background(
                LiquidGlassBackground(accentStroke: accentColor, cornerRadius: 28, fillOpacity: 0.14)
            )
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .offset(y: floatOffset)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) {
                backdropOpacity = 1
                floatOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
                contentScale = 1
                contentOpacity = 1
            }

            animateAmount()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.85))
                dismiss()
            }
        }
    }

    private var accentColor: Color {
        presentation.isGain ? .green : .red
    }

    private var formattedAmount: String {
        presentation.isGain ? "+\(displayedAmount)" : "−\(displayedAmount)"
    }

    private func animateAmount() {
        let target = presentation.absoluteAmount
        guard target > 0 else {
            displayedAmount = 0
            return
        }

        let maxUnitTicks = 40
        let tickCount = min(target, maxUnitTicks)
        let intervalMs = tickCount <= 12 ? 30 : (tickCount <= 25 ? 26 : 22)
        settings.playCoinPaperTicksSound(adding: presentation.isGain, count: tickCount)

        Task { @MainActor in
            if target <= maxUnitTicks {
                for value in 1...target {
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.05)) {
                        displayedAmount = value
                    }
                    try? await Task.sleep(for: .milliseconds(intervalMs))
                }
            } else {
                for step in 1...tickCount {
                    guard !Task.isCancelled else { return }
                    let progress = Double(step) / Double(tickCount)
                    let eased = 1 - pow(1 - progress, 2.4)
                    let nextValue = max(1, Int((Double(target) * eased).rounded()))
                    withAnimation(.easeOut(duration: 0.05)) {
                        displayedAmount = nextValue
                    }
                    try? await Task.sleep(for: .milliseconds(intervalMs))
                }
                displayedAmount = target
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            backdropOpacity = 0
            contentOpacity = 0
            contentScale = 0.92
            floatOffset = -12
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            onDismiss()
        }
    }
}
