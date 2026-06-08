//
//  AppVisualStyle.swift
//  BoardCore
//

import SwiftUI
import UIKit

enum AppVisualStyle: String, CaseIterable, Codable, Identifiable {
    case elegant
    case cartoon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elegant: "Elegancki"
        case .cartoon: "Kreskówkowy"
        }
    }

    var subtitle: String {
        switch self {
        case .elegant: "Szkło, delikatne poświaty i płynne kształty."
        case .cartoon: "Grube obrysy, żywe kolory i zaokrąglone formy."
        }
    }

    var icon: String {
        switch self {
        case .elegant: "sparkles"
        case .cartoon: "face.smiling.inverse"
        }
    }

    var metrics: AppStyleMetrics {
        switch self {
        case .elegant:
            AppStyleMetrics(
                fontDesign: .default,
                cardCornerRadius: 12,
                tileCornerRadius: 16,
                buttonCornerRadius: 12,
                strokeWidth: 1.5,
                fillOpacity: 0.14,
                prominentFillOpacity: 0.28,
                usesMaterial: true,
                pressedScale: 0.98,
                pressAnimation: .easeOut(duration: 0.15),
                shadowRadius: 14,
                shadowYOffset: 8,
                hardShadowOffset: nil,
                usesGradientStroke: true,
                headlineWeight: .semibold,
                bodyFontWeight: .regular,
                inkOutlineWidth: 0,
                inkOutlineOpacity: 0
            )
        case .cartoon:
            AppStyleMetrics(
                fontDesign: .rounded,
                cardCornerRadius: 22,
                tileCornerRadius: 24,
                buttonCornerRadius: 20,
                strokeWidth: 3.5,
                fillOpacity: 0.42,
                prominentFillOpacity: 0.58,
                usesMaterial: false,
                pressedScale: 0.93,
                pressAnimation: .spring(response: 0.28, dampingFraction: 0.55),
                shadowRadius: 0,
                shadowYOffset: 0,
                hardShadowOffset: CGSize(width: 5, height: 5),
                usesGradientStroke: false,
                headlineWeight: .medium,
                bodyFontWeight: .medium,
                inkOutlineWidth: 0.55,
                inkOutlineOpacity: 0.68
            )
        }
    }

    func font(textStyle: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        switch self {
        case .cartoon:
            return CartoonFont.font(textStyle: textStyle)
        case .elegant:
            let resolvedWeight = weight ?? metrics.bodyFontWeight
            return Font.system(textStyle, design: metrics.fontDesign).weight(resolvedWeight)
        }
    }

    func font(size: CGFloat, weight: Font.Weight? = nil) -> Font {
        switch self {
        case .cartoon:
            return CartoonFont.font(size: size)
        case .elegant:
            let resolvedWeight = weight ?? metrics.bodyFontWeight
            return Font.system(size: size, weight: resolvedWeight, design: metrics.fontDesign)
        }
    }

    func screenGlowTint(from base: Color) -> Color {
        switch self {
        case .elegant:
            return base
        case .cartoon:
            let ui = UIColor(base)
            var hue: CGFloat = 0
            var sat: CGFloat = 0
            var bri: CGFloat = 0
            var alpha: CGFloat = 0
            if ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) {
                return Color(
                    UIColor(
                        hue: hue,
                        saturation: min(1, sat * 1.08 + 0.12),
                        brightness: min(1, bri * 1.02 + 0.04),
                        alpha: alpha
                    )
                )
            }
            return base
        }
    }

    func styledAccent(from base: Color) -> Color {
        switch self {
        case .elegant:
            return AppSettings.buttonTint(fromGlow: base)
        case .cartoon:
            return AppSettings.buttonTint(fromGlow: base).opacity(1)
        }
    }
}

struct AppStyleMetrics {
    let fontDesign: Font.Design
    let cardCornerRadius: CGFloat
    let tileCornerRadius: CGFloat
    let buttonCornerRadius: CGFloat
    let strokeWidth: CGFloat
    let fillOpacity: Double
    let prominentFillOpacity: Double
    let usesMaterial: Bool
    let pressedScale: CGFloat
    let pressAnimation: Animation
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
    let hardShadowOffset: CGSize?
    let usesGradientStroke: Bool
    let headlineWeight: Font.Weight
    let bodyFontWeight: Font.Weight
    let inkOutlineWidth: CGFloat
    let inkOutlineOpacity: Double
}

enum CartoonFont {
    private static let faceName = "Fredoka-Medium"

    static func font(textStyle: Font.TextStyle) -> Font {
        font(size: uiSize(for: textStyle))
    }

    static func font(size: CGFloat) -> Font {
        if UIFont(name: faceName, size: size) != nil {
            return .custom(faceName, size: size)
        }
        return .system(size: size, weight: .medium, design: .rounded)
    }

    private static func uiSize(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

struct AppStyledSurfaceBackground: View {
    @Environment(AppSettings.self) private var settings

    let accentStroke: Color
    var cornerRadius: CGFloat?
    var fillOpacity: Double?
    var prominent: Bool

    private var style: AppVisualStyle { settings.visualStyle }
    private var metrics: AppStyleMetrics { style.metrics }
    private var radius: CGFloat { cornerRadius ?? (prominent ? metrics.buttonCornerRadius : metrics.cardCornerRadius) }
    private var resolvedFill: Double { fillOpacity ?? (prominent ? metrics.prominentFillOpacity : metrics.fillOpacity) }
    private var resolvedAccent: Color { style.styledAccent(from: accentStroke) }

    var body: some View {
        Group {
            switch style {
            case .elegant:
                elegantSurface
            case .cartoon:
                cartoonSurface
            }
        }
    }

    private var elegantSurface: some View {
        ZStack {
            if metrics.usesMaterial {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(resolvedAccent.opacity(resolvedFill))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            resolvedAccent.opacity(0.9),
                            resolvedAccent.opacity(0.35),
                            Color.white.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: metrics.strokeWidth
                )
        }
        .shadow(color: resolvedAccent.opacity(0.22), radius: metrics.shadowRadius, y: metrics.shadowYOffset)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    private var cartoonSurface: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return ZStack {
            if let offset = metrics.hardShadowOffset {
                shape
                    .fill(Color.black.opacity(0.82))
                    .offset(x: offset.width, y: offset.height)
            }
            shape
                .fill(cartoonFillGradient)
                .overlay {
                    CartoonHalftoneDotOverlay()
                }
                .clipShape(shape)
            shape
                .strokeBorder(Color.black.opacity(0.88), lineWidth: metrics.strokeWidth)
            shape
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2)
                .padding(metrics.strokeWidth * 0.35)
        }
    }

    private var cartoonFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                resolvedAccent.opacity(0.72),
                resolvedAccent.opacity(0.48),
                resolvedAccent.opacity(0.34),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Jednolity, lekki czarny obrys tekstu i ikon w stylu kreskówkowym.
struct CartoonInkOutlineModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        guard settings.visualStyle == .cartoon else {
            return AnyView(content)
        }

        let metrics = settings.visualStyle.metrics
        let width = metrics.inkOutlineWidth
        let alpha = metrics.inkOutlineOpacity

        return AnyView(
            (0..<8).reduce(AnyView(content)) { view, index in
                let angle = Double(index) * .pi / 4
                return AnyView(
                    view.shadow(
                        color: .black.opacity(alpha),
                        radius: 0,
                        x: CGFloat(cos(angle)) * width,
                        y: CGFloat(sin(angle)) * width
                    )
                )
            }
        )
    }
}

/// Gęsta kropka halftone na tle kreskówkowym — gradient zostaje pod spodem.
struct CartoonHalftoneDotOverlay: View {
    var dotSpacing: CGFloat = 4.2
    var dotRadius: CGFloat = 0.95
    var dotOpacity: Double = 0.28

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let horizontalStep = dotSpacing
            let verticalStep = dotSpacing * 0.92
            let columns = Int(size.width / horizontalStep) + 3
            let rows = Int(size.height / verticalStep) + 3

            for row in 0..<rows {
                let rowOffset = row.isMultiple(of: 2) ? 0 : horizontalStep * 0.5
                for column in 0..<columns {
                    let x = CGFloat(column) * horizontalStep + rowOffset
                    let y = CGFloat(row) * verticalStep
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.black.opacity(dotOpacity))
                    )
                }
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - Kreskówkowy suwak (bez liquid glass)

struct CartoonSlider: View {
    @Environment(AppSettings.self) private var settings

    @Binding var value: Double
    let bounds: ClosedRange<Double>
    var step: Double?

    private let trackHeight: CGFloat = 16
    private let thumbSize: CGFloat = 22
    private let strokeWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let progress = normalizedProgress
            let thumbCenterX = CGFloat(progress) * width

            ZStack(alignment: .leading) {
                trackBackground(width: width)
                filledTrack(width: width * CGFloat(progress))
                thumb
                    .offset(x: thumbCenterX - thumbSize / 2)
            }
            .frame(height: trackHeight, alignment: .center)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setValue(at: gesture.location.x, width: width, playSound: false)
                    }
                    .onEnded { _ in
                        settings.playTapSound()
                    }
            )
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityValue(Text(accessibilityValueText))
        .accessibilityAdjustableAction { direction in
            adjustByAccessibility(direction)
        }
    }

    private var trackBackground: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.42), Color(white: 0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay { CartoonHalftoneDotOverlay() }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.9), lineWidth: strokeWidth)
            }
    }

    private func trackBackground(width: CGFloat) -> some View {
        trackBackground.frame(width: width, height: trackHeight)
    }

    private func filledTrack(width: CGFloat) -> some View {
        let accent = settings.accentColor

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.95), accent.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay { CartoonHalftoneDotOverlay() }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .frame(width: max(width, 0), height: trackHeight)
    }

    private var thumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .offset(x: 2.5, y: 2.5)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.9), lineWidth: 2.5)
                }
        }
        .frame(width: thumbSize, height: thumbSize)
    }

    private var normalizedProgress: Double {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return 0 }
        return (value - bounds.lowerBound) / span
    }

    private var accessibilityValueText: String {
        "\(Int((normalizedProgress * 100).rounded()))%"
    }

    private func setValue(at x: CGFloat, width: CGFloat, playSound: Bool) {
        let clampedX = min(max(0, x), width)
        let span = bounds.upperBound - bounds.lowerBound
        var newValue = bounds.lowerBound + span * Double(clampedX / width)

        if let step, step > 0 {
            newValue = (newValue / step).rounded() * step
        }
        newValue = min(bounds.upperBound, max(bounds.lowerBound, newValue))

        guard newValue != value else { return }
        value = newValue
        if playSound {
            settings.playTapSound()
        }
    }

    private func adjustByAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        let span = bounds.upperBound - bounds.lowerBound
        let delta = step ?? max(span / 20, 0.01)
        switch direction {
        case .increment:
            value = min(bounds.upperBound, value + delta)
        case .decrement:
            value = max(bounds.lowerBound, value - delta)
        @unknown default:
            break
        }
        settings.playTapSound()
    }
}

struct AppSlider<V>: View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    @Environment(AppSettings.self) private var settings
    @Binding var value: V
    let bounds: ClosedRange<V>
    var step: V.Stride?

    init(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride? = nil) {
        self._value = value
        self.bounds = bounds
        self.step = step
    }

    var body: some View {
        if settings.visualStyle == .cartoon {
            CartoonSlider(
                value: doubleBinding,
                bounds: doubleBounds,
                step: doubleStep
            )
        } else if let step {
            Slider(value: $value, in: bounds, step: step)
        } else {
            Slider(value: $value, in: bounds)
        }
    }

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { value = V($0) }
        )
    }

    private var doubleBounds: ClosedRange<Double> {
        Double(bounds.lowerBound)...Double(bounds.upperBound)
    }

    private var doubleStep: Double? {
        step.map { Double($0) }
    }
}

struct AppCartoonToggleStyle: ToggleStyle {
    @Environment(AppSettings.self) private var settings

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            cartoonSwitch(isOn: configuration.$isOn)
        }
    }

    private func cartoonSwitch(isOn: Binding<Bool>) -> some View {
        let accent = settings.accentColor
        let trackWidth: CGFloat = 58
        let trackHeight: CGFloat = 30
        let thumbSize: CGFloat = 22
        let padding: CGFloat = 4

        return Button {
            let turningOn = !isOn.wrappedValue
            settings.playCartoonToggleSound(turningOn: turningOn)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.58)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        isOn.wrappedValue
                            ? LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color(white: 0.42),
                                    Color(white: 0.28),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .overlay {
                        CartoonHalftoneDotOverlay()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(width: trackWidth, height: trackHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.9), lineWidth: 3)
                    }

                ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.black.opacity(0.82))
                        .offset(x: 2.5, y: 2.5)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.9), lineWidth: 2.5)
                        }
                }
                .frame(width: thumbSize, height: thumbSize)
                .padding(padding)
            }
            .frame(width: trackWidth, height: trackHeight)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn.wrappedValue ? "Włączone" : "Wyłączone")
    }
}

extension View {
    func appVisualStyleEnvironment() -> some View {
        modifier(AppVisualStyleEnvironmentModifier())
    }

    func appStyledToggles() -> some View {
        modifier(AppStyledToggleModifier())
    }

    func appTabBarChrome() -> some View {
        modifier(AppTabBarChromeModifier())
    }

    func appCartoonInkOutline() -> some View {
        modifier(CartoonInkOutlineModifier())
    }

    func appCartoonTypography(textStyle: Font.TextStyle = .body) -> some View {
        modifier(CartoonTypographyModifier(textStyle: textStyle))
    }
}

private struct AppVisualStyleEnvironmentModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        let style = settings.visualStyle
        let metrics = style.metrics

        Group {
            if style == .cartoon {
                content
                    .environment(\.font, style.font(textStyle: .body))
            } else {
                content
                    .fontDesign(metrics.fontDesign)
                    .environment(
                        \.font,
                        Font.system(.body, design: metrics.fontDesign).weight(metrics.bodyFontWeight)
                    )
            }
        }
        .id("app-style-\(style.rawValue)")
    }
}

private struct CartoonTypographyModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    let textStyle: Font.TextStyle

    func body(content: Content) -> some View {
        let style = settings.visualStyle
        let metrics = style.metrics

        if style == .cartoon {
            content
                .font(style.font(textStyle: textStyle))
                .appCartoonInkOutline()
        } else {
            let weight = textStyle == .headline ? metrics.headlineWeight : metrics.bodyFontWeight
            content.font(Font.system(textStyle, design: metrics.fontDesign).weight(weight))
        }
    }
}

private struct AppStyledToggleModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        switch settings.visualStyle {
        case .cartoon:
            content.toggleStyle(AppCartoonToggleStyle())
        case .elegant:
            content
        }
    }
}

private struct AppTabBarChromeModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content
            .tabBarMinimizeBehavior(.automatic)
            .toolbarBackground(.hidden, for: .tabBar)
            .onAppear {
                AppAppearance.applyTabBarAppearance(for: settings.visualStyle)
            }
            .onChange(of: settings.visualStyle) { _, newStyle in
                AppAppearance.applyTabBarAppearance(for: newStyle)
                DispatchQueue.main.async {
                    AppAppearance.refreshViewHierarchyBackgrounds()
                }
            }
    }
}

// MARK: - Kreskówkowy pasek zakładek (własne przyciski, bez systemowej pastylki)

enum AppRootTab: Hashable, CaseIterable {
    case menu
    case campaigns
    case creator
    case trikiController
    case settings

    var title: String {
        switch self {
        case .menu: "Menu"
        case .campaigns: "Kampanie"
        case .creator: "DevCentrum"
        case .trikiController: "TRIKI KONTROLER"
        case .settings: "Ustawienia"
        }
    }

    var shortTitle: String {
        switch self {
        case .trikiController: "Triki"
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .menu: "house.fill"
        case .campaigns: "books.vertical.fill"
        case .creator: "wand.and.stars"
        case .trikiController: "gamecontroller.fill"
        case .settings: "gearshape.fill"
        }
    }

    static func visibleTabs(for settings: AppSettings) -> [AppRootTab] {
        var tabs: [AppRootTab] = [.menu]
        if settings.effectiveCampaignsEnabled { tabs.append(.campaigns) }
        if settings.developerModeEnabled { tabs.append(.creator) }
        if settings.trikiControllerEnabled { tabs.append(.trikiController) }
        tabs.append(.settings)
        return tabs
    }
}

struct AppCartoonTabBarVisibilityKey: PreferenceKey {
    static var defaultValue = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value && nextValue()
    }
}

struct CartoonBottomTabBar: View {
    @Environment(AppSettings.self) private var settings
    @Binding var selectedTab: AppRootTab
    let tabs: [AppRootTab]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
        .background {
            Color.black
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(for tab: AppRootTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard !isSelected else { return }
            settings.playTapSound()
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                Text(tab.shortTitle)
                    .font(settings.visualStyle.font(textStyle: .caption2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isSelected ? Color.white : Color(white: 0.58))
            .appCartoonInkOutline()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func appCartoonTabBarVisible(_ visible: Bool) -> some View {
        preference(key: AppCartoonTabBarVisibilityKey.self, value: visible)
    }
}
