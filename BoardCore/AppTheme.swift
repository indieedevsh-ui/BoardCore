//
//  AppTheme.swift
//  BoardCore
//

import SwiftUI

// MARK: - Liquid glass / styled surfaces

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
        AppStyledSurfaceBackground(
            accentStroke: accentStroke,
            cornerRadius: cornerRadius,
            fillOpacity: fillOpacity,
            prominent: false
        )
    }
}

struct LiquidGlassProminentBackground: View {
    var accent: Color
    var cornerRadius: CGFloat = 12

    var body: some View {
        AppStyledSurfaceBackground(
            accentStroke: accent,
            cornerRadius: cornerRadius,
            prominent: true
        )
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

    private var resolvedAccent: Color {
        let base = accent ?? settings.accentColor
        return settings.visualStyle.styledAccent(from: base)
    }

    private var resolvedRadius: CGFloat {
        cornerRadius == 12 ? settings.visualStyle.metrics.buttonCornerRadius : cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                AppStyledSurfaceBackground(
                    accentStroke: resolvedAccent,
                    cornerRadius: resolvedRadius,
                    prominent: prominent
                )
            }
    }
}

// MARK: - Style przycisków

struct AppProminentButtonStyle: ButtonStyle {
    @Environment(AppSettings.self) private var settings

    func makeBody(configuration: Configuration) -> some View {
        let metrics = settings.visualStyle.metrics
        let accent = settings.visualStyle.styledAccent(from: settings.accentColor)

        configuration.label
            .appCartoonTypography(textStyle: .headline)
            .foregroundStyle(buttonForeground(prominent: true))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background {
                AppStyledSurfaceBackground(
                    accentStroke: accent,
                    cornerRadius: metrics.buttonCornerRadius,
                    prominent: true
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .scaleEffect(configuration.isPressed ? metrics.pressedScale : 1)
            .animation(metrics.pressAnimation, value: configuration.isPressed)
    }

    private var horizontalPadding: CGFloat {
        settings.visualStyle == .cartoon ? 18 : 16
    }

    private var verticalPadding: CGFloat {
        settings.visualStyle == .cartoon ? 14 : 12
    }

    private func buttonForeground(prominent: Bool) -> Color {
        .white
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(AppSettings.self) private var settings

    func makeBody(configuration: Configuration) -> some View {
        let metrics = settings.visualStyle.metrics
        let accent = settings.visualStyle.styledAccent(from: settings.accentColor)

        configuration.label
            .appCartoonTypography(textStyle: .headline)
            .foregroundStyle(buttonForeground)
            .padding(.horizontal, settings.visualStyle == .cartoon ? 18 : 16)
            .padding(.vertical, settings.visualStyle == .cartoon ? 14 : 12)
            .frame(maxWidth: .infinity)
            .background {
                AppStyledSurfaceBackground(
                    accentStroke: accent,
                    cornerRadius: metrics.buttonCornerRadius,
                    fillOpacity: metrics.fillOpacity,
                    prominent: false
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .scaleEffect(configuration.isPressed ? metrics.pressedScale : 1)
            .animation(metrics.pressAnimation, value: configuration.isPressed)
    }

    private var buttonForeground: Color {
        .white.opacity(0.95)
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
            .tint(settings.visualStyle.styledAccent(from: settings.accentColor))
    }
}
