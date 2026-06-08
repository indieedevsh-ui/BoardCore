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
    let winnerPlayerName: String?
    let endSummary: String
    let financeRanking: [CampaignEndRankingRow]
    let abilityRanking: [CampaignEndRankingRow]
    let bossFightRanking: [CampaignEndRankingRow]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Koniec gry")
                        .font(.largeTitle.bold())
                    Text(campaignTitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(endSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let winnerPlayerName {
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zwycięzca")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(winnerPlayerName)
                                    .font(.title3.bold())
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LiquidGlassBackground(accentStroke: .yellow, cornerRadius: 14)
                        )
                    }
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

                rankingSection(
                    title: "Najwięcej walk z bossem",
                    icon: "shield.lefthalf.filled",
                    tint: .orange,
                    rows: bossFightRanking
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
        stats: [UUID: PlayerRuntimeStats],
        itemValuesByPlayer: [UUID: Int]
    ) -> [CampaignEndRankingRow] {
        let sorted = players.sorted { lhs, rhs in
            let left = totalFinances(playerID: lhs.id, stats: stats, itemValue: itemValuesByPlayer[lhs.id] ?? 0)
            let right = totalFinances(playerID: rhs.id, stats: stats, itemValue: itemValuesByPlayer[rhs.id] ?? 0)
            if left != right { return left > right }
            return lhs.displayTitle < rhs.displayTitle
        }
        return placeRows(sorted: sorted) { player in
            let cash = stats[player.id]?.finances ?? 0
            let items = itemValuesByPlayer[player.id] ?? 0
            if items > 0 {
                return "\(cash + items) monet (gotówka \(cash) + przedmioty \(items))"
            }
            return "\(cash) monet"
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

    static func bossFightRows(
        players: [PlayerCharacter],
        bossFightCounts: [UUID: Int]
    ) -> [CampaignEndRankingRow] {
        let sorted = players.sorted { lhs, rhs in
            let left = bossFightCounts[lhs.id] ?? 0
            let right = bossFightCounts[rhs.id] ?? 0
            if left != right { return left > right }
            return lhs.displayTitle < rhs.displayTitle
        }
        return placeRows(sorted: sorted) { player in
            let count = bossFightCounts[player.id] ?? 0
            return count == 1 ? "1 walka" : "\(count) walk"
        }
    }

    private static func totalFinances(
        playerID: UUID,
        stats: [UUID: PlayerRuntimeStats],
        itemValue: Int
    ) -> Int {
        (stats[playerID]?.finances ?? 0) + itemValue
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
