//
//  PowerPathAuraBackground.swift
//  BoardCore
//

import SwiftUI

/// Płynna poświata tła dla zakładki Mroku, Światła lub własnej ścieżki z DevCentrum.
struct PowerPathAuraBackground: View {
    let side: PowerPathSide?
    var customGlow: PlayerGlowColor? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geometry in
                let size = geometry.size
                let maxDim = max(size.width, size.height)

                ZStack {
                    Color.black

                    auraLayer(
                        palette: PowerPathAuraPalette(side: side, customGlow: customGlow),
                        time: time,
                        maxDim: maxDim,
                        isActive: side != nil || customGlow != nil
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.42), value: side)
        .animation(.easeInOut(duration: 0.42), value: customGlow?.animationKey)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func auraLayer(
        palette: PowerPathAuraPalette,
        time: TimeInterval,
        maxDim: CGFloat,
        isActive: Bool
    ) -> some View {
        ZStack {
            RadialGradient(
                colors: palette.topGlow,
                center: UnitPoint(
                    x: 0.5 + 0.08 * sin(time * 0.35),
                    y: 0.12 + 0.04 * cos(time * 0.28)
                ),
                startRadius: 0,
                endRadius: maxDim * 0.95
            )

            RadialGradient(
                colors: palette.midGlow,
                center: UnitPoint(
                    x: 0.22 + 0.12 * cos(time * 0.42),
                    y: 0.55 + 0.1 * sin(time * 0.38)
                ),
                startRadius: 0,
                endRadius: maxDim * 0.72
            )

            RadialGradient(
                colors: palette.bottomGlow,
                center: UnitPoint(
                    x: 0.78 + 0.1 * sin(time * 0.31),
                    y: 0.72 + 0.08 * cos(time * 0.45)
                ),
                startRadius: 0,
                endRadius: maxDim * 0.68
            )

            LinearGradient(
                colors: [
                    palette.edgeTint.opacity(0.55 + 0.08 * sin(time * 0.5)),
                    Color.black.opacity(0.92),
                    Color.black,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blur(radius: isActive ? 2 : 0)
    }
}

private struct PowerPathAuraPalette {
    let topGlow: [Color]
    let midGlow: [Color]
    let bottomGlow: [Color]
    let edgeTint: Color
    let accent: Color

    init(side: PowerPathSide?, customGlow: PlayerGlowColor? = nil) {
        if let customGlow {
            let values = Self.values(for: customGlow)
            accent = values.accent
            edgeTint = values.edgeTint
            topGlow = values.topGlow
            midGlow = values.midGlow
            bottomGlow = values.bottomGlow
            return
        }
        switch side {
        case .dark:
            accent = Color(red: 0.72, green: 0.38, blue: 1.0)
            edgeTint = Color(red: 0.42, green: 0.12, blue: 0.62)
            topGlow = [
                Color(red: 0.55, green: 0.18, blue: 0.85).opacity(0.75),
                Color(red: 0.35, green: 0.08, blue: 0.55).opacity(0.42),
                Color.clear,
            ]
            midGlow = [
                Color(red: 0.48, green: 0.14, blue: 0.72).opacity(0.5),
                Color(red: 0.25, green: 0.05, blue: 0.4).opacity(0.28),
                Color.clear,
            ]
            bottomGlow = [
                Color(red: 0.4, green: 0.1, blue: 0.65).opacity(0.38),
                Color.clear,
            ]
        case .light:
            accent = Color(red: 1.0, green: 0.88, blue: 0.35)
            edgeTint = Color(red: 0.85, green: 0.65, blue: 0.12)
            topGlow = [
                Color(red: 1.0, green: 0.82, blue: 0.28).opacity(0.7),
                Color(red: 0.9, green: 0.6, blue: 0.1).opacity(0.4),
                Color.clear,
            ]
            midGlow = [
                Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.48),
                Color(red: 0.75, green: 0.5, blue: 0.05).opacity(0.26),
                Color.clear,
            ]
            bottomGlow = [
                Color(red: 0.95, green: 0.7, blue: 0.15).opacity(0.35),
                Color.clear,
            ]
        case nil:
            accent = .white.opacity(0.4)
            edgeTint = .white.opacity(0.15)
            topGlow = [Color.white.opacity(0.12), Color.clear]
            midGlow = [Color.clear]
            bottomGlow = [Color.clear]
        }
    }

    private static func values(for glowColor: PlayerGlowColor) -> PowerPathAuraPalette {
        let accent = glowColor.swiftUIColor
        let edgeTint = Color(
            red: glowColor.red * 0.45,
            green: glowColor.green * 0.45,
            blue: glowColor.blue * 0.45,
            opacity: min(1, glowColor.opacity + 0.1)
        )
        let base = glowColor.swiftUIColor
        let deep = Color(
            red: glowColor.red * 0.28,
            green: glowColor.green * 0.28,
            blue: glowColor.blue * 0.28
        )
        return PowerPathAuraPalette(
            topGlow: [base.opacity(0.75), deep.opacity(0.42), Color.clear],
            midGlow: [base.opacity(0.5), deep.opacity(0.28), Color.clear],
            bottomGlow: [base.opacity(0.38), Color.clear],
            edgeTint: edgeTint,
            accent: accent
        )
    }

    private init(
        topGlow: [Color],
        midGlow: [Color],
        bottomGlow: [Color],
        edgeTint: Color,
        accent: Color
    ) {
        self.topGlow = topGlow
        self.midGlow = midGlow
        self.bottomGlow = bottomGlow
        self.edgeTint = edgeTint
        self.accent = accent
    }
}

extension PowerPathSide {
    var auraAccent: Color {
        switch self {
        case .dark: Color(red: 0.72, green: 0.38, blue: 1.0)
        case .light: Color(red: 1.0, green: 0.88, blue: 0.35)
        }
    }
}
