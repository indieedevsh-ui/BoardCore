//
//  MenuView.swift
//  BoardCore
//

import SwiftUI

private enum MenuRoute: Hashable {
    case gra
    case zasadyGry
}

struct MenuView: View {
    @Binding var navigationDepth: Int
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    SoundNavigationLink(value: MenuRoute.gra, path: $navigationPath) {
                        Text("Graj")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .liquidGlassButtonBackground(prominent: true, cornerRadius: 16)
                    }
                    .buttonStyle(.plain)

                    SoundNavigationLink(value: MenuRoute.zasadyGry, path: $navigationPath) {
                        Label("Zasady gry", systemImage: "book.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .liquidGlassButtonBackground(prominent: true, cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("Menu")
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: MenuRoute.self) { route in
                switch route {
                case .gra:
                    GameView()
                case .zasadyGry:
                    GameRulesView()
                }
            }
            .onChange(of: navigationPath.count) { _, count in
                navigationDepth = count
            }
            .onAppear {
                navigationDepth = navigationPath.count
            }
        }
    }
}

#Preview {
    MenuView(navigationDepth: .constant(0))
        .environment(AppSettings())
        .environment(PlayerSlotStore())
        .environment(CreatorStore())
}
