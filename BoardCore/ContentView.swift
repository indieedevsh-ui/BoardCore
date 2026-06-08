//
//  ContentView.swift
//  BoardCore
//
//  Created by Michał Wołtosz on 30/05/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab: AppRootTab = .menu
    @State private var menuNavigationDepth = 0
    @State private var cartoonTabBarVisible = true

    var body: some View {
        Group {
            if settings.visualStyle == .cartoon {
                cartoonRootShell
            } else {
                elegantTabView
            }
        }
        .overlay { AppBackgroundSync() }
        .dmdRootTheme()
        .appVisualStyleEnvironment()
        .appStyledToggles()
        .trikiNavigationHost(isBlocked: isTrikiNavigationBlocked)
        .onAppear {
            AppAppearance.applyTransparentChrome()
            AppAppearance.applyTabBarAppearance(for: settings.visualStyle)
            AppAppearance.refreshViewHierarchyBackgrounds()
            BackgroundMusicPlayer.startLoopingIfNeeded(appVolume: settings.volume)
            ensureValidSelectedTab()
        }
        .onChange(of: settings.effectiveCampaignsEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.developerModeEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.trikiControllerEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.visualStyle) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: settings.volume) { _, newVolume in
            BackgroundMusicPlayer.updateVolume(newVolume)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if settings.visualStyle != .cartoon {
                settings.playTapSound()
            }
            DispatchQueue.main.async {
                AppAppearance.refreshViewHierarchyBackgrounds()
            }
        }
        .onPreferenceChange(AppCartoonTabBarVisibilityKey.self) { cartoonTabBarVisible = $0 }
    }

    private var elegantTabView: some View {
        TabView(selection: $selectedTab) {
            rootTabScreen(.menu)
                .tag(AppRootTab.menu)
                .tabItem {
                    Label(AppRootTab.menu.title, systemImage: AppRootTab.menu.systemImage)
                }

            if settings.effectiveCampaignsEnabled {
                rootTabScreen(.campaigns)
                    .tag(AppRootTab.campaigns)
                    .tabItem {
                        Label(AppRootTab.campaigns.title, systemImage: AppRootTab.campaigns.systemImage)
                    }
            }

            if settings.developerModeEnabled {
                rootTabScreen(.creator)
                    .tag(AppRootTab.creator)
                    .tabItem {
                        Label(AppRootTab.creator.title, systemImage: AppRootTab.creator.systemImage)
                    }
            }

            if settings.trikiControllerEnabled {
                rootTabScreen(.trikiController)
                    .tag(AppRootTab.trikiController)
                    .tabItem {
                        Label(AppRootTab.trikiController.title, systemImage: AppRootTab.trikiController.systemImage)
                    }
            }

            rootTabScreen(.settings)
                .tag(AppRootTab.settings)
                .tabItem {
                    Label(AppRootTab.settings.title, systemImage: AppRootTab.settings.systemImage)
                }
        }
        .appTabBarChrome()
    }

    private var cartoonRootShell: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(visibleRootTabs, id: \.self) { tab in
                    rootTabScreen(tab)
                        .opacity(selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(selectedTab == tab)
                        .accessibilityHidden(selectedTab != tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if cartoonTabBarVisible {
                CartoonBottomTabBar(
                    selectedTab: $selectedTab,
                    tabs: visibleRootTabs
                )
            }
        }
    }

    private var visibleRootTabs: [AppRootTab] {
        AppRootTab.visibleTabs(for: settings)
    }

    @ViewBuilder
    private func rootTabScreen(_ tab: AppRootTab) -> some View {
        switch tab {
        case .menu:
            MenuView(navigationDepth: $menuNavigationDepth)
                .appTabRootScreen()
        case .campaigns:
            CampaignsHomeView()
                .appTabRootScreen()
        case .creator:
            CreatorHomeView()
                .appTabRootScreen()
        case .trikiController:
            TrikiControllerDebugView()
                .appTabRootScreen()
        case .settings:
            SettingsView()
                .appTabRootScreen()
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
        let visible = Set(visibleRootTabs)
        if !visible.contains(selectedTab) {
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
