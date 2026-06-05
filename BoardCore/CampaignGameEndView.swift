//
//  CampaignGameEndView.swift
//  BoardCore
//

import SwiftUI

struct CampaignEndRankingRow: Identifiable {
    let id: UUID
    let place: Int
    let playerName: String
    let valueLabel: String
}

struct CampaignGameEndView: View {
    @Environment(AppSettings.self) private var settings

    let campaignTitle: String
    let financeRanking: [CampaignEndRankingRow]
    let abilityRanking: [CampaignEndRankingRow]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Koniec gry")
                        .font(.largeTitle.bold())
                    Text(campaignTitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Kampania fabularna dobiegła końca. Oto podsumowanie drużyny.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                rankingSection(
                    title: "Największy fundusz",
                    icon: "dollarsign.circle.fill",
                    tint: .yellow,
                    rows: financeRanking
                )

                rankingSection(
                    title: "Najwięcej zdolności",
                    icon: "sparkles",
                    tint: settings.accentColor,
                    rows: abilityRanking
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollBounceBehavior(.basedOnSize)
        .appScrollSurface()
    }

    private func rankingSection(
        title: String,
        icon: String,
        tint: Color,
        rows: [CampaignEndRankingRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title2.bold())
                .foregroundStyle(tint)

            if rows.isEmpty {
                Text("Brak danych graczy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        HStack(spacing: 14) {
                            Text("\(row.place).")
                                .font(.title2.bold())
                                .foregroundStyle(tint)
                                .frame(width: 36, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.playerName)
                                    .font(.headline)
                                Text(row.valueLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LiquidGlassBackground(accentStroke: tint, cornerRadius: 14)
                        )
                    }
                }
            }
        }
    }
}

enum CampaignEndRankings {
    static func financeRows(
        players: [PlayerCharacter],
        stats: [UUID: PlayerRuntimeStats]
    ) -> [CampaignEndRankingRow] {
        let sorted = players.sorted { lhs, rhs in
            let left = stats[lhs.id]?.finances ?? 0
            let right = stats[rhs.id]?.finances ?? 0
            if left != right { return left > right }
            return lhs.displayTitle < rhs.displayTitle
        }
        return placeRows(sorted: sorted) { player in
            let value = stats[player.id]?.finances ?? 0
            return "\(value) monet"
        }
    }

    static func abilityRows(
        players: [PlayerCharacter],
        stats: [UUID: PlayerRuntimeStats],
        grantedAbilityIDs: [UUID: [UUID]]
    ) -> [CampaignEndRankingRow] {
        let sorted = players.sorted { lhs, rhs in
            let leftCount = grantedAbilityIDs[lhs.id]?.count ?? 0
            let rightCount = grantedAbilityIDs[rhs.id]?.count ?? 0
            if leftCount != rightCount { return leftCount > rightCount }
            let leftStat = stats[lhs.id]?.abilities ?? 0
            let rightStat = stats[rhs.id]?.abilities ?? 0
            if leftStat != rightStat { return leftStat > rightStat }
            return lhs.displayTitle < rhs.displayTitle
        }
        return placeRows(sorted: sorted) { player in
            let count = grantedAbilityIDs[player.id]?.count ?? 0
            let stat = stats[player.id]?.abilities ?? 0
            if count > 0 {
                return "\(count) zdolności w ekwipunku · pasek \(stat)"
            }
            return "Pasek zdolności: \(stat)"
        }
    }

    private static func placeRows(
        sorted: [PlayerCharacter],
        valueLabel: (PlayerCharacter) -> String
    ) -> [CampaignEndRankingRow] {
        sorted.enumerated().map { index, player in
            CampaignEndRankingRow(
                id: player.id,
                place: index + 1,
                playerName: player.displayTitle,
                valueLabel: valueLabel(player)
            )
        }
    }
}
