//
//  AppTheme.swift
//  BoardCore
//

import SwiftUI

// MARK: - Liquid glass

struct LiquidGlassBackground: View {
    var accentStroke: Color
    var cornerRadius: CGFloat
    var fillOpacity: Double

    init(
        accentStroke: Color = .white.opacity(0.85),
        cornerRadius: CGFloat = 12,
        fillOpacity: Double = 0.14
    ) {
        self.accentStroke = accentStroke
        self.cornerRadius = cornerRadius
        self.fillOpacity = fillOpacity
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentStroke.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accentStroke.opacity(0.9),
                                accentStroke.opacity(0.35),
                                Color.white.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: accentStroke.opacity(0.22), radius: 14, y: 8)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

struct LiquidGlassProminentBackground: View {
    var accent: Color
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.55),
                            accent.opacity(0.22),
                            accent.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            LiquidGlassBackground(
                accentStroke: accent,
                cornerRadius: cornerRadius,
                fillOpacity: 0.28
            )
        }
    }
}

extension View {
    func liquidGlassButtonBackground(prominent: Bool = true, cornerRadius: CGFloat = 12, accent: Color? = nil) -> some View {
        modifier(LiquidGlassButtonBackgroundModifier(prominent: prominent, cornerRadius: cornerRadius, accent: accent))
    }
}

private struct LiquidGlassButtonBackgroundModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    let prominent: Bool
    let cornerRadius: CGFloat
    let accent: Color?

    private var resolvedAccent: Color { accent ?? settings.accentColor }

    func body(content: Content) -> some View {
        content
            .background {
                if prominent {
                    LiquidGlassProminentBackground(
                        accent: resolvedAccent,
                        cornerRadius: cornerRadius
                    )
                } else {
                    LiquidGlassBackground(
                        accentStroke: resolvedAccent,
                        cornerRadius: cornerRadius,
                        fillOpacity: 0.1
                    )
                }
            }
    }
}

// MARK: - Style przycisków (liquid glass + kolor z AppSettings.accentColor)

struct AppProminentButtonStyle: ButtonStyle {
    @Environment(AppSettings.self) private var settings

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                LiquidGlassProminentBackground(
                    accent: settings.accentColor,
                    cornerRadius: 12
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(AppSettings.self) private var settings

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                LiquidGlassBackground(
                    accentStroke: settings.accentColor,
                    cornerRadius: 12,
                    fillOpacity: 0.12
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AppProminentButtonStyle {
    static var appProminent: AppProminentButtonStyle { AppProminentButtonStyle() }
}

extension ButtonStyle where Self == AppSecondaryButtonStyle {
    static var appSecondary: AppSecondaryButtonStyle { AppSecondaryButtonStyle() }
}

extension View {
    func dmdRootTheme() -> some View {
        modifier(DmdRootThemeModifier())
    }
}

private struct DmdRootThemeModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content
            .tint(settings.accentColor)
    }
}
