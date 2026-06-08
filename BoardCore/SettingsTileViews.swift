//
//  SettingsTileViews.swift
//  BoardCore
//

import SwiftUI

struct SettingsSectionHeader: View {
    @Environment(AppSettings.self) private var settings
    let title: String

    var body: some View {
        Text(title)
            .appCartoonTypography(textStyle: .headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsTile<Content: View>: View {
    @Environment(AppSettings.self) private var settings
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .appCartoonInkOutline()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AppStyledSurfaceBackground(
                    accentStroke: settings.accentColor,
                    cornerRadius: settings.visualStyle.metrics.tileCornerRadius,
                    fillOpacity: settings.visualStyle.metrics.fillOpacity,
                    prominent: false
                )
            }
    }
}

struct CreatorCatalogTile<Content: View>: View {
    var accentColor: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LiquidGlassBackground(accentStroke: accentColor, cornerRadius: 16)
            )
    }
}
