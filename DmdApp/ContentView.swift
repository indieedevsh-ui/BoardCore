//
//  ContentView.swift
//  DmdApp
//
//  Created by Michał Wołtosz on 30/05/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab = Tab.menu
    @State private var menuNavigationDepth = 0

    private enum Tab: Hashable {
        case menu
        case campaigns
        case creator
        case trikiController
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MenuView(navigationDepth: $menuNavigationDepth)
                .appTabRootScreen()
                .tag(Tab.menu)
                .tabItem {
                    Label("Menu", systemImage: "house.fill")
                }

            if settings.effectiveCampaignsEnabled {
                CampaignsHomeView()
                    .appTabRootScreen()
                    .tag(Tab.campaigns)
                    .tabItem {
                        Label("Kampanie", systemImage: "books.vertical.fill")
                    }
            }

            if settings.developerModeEnabled {
                CreatorHomeView()
                    .appTabRootScreen()
                    .tag(Tab.creator)
                    .tabItem {
                        Label("DevCentrum", systemImage: "wand.and.stars")
                    }
            }

            TrikiControllerDebugView()
                .appTabRootScreen()
                .tag(Tab.trikiController)
                .tabItem {
                    Label("TRIKI KONTROLER", systemImage: "gamecontroller.fill")
                }

            SettingsView()
                .appTabRootScreen()
                .tag(Tab.settings)
                .tabItem {
                    Label("Ustawienia", systemImage: "gearshape.fill")
                }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .overlay { AppBackgroundSync() }
        .dmdRootTheme()
        .trikiNavigationHost(isBlocked: isTrikiNavigationBlocked)
        .onAppear {
            AppAppearance.applyTransparentChrome()
            AppAppearance.clearViewHierarchyBackgrounds()
            BackgroundMusicPlayer.startLoopingIfNeeded(appVolume: settings.volume)
            ensureValidSelectedTab()
        }
        .onChange(of: settings.effectiveCampaignsEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.developerModeEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.volume) { _, newVolume in
            BackgroundMusicPlayer.updateVolume(newVolume)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            guard oldValue != newValue else { return }
            settings.playTapSound()
            DispatchQueue.main.async {
                AppAppearance.clearViewHierarchyBackgrounds()
            }
        }
    }

    private var isTrikiNavigationBlocked: Bool {
        switch selectedTab {
        case .menu:
            return menuNavigationDepth == 0
        case .campaigns, .settings, .trikiController:
            return true
        case .creator:
            return false
        }
    }

    private func ensureValidSelectedTab() {
        if !settings.effectiveCampaignsEnabled, selectedTab == .campaigns {
            selectedTab = .menu
        }
        if !settings.developerModeEnabled, selectedTab == .creator {
            selectedTab = .menu
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(CreatorStore())
        .modelContainer(for: Item.self, inMemory: true)
}
