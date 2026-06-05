//
//  SoundButtonStyle.swift
//  BoardCore
//

import SwiftUI

/// Przycisk menu, który dopisuje cel do `NavigationPath` (głębokość ścieżki rośnie — Triki wie, że nie jesteś na root menu).
struct SoundNavigationLink<Label: View, Value: Hashable>: View {
    @Environment(AppSettings.self) private var settings

    let value: Value
    @Binding var path: NavigationPath
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            settings.playTapSound()
            path.append(value)
        } label: {
            label()
        }
    }
}
