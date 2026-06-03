//
//  QueueBlockedOverlay.swift
//  DmdApp
//

import SwiftUI

struct QueueBlockedOverlay: View {
    let playerGlow: PlayerGlowColor
    let playerName: String
    let roundsRemaining: Int
    var isTrikiSelected: Bool = false
    let onSkipTurn: () -> Void

    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)

            gridBackground

            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.orange)

                    Text("Kolejka zablokowana")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text(playerName)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("\(roundsRemaining)")
                        .font(.system(size: 88, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(roundsLabel)
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(28)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                onSkipTurn()
            } label: {
                Text("Pomiń turę")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTrikiSelected ? settings.accentColor.opacity(0.95) : .clear,
                        lineWidth: isTrikiSelected ? 2.6 : 0
                    )
                    .shadow(
                        color: isTrikiSelected ? settings.accentColor.opacity(0.7) : .clear,
                        radius: 10
                    )
                    .animation(.easeInOut(duration: 0.16), value: isTrikiSelected)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.35)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private var roundsLabel: String {
        switch roundsRemaining {
        case 1: "Została 1 tura do odblokowania"
        case 2...4: "Zostały \(roundsRemaining) tury do odblokowania"
        default: "Zostało \(roundsRemaining) tur do odblokowania"
        }
    }

    private var gridBackground: some View {
        GeometryReader { geometry in
            let columns = 10
            let rows = 16
            Path { path in
                let colStep = geometry.size.width / CGFloat(columns)
                let rowStep = geometry.size.height / CGFloat(rows)
                for index in 0...columns {
                    let x = CGFloat(index) * colStep
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for index in 0...rows {
                    let y = CGFloat(index) * rowStep
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
        }
        .ignoresSafeArea()
    }
}
