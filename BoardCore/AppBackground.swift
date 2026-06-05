//
//  AppBackground.swift
//  BoardCore
//

import SwiftUI
import UIKit

/// Gradient: poświata wybranego koloru u góry, rozmyta w czarne tło.
struct AppGradientBackground: View {
    @Environment(AppSettings.self) private var settings

    /// Nadpisanie koloru poświaty (np. tura gracza w rozgrywce).
    var glowColor: Color?
    /// Klucz animacji — gdy podany, używany zamiast klucza ustawień aplikacji.
    var glowColorKey: String?

    private var resolvedGlow: Color {
        glowColor ?? settings.backgroundColor
    }

    private var resolvedGlowKey: String {
        glowColorKey ?? settings.backgroundColorKey
    }

    var body: some View {
        GeometryReader { geometry in
            let glowRadius = max(geometry.size.width, geometry.size.height) * 0.92

            ZStack {
                Color.black

                RadialGradient(
                    colors: [
                        resolvedGlow.opacity(0.98),
                        resolvedGlow.opacity(0.72),
                        resolvedGlow.opacity(0.34),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: glowRadius
                )

                LinearGradient(
                    stops: [
                        .init(color: resolvedGlow.opacity(0.82), location: 0),
                        .init(color: resolvedGlow.opacity(0.48), location: 0.18),
                        .init(color: resolvedGlow.opacity(0.2), location: 0.38),
                        .init(color: Color.black.opacity(0.55), location: 0.72),
                        .init(color: Color.black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .id(resolvedGlowKey)
        .ignoresSafeArea()
    }

    init(glowColor: Color? = nil, glowColorKey: String? = nil) {
        self.glowColor = glowColor
        self.glowColorKey = glowColorKey
    }

    init(glow: PlayerGlowColor) {
        self.init(glowColor: glow.swiftUIColor, glowColorKey: glow.animationKey)
    }
}

/// Wymusza przezroczyste tło w hierarchii UIKit (TabView, Navigation, Form).
struct AppBackgroundSync: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppAppearance.applyTransparentChrome()
                AppAppearance.clearViewHierarchyBackgrounds()
            }
    }
}

extension View {
    /// Pełnoekranowa poświata za treścią.
    func appGradientBackdrop() -> some View {
        background {
            AppGradientBackground()
        }
    }

    /// Poświata + przezroczyste paski — używaj na każdym ekranie aplikacji.
    func appThemedScreen() -> some View {
        modifier(AppThemedScreenModifier())
    }

    /// Rozgrywka z animowaną poświatą aktywnego gracza.
    func gameplayThemedScreen(glow: PlayerGlowColor) -> some View {
        modifier(GameplayThemedScreenModifier(glow: glow))
    }

    func appScrollSurface() -> some View {
        modifier(AppScrollSurfaceModifier())
    }

    func appFormSurface() -> some View {
        modifier(AppFormSurfaceModifier())
    }

    @available(*, deprecated, renamed: "appThemedScreen")
    func appClearNavigationStack() -> some View {
        appThemedScreen()
    }

    @available(*, deprecated, renamed: "appThemedScreen")
    func transparentAppChrome() -> some View {
        appThemedScreen()
    }

    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }

    /// Otoczka głównych zakładek TabView.
    func appTabRootScreen() -> some View {
        appThemedScreen()
    }
}

private struct AppThemedScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppGradientBackground()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .containerBackground(.clear, for: .navigation)
    }
}

private struct GameplayThemedScreenModifier: ViewModifier {
    let glow: PlayerGlowColor

    func body(content: Content) -> some View {
        ZStack {
            AppGradientBackground(
                glowColor: glow.swiftUIColor,
                glowColorKey: glow.animationKey
            )
            .animation(.easeInOut(duration: 0.55), value: glow.animationKey)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .containerBackground(.clear, for: .navigation)
    }
}

private struct AppScrollSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}

private struct AppFormSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listRowBackground(Color.clear)
            .listSectionSeparatorTint(.clear)
            .background(Color.clear)
    }
}

enum AppAppearance {
    static func configure() {
        applyTransparentChrome()
    }

    static func applyTransparentChrome() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithTransparentBackground()
        navigationBar.backgroundColor = .clear
        navigationBar.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
        UINavigationBar.appearance().isTranslucent = true

        let tabBar = UITabBarAppearance()
        tabBar.configureWithTransparentBackground()
        tabBar.backgroundColor = .clear
        tabBar.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }

    static func clearViewHierarchyBackgrounds() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                clearViewBackgrounds(in: window)
            }
        }
    }

    private static func clearViewBackgrounds(in window: UIWindow) {
        clearViewBackgrounds(in: window, depth: 0)
    }

    private static func clearViewBackgrounds(in view: UIView, depth: Int) {
        guard depth < 48 else { return }

        let typeName = String(describing: type(of: view))
        let shouldClear =
            typeName.contains("UIHosting")
            || typeName.contains("UITabBar")
            || typeName.contains("UINavigation")
            || typeName.contains("UIScrollView")
            || typeName.contains("UITableView")
            || typeName.contains("UICollectionView")

        if shouldClear {
            view.backgroundColor = .clear
            view.isOpaque = false
        }

        for subview in view.subviews {
            clearViewBackgrounds(in: subview, depth: depth + 1)
        }
    }
}

private struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppGradientBackground()
            content
        }
    }
}

extension AppSettings {
    func playTapSound() {
        HapticManager.playButtonTap(intensity: hapticIntensity)
        SoundManager.playTap(volume: volume)
    }

    func playSkipTurnSound() {
        HapticManager.playSkipTurn(intensity: hapticIntensity)
        SoundManager.playSkipTurn(volume: volume)
    }

    func playStatsRevealSound() {
        HapticManager.playStatReveal(intensity: hapticIntensity)
        SoundManager.playStatsReveal(volume: volume)
    }

    func playShopOpenSound() {
        HapticManager.playButtonTap(intensity: hapticIntensity * 0.65)
        SoundManager.playShopOpen(volume: volume)
    }

    func playDrawShuffleFeedback(tickIndex: Int, phase: Double) {
        HapticManager.playDrawPulse(intensity: hapticIntensity, phase: phase)
        SoundManager.playDrawShuffleTick(volume: volume, tickIndex: tickIndex)
    }

    func playDrawRevealSound() {
        HapticManager.playStatReveal(intensity: hapticIntensity)
        SoundManager.playDrawReveal(volume: volume)
    }

    func playArtifactBrushFeedback(tickIndex: Int, phase: Double) {
        HapticManager.playArtifactBrushPulse(intensity: hapticIntensity, phase: phase)
        SoundManager.playArtifactCrystalPulse(volume: volume, tickIndex: tickIndex, phase: phase)
    }

    func playArtifactRevealSound(positive: Bool) {
        if positive {
            HapticManager.playStatReveal(intensity: hapticIntensity)
        } else {
            HapticManager.playSkipTurn(intensity: hapticIntensity * 0.75)
        }
        SoundManager.playArtifactReveal(volume: volume, positive: positive)
    }

    func playShopPurchaseSound() {
        HapticManager.playShopPurchase(intensity: hapticIntensity)
        SoundManager.playShopPurchase(volume: volume)
    }

    func playShopSellSound() {
        HapticManager.playShopSell(intensity: hapticIntensity)
        SoundManager.playShopSell(volume: volume)
    }

    func playCoinPaperSound(adding: Bool) {
        playCoinPaperTicksSound(adding: adding, count: 1)
    }

    func playCoinPaperTicksSound(adding: Bool, count: Int) {
        guard count > 0 else { return }
        let hapticScale = adding ? 0.42 : 0.36
        HapticManager.playButtonTap(intensity: hapticIntensity * hapticScale * min(1, 0.35 + Double(count) * 0.04))
        SoundManager.playCoinPaperTicks(volume: volume, adding: adding, count: count)
    }
}
