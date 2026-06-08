//
//  AppSettings.swift
//  BoardCore
//

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AppSettings {
    private static let volumeKey = "appVolume"
    private static let hapticIntensityKey = "appHapticIntensity"
    private static let backgroundRedKey = "backgroundRed"
    private static let backgroundGreenKey = "backgroundGreen"
    private static let backgroundBlueKey = "backgroundBlue"
    private static let backgroundOpacityKey = "backgroundOpacity"
    private static let qrScanCameraPositionKey = "qrScanCameraPosition"
    private static let campaignsEnabledKey = "campaignsEnabled"
    private static let developerModeEnabledKey = "developerModeEnabled"
    private static let trikiControllerEnabledKey = "trikiControllerEnabled"
    private static let trikiControllerCalibratedKey = "trikiControllerCalibrated"
    private static let visualStyleKey = "appVisualStyle"

    static let defaultBackgroundRed = 0.95
    static let defaultBackgroundGreen = 0.97
    static let defaultBackgroundBlue = 1.0
    static let defaultBackgroundOpacity = 1.0
    /// Minimalna widoczność poświaty — zapobiega całkowicie czarnemu ekranowi przy suwaku przezroczystości.
    static let minimumBackgroundOpacity = 0.22

    var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: Self.volumeKey) }
    }

    var hapticIntensity: Double {
        didSet { UserDefaults.standard.set(hapticIntensity, forKey: Self.hapticIntensityKey) }
    }

    var backgroundRed: Double {
        didSet { UserDefaults.standard.set(backgroundRed, forKey: Self.backgroundRedKey) }
    }

    var backgroundGreen: Double {
        didSet { UserDefaults.standard.set(backgroundGreen, forKey: Self.backgroundGreenKey) }
    }

    var backgroundBlue: Double {
        didSet { UserDefaults.standard.set(backgroundBlue, forKey: Self.backgroundBlueKey) }
    }

    var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: Self.backgroundOpacityKey) }
    }

    var qrScanCameraPosition: QRScanCameraPosition {
        didSet { UserDefaults.standard.set(qrScanCameraPosition.rawValue, forKey: Self.qrScanCameraPositionKey) }
    }

    var campaignsEnabled: Bool {
        didSet {
            if campaignsEnabled && !canEnableCampaigns {
                campaignsEnabled = false
                return
            }
            UserDefaults.standard.set(campaignsEnabled, forKey: Self.campaignsEnabledKey)
        }
    }

    /// Po włączeniu w ustawieniach pojawia się zakładka DevCentrum.
    var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: Self.developerModeEnabledKey) }
    }

    /// Włącza sterowanie gestami kontrolera Triki podczas rozgrywki.
    var trikiControllerEnabled: Bool {
        didSet { UserDefaults.standard.set(trikiControllerEnabled, forKey: Self.trikiControllerEnabledKey) }
    }

    /// Zapamiętuje, że użytkownik wykonał kalibrację pozycji neutralnej Triki.
    var trikiControllerCalibrated: Bool {
        didSet { UserDefaults.standard.set(trikiControllerCalibrated, forKey: Self.trikiControllerCalibratedKey) }
    }

    /// Wygląd interfejsu: elegancki lub kreskówkowy.
    var visualStyle: AppVisualStyle {
        didSet {
            UserDefaults.standard.set(visualStyle.rawValue, forKey: Self.visualStyleKey)
            AppAppearance.applyTabBarAppearance(for: visualStyle)
        }
    }

    /// Kampanie można włączyć tylko na urządzeniach z więcej niż 5 GB RAM.
    var canEnableCampaigns: Bool {
        !DeviceMemory.blocksCampaignsDueToLowRAM
    }

    var effectiveCampaignsEnabled: Bool {
        campaignsEnabled && canEnableCampaigns
    }

    var backgroundColor: Color {
        get { color(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, opacity: backgroundOpacity) }
        set { applyColor(newValue) }
    }

    /// Jaśniejszy odcień poświaty — używany przez przyciski i akcenty UI.
    var accentColor: Color {
        visualStyle.styledAccent(from: backgroundColor)
    }

    var backgroundColorKey: String {
        "\(backgroundRed)-\(backgroundGreen)-\(backgroundBlue)-\(backgroundOpacity)"
    }

    var accentColorKey: String { "\(backgroundColorKey)-\(visualStyle.rawValue)" }

    init() {
        let defaults = UserDefaults.standard
        volume = defaults.object(forKey: Self.volumeKey) as? Double ?? 0.8
        hapticIntensity = defaults.object(forKey: Self.hapticIntensityKey) as? Double ?? 1.0
        backgroundRed = defaults.object(forKey: Self.backgroundRedKey) as? Double ?? Self.defaultBackgroundRed
        backgroundGreen = defaults.object(forKey: Self.backgroundGreenKey) as? Double ?? Self.defaultBackgroundGreen
        backgroundBlue = defaults.object(forKey: Self.backgroundBlueKey) as? Double ?? Self.defaultBackgroundBlue
        let storedOpacity = defaults.object(forKey: Self.backgroundOpacityKey) as? Double ?? Self.defaultBackgroundOpacity
        backgroundOpacity = max(Self.minimumBackgroundOpacity, storedOpacity)
        if let raw = defaults.string(forKey: Self.qrScanCameraPositionKey),
           let position = QRScanCameraPosition(rawValue: raw) {
            qrScanCameraPosition = position
        } else {
            qrScanCameraPosition = .front
        }

        if defaults.object(forKey: Self.campaignsEnabledKey) != nil {
            campaignsEnabled = defaults.bool(forKey: Self.campaignsEnabledKey)
        } else {
            campaignsEnabled = !DeviceMemory.blocksCampaignsDueToLowRAM
        }
        if DeviceMemory.blocksCampaignsDueToLowRAM {
            campaignsEnabled = false
        }
        developerModeEnabled = defaults.bool(forKey: Self.developerModeEnabledKey)
        trikiControllerEnabled = defaults.bool(forKey: Self.trikiControllerEnabledKey)
        trikiControllerCalibrated = defaults.bool(forKey: Self.trikiControllerCalibratedKey)
        if let raw = defaults.string(forKey: Self.visualStyleKey) {
            if raw == "fantasy" {
                visualStyle = .elegant
                defaults.set(AppVisualStyle.elegant.rawValue, forKey: Self.visualStyleKey)
            } else if let style = AppVisualStyle(rawValue: raw) {
                visualStyle = style
            } else {
                visualStyle = .elegant
            }
        } else {
            visualStyle = .elegant
        }
        AppAppearance.applyTabBarAppearance(for: visualStyle)
    }

    func resetToDefaults() {
        volume = 0.8
        hapticIntensity = 1.0
        backgroundRed = Self.defaultBackgroundRed
        backgroundGreen = Self.defaultBackgroundGreen
        backgroundBlue = Self.defaultBackgroundBlue
        backgroundOpacity = Self.defaultBackgroundOpacity
        qrScanCameraPosition = .front
        campaignsEnabled = !DeviceMemory.blocksCampaignsDueToLowRAM
        developerModeEnabled = false
        trikiControllerEnabled = false
        trikiControllerCalibrated = false
        visualStyle = .elegant
    }

    private func color(red: Double, green: Double, blue: Double, opacity: Double) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    private func applyColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            applyBackgroundComponents(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                opacity: Double(alpha)
            )
            return
        }

        guard
            let rgb = uiColor.cgColor.converted(
                to: CGColorSpaceCreateDeviceRGB(),
                intent: .defaultIntent,
                options: nil
            )?.components
        else { return }

        switch rgb.count {
        case 2:
            applyBackgroundComponents(
                red: Double(rgb[0]),
                green: Double(rgb[0]),
                blue: Double(rgb[0]),
                opacity: Double(rgb[1])
            )
        default:
            applyBackgroundComponents(
                red: Double(rgb[0]),
                green: Double(rgb[1]),
                blue: Double(rgb[2]),
                opacity: Double(rgb.count > 3 ? rgb[3] : 1.0)
            )
        }
    }

    private func applyBackgroundComponents(
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double
    ) {
        backgroundRed = red
        backgroundGreen = green
        backgroundBlue = blue
        backgroundOpacity = max(Self.minimumBackgroundOpacity, opacity)
    }

    /// Jaśniejsza wersja koloru poświaty (np. fiolet → jasny fiolet na przyciskach).
    static func buttonTint(fromGlow glow: Color) -> Color {
        let uiColor = UIColor(glow)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let liftedBrightness = min(1, brightness * 0.38 + 0.58)
            let softenedSaturation = min(1, max(0.22, saturation * 0.78 + 0.08))
            return Color(
                UIColor(
                    hue: hue,
                    saturation: softenedSaturation,
                    brightness: liftedBrightness,
                    alpha: alpha
                )
            )
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(
                UIColor(
                    red: min(1, red * 0.35 + 0.52),
                    green: min(1, green * 0.35 + 0.52),
                    blue: min(1, blue * 0.35 + 0.52),
                    alpha: alpha
                )
            )
        }

        return glow.opacity(0.85)
    }
}
