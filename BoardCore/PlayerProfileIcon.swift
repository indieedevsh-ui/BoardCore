//
//  PlayerProfileIcon.swift
//  BoardCore
//

import SwiftUI

/// Jedna z 10 ikon awatara — każda może być przypisana tylko do jednego gracza.
enum PlayerProfileIcon: String, CaseIterable, Identifiable, Codable {
    case flame
    case robot
    case legoBrick
    case leaf
    case moon
    case sun
    case bolt
    case shield
    case star
    case crown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flame: "Ogień"
        case .robot: "Robot"
        case .legoBrick: "Klocek"
        case .leaf: "Liść"
        case .moon: "Księżyc"
        case .sun: "Słońce"
        case .bolt: "Błyskawica"
        case .shield: "Tarcza"
        case .star: "Gwiazda"
        case .crown: "Korona"
        }
    }

    var systemImage: String {
        switch self {
        case .flame: "flame.fill"
        case .robot: "figure.walk.motion"
        case .legoBrick: "square.grid.2x2.fill"
        case .leaf: "leaf.fill"
        case .moon: "moon.stars.fill"
        case .sun: "sun.max.fill"
        case .bolt: "bolt.fill"
        case .shield: "shield.fill"
        case .star: "star.fill"
        case .crown: "crown.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .flame: Color(red: 1.0, green: 0.45, blue: 0.18)
        case .robot: Color(red: 0.35, green: 0.78, blue: 0.95)
        case .legoBrick: Color(red: 0.98, green: 0.78, blue: 0.2)
        case .leaf: Color(red: 0.28, green: 0.82, blue: 0.45)
        case .moon: Color(red: 0.62, green: 0.48, blue: 0.92)
        case .sun: Color(red: 1.0, green: 0.82, blue: 0.28)
        case .bolt: Color(red: 0.95, green: 0.88, blue: 0.35)
        case .shield: Color(red: 0.38, green: 0.62, blue: 0.95)
        case .star: Color(red: 0.92, green: 0.72, blue: 1.0)
        case .crown: Color(red: 0.95, green: 0.68, blue: 0.22)
        }
    }

    static func from(id: String?) -> PlayerProfileIcon? {
        guard let id, !id.isEmpty else { return nil }
        return PlayerProfileIcon(rawValue: id)
    }
}

struct PlayerProfileIconBadge: View {
    let icon: PlayerProfileIcon
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [icon.tintColor.opacity(0.35), icon.tintColor.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(icon.tintColor.opacity(0.55), lineWidth: 2)
            Image(systemName: icon.systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(icon.tintColor)
        }
        .frame(width: size, height: size)
    }
}

struct PlayerSlotAppearanceView: View {
    let record: SlotCharacterRecord?
    let slot: Int
    let playerSlotStore: PlayerSlotStore
    var size: CGFloat = 136
    var cornerRadius: CGFloat = 16

    private var photo: UIImage? {
        guard record?.usesPhoto == true else { return nil }
        return playerSlotStore.appearanceImage(for: slot)
    }

    private var profileIcon: PlayerProfileIcon? {
        record?.profileIcon
    }

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else if let profileIcon {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    profileIcon.tintColor.opacity(0.28),
                                    profileIcon.tintColor.opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    PlayerProfileIconBadge(icon: profileIcon, size: size * 0.55)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.08))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.32))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
