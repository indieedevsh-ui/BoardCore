//
//  PlayerCharacterRow.swift
//  BoardCore
//

import SwiftUI

struct PlayerCharacterRow: View {
    @Environment(PlayerSlotStore.self) private var playerSlotStore

    let player: PlayerCharacter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let slot = player.lobbySlotNumber {
                PlayerSlotAppearanceView(
                    record: playerSlotStore.characterRecord(for: slot),
                    slot: slot,
                    playerSlotStore: playerSlotStore,
                    size: 56,
                    cornerRadius: 28
                )
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            } else if let icon = player.profileIcon {
                PlayerProfileIconBadge(icon: icon, size: 56)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(player.displayTitle)
                        .font(.headline)
                    Spacer()
                    if let qrCode = player.qrCode {
                        Text("QR \(qrCode)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    } else {
                        Text("Własna")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                Label {
                    Text(player.advantages.joined(separator: ", "))
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.subheadline)

                Label {
                    Text(player.flaws.joined(separator: ", "))
                } icon: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)

                Label {
                    Text(player.mainWeapon)
                } icon: {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
