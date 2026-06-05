//
//  BossFightARView.swift
//  BoardCore
//

import ARKit
import AVFoundation
import SwiftUI
import UIKit

private enum BossARFlowPhase: Equatable {
    case preparation
    case combat
}

struct BossFightARView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(TrikiNavigationCoordinator.self) private var trikiCoordinator

    private let bossARTrikiFocusID = UUID()

    let mainFighter: PlayerCharacter
    let players: [PlayerCharacter]
    let playerStats: [UUID: PlayerRuntimeStats]
    let playerEquippedItems: PlayerEquipmentMap
    let catalogItems: [CreatedItem]
    let sessionAbilityPool: GameplaySessionAbilityPoolState
    let onPlayerHealthUpdate: (UUID, Int) -> Void
    let onPlayerStatsUpdate: (UUID, PlayerRuntimeStats) -> Void
    let onAbilityConsumed: (UUID, UUID) -> Void
    let onCombatFinished: (BossFightCombatOutcome) -> Void
    @Binding var externalSelectedMove: BossClashMove?
    let onExit: () -> Void

    @State private var flowPhase: BossARFlowPhase = .preparation
    @State private var supporters: [PlayerCharacter] = []
    @State private var visiblePlayerIDs: Set<UUID> = []
    @State private var statsHeaderLabel = ""
    @State private var displayStats = BossFightDisplayStats.zero
    @State private var statDeltas = EquipmentLoadoutBonus.zero
    @State private var bossSelectionStarted = false
    @State private var showBossSelection = false
    @State private var selectedBoss: BossDefinition?
    @State private var combatSession: BossCombatSession?
    @State private var statusMessage = "Skanuj QR gracza (4001–4004). Schowaj figurkę, by ukryć statystyki."
    @State private var lastScanAt: [String: TimeInterval] = [:]
    @State private var playerPresenceTracker = MultiPlayerPresenceTracker()
    @State private var supporterCandidateSince: [UUID: TimeInterval] = [:]
    @State private var supporterRemovalCandidateSince: [UUID: TimeInterval] = [:]
    @State private var combatIconPulse: BossFightCombatIconPulse?
    @State private var supportJoinPresentation: BossFightSupportJoinPresentation?
    @State private var roundTask: Task<Void, Never>?

    private var showStatsOverlay: Bool {
        !visiblePlayerIDs.isEmpty && flowPhase == .preparation
    }

    private var bossCameraExperienceAvailable: Bool {
        settings.qrScanCameraPosition.supportsARKitPreview
            || QRScanCameraDevice.captureDevice(for: settings.qrScanCameraPosition) != nil
    }

    private var canChooseBoss: Bool {
        flowPhase == .preparation
            && !bossSelectionStarted
            && (visiblePlayerIDs.contains(mainFighter.id) || !supporters.isEmpty)
    }

    var body: some View {
        ZStack {
            if bossCameraExperienceAvailable {
                GameplayARQRScanner(
                    cameraPosition: settings.qrScanCameraPosition,
                    onPayloads: handleScannedPayloads
                )
                .ignoresSafeArea()
            } else {
                AppGradientBackground()
                Text("AR nie jest dostępne na tym urządzeniu.")
                    .multilineTextAlignment(.center)
                    .padding()
            }

            VStack(spacing: 0) {
                topBar
                if flowPhase == .combat, let combatSession {
                    combatTurnBanner(combatSession)
                        .padding(.top, 8)
                }
                if showStatsOverlay {
                    statsOverlay
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if let combatSession {
                    combatOverlay(combatSession)
                } else {
                    statusBanner
                }
                bottomActions
            }
            .padding()
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showStatsOverlay)

            if let activePulse = combatIconPulse {
                BossFightCombatIconPulseView(pulse: activePulse) {
                    combatIconPulse = nil
                }
            }

            if let supportJoinPresentation {
                BossFightSupportJoinOverlay(presentation: supportJoinPresentation) {
                    self.supportJoinPresentation = nil
                }
            }
        }
        .appThemedScreen()
        .fullScreenCover(isPresented: $showBossSelection) {
            BossSelectionView(
                highlightedDifficulty: bossTrikiHighlightedDifficulty,
                trikiCancelHighlighted: bossTrikiHighlightedButtonID == "boss-cancel",
                trikiHoldChargeProgress: bossTrikiHoldChargeProgress,
                onSelect: { boss in
                    selectedBoss = boss
                    showBossSelection = false
                    statusMessage = "Boss wybrany: \(boss.difficulty.title). Naciśnij „Walka”."
                },
                onCancel: {
                    showBossSelection = false
                    bossSelectionStarted = false
                }
            )
        }
        .onDisappear {
            roundTask?.cancel()
        }
        .onChange(of: trikiCoordinator.motionGestureRevision) { _, _ in
            handleTrikiMotionGestureFromCoordinator()
        }
        .onChange(of: externalSelectedMove) { _, move in
            guard let move else { return }
            playerSelectedMove(move)
            externalSelectedMove = nil
        }
        .trikiFocusContext(
            id: bossARTrikiFocusID,
            buttons: bossARTrikiButtons,
            onActivate: { activateBossARTriki(at: $0) }
        )
    }

    private var bossTrikiHighlightedButtonID: String? {
        guard settings.trikiControllerEnabled,
              let index = trikiCoordinator.highlightIndex else { return nil }
        let buttons = bossARTrikiButtons
        guard buttons.indices.contains(index) else { return nil }
        return buttons[index].id
    }

    private var bossTrikiHoldChargeProgress: Double {
        trikiCoordinator.holdChargeProgress
    }

    private var bossTrikiHighlightedDifficulty: BossDifficulty? {
        guard let highlightedID = bossTrikiHighlightedButtonID,
              highlightedID.hasPrefix("boss-"),
              highlightedID != "boss-cancel" else { return nil }
        let raw = String(highlightedID.dropFirst("boss-".count))
        return BossDifficulty(rawValue: raw)
    }

    private var bossARTrikiButtons: [TrikiFocusButton] {
        if showBossSelection {
            var buttons = BossDifficulty.allCases.map { difficulty in
                TrikiFocusButton(
                    id: "boss-\(difficulty.rawValue)",
                    title: BossDefinition(difficulty: difficulty).difficulty.title
                )
            }
            buttons.append(TrikiFocusButton(id: "boss-cancel", title: "Anuluj"))
            return buttons
        }

        if flowPhase == .combat, let combatSession {
            var buttons: [TrikiFocusButton] = []
            if combatSession.isFinished {
                let title = combatSession.victory ? "Wygrana — wyjdź" : "Porażka — wyjdź"
                buttons.append(TrikiFocusButton(id: "finish-combat", title: title))
            } else if combatSession.playerMove == nil {
                for move in BossClashMove.playerSelectable {
                    buttons.append(TrikiFocusButton(id: "move-\(move.rawValue)", title: move.title))
                }
            }
            return buttons
        }

        var buttons: [TrikiFocusButton] = []
        if canChooseBoss {
            buttons.append(TrikiFocusButton(id: "select-boss", title: "Wybierz Bossa"))
        }
        if flowPhase == .preparation, selectedBoss != nil {
            buttons.append(TrikiFocusButton(id: "start-fight", title: "Walka"))
        }
        buttons.append(TrikiFocusButton(id: "exit-ar", title: "Wyjdź z AR"))
        return buttons
    }

    private func activateBossARTriki(at index: Int) {
        let buttons = bossARTrikiButtons
        guard buttons.indices.contains(index) else { return }
        settings.playTapSound()
        let button = buttons[index]
        switch button.id {
        case "select-boss":
            bossSelectionStarted = true
            showBossSelection = true
        case "start-fight":
            beginCombat()
        case "finish-combat":
            if let combatSession {
                finishCombat(combatSession)
            }
        case "boss-cancel":
            showBossSelection = false
            bossSelectionStarted = false
        case let id where id.hasPrefix("boss-"):
            let raw = String(id.dropFirst("boss-".count))
            if let difficulty = BossDifficulty(rawValue: raw) {
                let boss = BossDefinition(difficulty: difficulty)
                selectedBoss = boss
                showBossSelection = false
                statusMessage = "Boss wybrany: \(boss.difficulty.title). Naciśnij „Walka”."
            }
        case let id where id.hasPrefix("move-"):
            let raw = String(id.dropFirst("move-".count))
            if let move = BossClashMove(rawValue: raw) {
                playerSelectedMove(move)
            }
        case "exit-ar":
            roundTask?.cancel()
            onExit()
        default:
            break
        }
        trikiCoordinator.statusMessage = "Wciśnięto: \(button.title)"
    }

    private func handleTrikiMotionGestureFromCoordinator() {
        guard settings.trikiControllerEnabled,
              let kind = trikiCoordinator.lastMotionGesture else { return }
        // AR: wybór opcji tylko fizycznym przyciskiem.
        switch kind {
        case .bowRelease, .swordSwing:
            break
        default:
            break
        }
    }

    private func bossTrikiHighlightedMove(in session: BossCombatSession) -> BossClashMove? {
        guard session.playerMove == nil,
              let highlightedID = bossTrikiHighlightedButtonID,
              highlightedID.hasPrefix("move-") else { return nil }
        let raw = String(highlightedID.dropFirst("move-".count))
        return BossClashMove(rawValue: raw)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Walka z bossem — AR")
                    .font(.headline)
                Text(flowPhase == .combat ? "Atak · Obrona · Mocny atak (6 s)" : "Skan QR gracza (4001–4004) i wsparcie")
                    .font(.caption)
                    .foregroundStyle(settings.accentColor)
            }
            Spacer()
            Button {
                settings.playTapSound()
                roundTask?.cancel()
                onExit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func combatTurnBanner(_ session: BossCombatSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: session.isReacting ? "timer" : "flag.checkered.2.crossed")
                .font(.title3.bold())
                .foregroundStyle(settings.accentColor)
                .symbolEffect(.pulse, isActive: session.isReacting)

            VStack(alignment: .leading, spacing: 2) {
                Text("Runda \(session.roundNumber)")
                    .font(.subheadline.bold())
                Text(combatBannerSubtitle(session))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if session.bossSpecialAbility != nil {
                Label(
                    session.bossSpecialUsed ? "Zdolność zużyta" : "Boss ma zdolność",
                    systemImage: "sparkles"
                )
                .font(.caption2.bold())
                .foregroundStyle(session.bossSpecialUsed ? Color.secondary : Color.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func combatBannerSubtitle(_ session: BossCombatSession) -> String {
        switch session.phase {
        case .reacting:
            if session.playerMove != nil {
                return "Ruch zablokowany — czekaj na starcie"
            }
            return "Masz 6 sekund na wybór ruchu"
        case .revealing:
            return "Porównanie ruchów…"
        }
    }

    private var statsOverlay: some View {
        VStack(spacing: 8) {
            if !statsHeaderLabel.isEmpty {
                Text(statsHeaderLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !supporters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        partyChip(mainFighter.displayTitle, prominent: true)
                        ForEach(supporters) { supporter in
                            partyChip(supporter.displayTitle, prominent: false)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                BossFightStatCircle(label: "Zdrowie", value: displayStats.health, delta: statDeltas.health, color: .green)
                BossFightStatCircle(label: "Siła", value: displayStats.strength, delta: statDeltas.strength, color: .red)
                BossFightStatCircle(label: "Zdolności", value: displayStats.abilities, delta: 0, color: .blue)
                BossFightStatCircle(label: "Pancerz", value: displayStats.armor, delta: statDeltas.armor, color: .orange)
            }
            if visiblePlayersHaveEquippedGear {
                Label("Ekwipunek z gry", systemImage: "bag.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(settings.accentColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: displayStats)
    }

    private func partyChip(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                prominent ? settings.accentColor.opacity(0.28) : Color.white.opacity(0.1),
                in: Capsule()
            )
    }

    private var statusBanner: some View {
        Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 10) {
            if canChooseBoss {
                Button("Wybierz Bossa") {
                    settings.playTapSound()
                    bossSelectionStarted = true
                    showBossSelection = true
                }
                .buttonStyle(.appProminent)
                .trikiSelectableHighlight(
                    isSelected: bossTrikiHighlightedButtonID == "select-boss",
                    chargeProgress: bossTrikiHighlightedButtonID == "select-boss" ? bossTrikiHoldChargeProgress : 0
                )
            }

            if flowPhase == .preparation, selectedBoss != nil {
                Button("Walka") {
                    settings.playTapSound()
                    beginCombat()
                }
                .buttonStyle(.appProminent)
                .trikiSelectableHighlight(
                    isSelected: bossTrikiHighlightedButtonID == "start-fight",
                    chargeProgress: bossTrikiHighlightedButtonID == "start-fight" ? bossTrikiHoldChargeProgress : 0
                )
            }

            if let combatSession, combatSession.isFinished {
                Button(combatSession.victory ? "Wygrana — wyjdź" : "Porażka — wyjdź") {
                    settings.playTapSound()
                    finishCombat(combatSession)
                }
                .buttonStyle(.appProminent)
                .trikiSelectableHighlight(
                    isSelected: bossTrikiHighlightedButtonID == "finish-combat",
                    chargeProgress: bossTrikiHighlightedButtonID == "finish-combat" ? bossTrikiHoldChargeProgress : 0
                )
            }
        }
        .padding(.top, 8)
    }

    private func combatOverlay(_ session: BossCombatSession) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.boss.title)
                        .font(.headline.bold())
                    ProgressView(value: session.bossHPProgress)
                        .tint(.red)
                        .frame(height: 14)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(session.bossCurrentHP)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                        Text("/ \(session.boss.maxHP)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    Text("HP drużyny")
                        .font(.headline.bold())
                    ProgressView(value: session.playerHPProgress)
                        .tint(.green)
                        .frame(height: 14)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(session.playerCurrentHP)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                        Text("/ \(session.frozenStats.health)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if !supporters.isEmpty {
                Text("Walczy \(mainFighter.displayTitle) + \(supporters.count) wsparcie")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            BossFightClashCombatView(
                session: session,
                trikiHighlightedMove: bossTrikiHighlightedMove(in: session),
                trikiHoldChargeProgress: bossTrikiHoldChargeProgress,
                onSelectMove: { move in
                    playerSelectedMove(move)
                }
            )

            if let last = session.combatLog.last {
                Text(last)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func triggerCombatIconPulse(_ kind: BossFightCombatIconPulse.Kind) {
        combatIconPulse = BossFightCombatIconPulse(kind: kind)
    }

    // MARK: - Scan handling

    private func handleScannedPayloads(_ payloads: [String]) {
        let now = CACurrentMediaTime()

        updatePlayerPresence(from: payloads, now: now)

        for payload in payloads {
            if shouldDebounce(payload, now: now) { continue }
        }
    }

    private func updatePlayerPresence(from payloads: [String], now: TimeInterval) {
        let detectedIDs = Set(
            payloads.compactMap { ARPlayerScanMatcher.lobbyPlayer(for: $0, in: players)?.id }
        )

        playerPresenceTracker.update(
            allPlayerIDs: players.map(\.id),
            detected: detectedIDs,
            now: now
        ) { visible in
            visiblePlayerIDs = visible

            if visible.isEmpty {
                statusMessage = "Schowaj figurkę — statystyki ukryte. Pokaż QR, by je zobaczyć."
            } else {
                syncSupportersWithVisibility(from: visible, now: now)
                refreshVisibleStatsDisplay(animated: true)
            }
        }
    }

    private func syncSupportersWithVisibility(from visible: Set<UUID>, now: TimeInterval) {
        guard flowPhase == .preparation, !bossSelectionStarted else { return }
        tryRegisterSupporters(from: visible, now: now)
        tryRemoveSupporters(from: visible, now: now)
    }

    private func tryRegisterSupporters(from visible: Set<UUID>, now: TimeInterval) {
        for player in players where visible.contains(player.id) {
            guard player.id != mainFighter.id else { continue }
            guard !supporters.contains(where: { $0.id == player.id }) else { continue }

            if supporterCandidateSince[player.id] == nil {
                supporterCandidateSince[player.id] = now
            }

            if let since = supporterCandidateSince[player.id], now - since >= 0.35 {
                addSupporter(player)
                supporterCandidateSince.removeValue(forKey: player.id)
            }
        }

        for id in supporterCandidateSince.keys where !visible.contains(id) {
            supporterCandidateSince.removeValue(forKey: id)
        }
    }

    private func tryRemoveSupporters(from visible: Set<UUID>, now: TimeInterval) {
        for supporter in supporters {
            let id = supporter.id
            if visible.contains(id) {
                supporterRemovalCandidateSince.removeValue(forKey: id)
                continue
            }

            if supporterRemovalCandidateSince[id] == nil {
                supporterRemovalCandidateSince[id] = now
            }

            if let since = supporterRemovalCandidateSince[id], now - since >= 0.35 {
                removeSupporter(id: id)
                supporterRemovalCandidateSince.removeValue(forKey: id)
            }
        }

        for id in supporterRemovalCandidateSince.keys where !supporters.contains(where: { $0.id == id }) {
            supporterRemovalCandidateSince.removeValue(forKey: id)
        }
    }

    private func removeSupporter(id: UUID) {
        guard let index = supporters.firstIndex(where: { $0.id == id }) else { return }
        let removed = supporters.remove(at: index)
        refreshVisibleStatsDisplay(animated: true, updateStatusMessage: false)
        statusMessage = "\(removed.displayTitle) opuścił wsparcie. Statystyki zaktualizowane."
        settings.playTapSound()
    }

    private func addSupporter(_ player: PlayerCharacter) {
        guard !supporters.contains(where: { $0.id == player.id }) else { return }

        let before = partyCombatStats()
        supporters.append(player)
        let after = partyCombatStats()

        supportJoinPresentation = BossFightSupportJoinPresentation(
            playerName: player.displayTitle,
            addedHealth: after.health - before.health,
            addedStrength: after.strength - before.strength,
            addedArmor: after.armor - before.armor
        )

        refreshVisibleStatsDisplay(animated: true)
        statusMessage = "\(player.displayTitle) wspiera drużynę. Suma statystyk zaktualizowana."
        settings.playTapSound()
    }

    private func refreshVisibleStatsDisplay(animated: Bool, updateStatusMessage: Bool = true) {
        guard !visiblePlayerIDs.isEmpty else { return }

        let previous = displayStats
        let mainVisible = visiblePlayerIDs.contains(mainFighter.id)

        if mainVisible {
            if supporters.isEmpty {
                displaySoloStats(for: mainFighter, animated: animated)
            } else {
                displayPartyStats(animated: animated)
            }
        } else if let visibleSupporter = supporters.first(where: { visiblePlayerIDs.contains($0.id) }) {
            if supporters.filter({ visiblePlayerIDs.contains($0.id) }).count == 1 {
                displaySoloStats(for: visibleSupporter, animated: animated)
            } else {
                displayPartyStats(animated: animated)
            }
        }

        statDeltas = EquipmentLoadoutBonus(
            health: displayStats.health - previous.health,
            strength: displayStats.strength - previous.strength,
            armor: displayStats.armor - previous.armor
        )

        if updateStatusMessage, supporters.isEmpty, !bossSelectionStarted, mainVisible {
            statusMessage = "Skanuj QR wsparcia przed „Wybierz Bossa”, by zsumować statystyki."
        }
    }

    private func displayPartyStats(animated: Bool) {
        let stats = partyCombatStats()
        statsHeaderLabel = supporters.isEmpty
            ? mainFighter.displayTitle
            : "Drużyna: \(mainFighter.displayTitle) + \(supporters.count) wsparcie"
        applyDisplayStats(stats, animated: animated)
    }

    private func displaySoloStats(for player: PlayerCharacter, animated: Bool) {
        guard let base = playerStats[player.id] else { return }
        applyDisplayStats(bossDisplayStats(for: player.id, base: base), animated: animated)
        statsHeaderLabel = player.displayTitle
    }

    private func applyDisplayStats(_ stats: BossFightDisplayStats, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                displayStats = stats
            }
        } else {
            displayStats = stats
        }
    }

    private func partyCombatStats() -> BossFightDisplayStats {
        guard let mainBase = playerStats[mainFighter.id] else { return .zero }
        let mainDisplay = bossDisplayStats(for: mainFighter.id, base: mainBase)
        var total = mainDisplay
        for supporter in supporters {
            guard let base = playerStats[supporter.id] else { continue }
            let stats = bossDisplayStats(for: supporter.id, base: base)
            total.health += stats.health
            total.strength += stats.strength
            total.armor += stats.armor
            total.abilities = max(total.abilities, stats.abilities)
        }
        return total
    }

    private func bossDisplayStats(for playerID: UUID, base: PlayerRuntimeStats) -> BossFightDisplayStats {
        let effective = PlayerEquipment.effectiveRuntimeStats(
            base: base,
            for: playerID,
            equipment: playerEquippedItems,
            catalog: catalogItems
        )
        let bonus = equipmentBonus(for: playerID)
        return BossFightDisplayStats(
            health: effective.health,
            strength: effective.strength,
            abilities: effective.abilities,
            armor: min(100, bonus.armor)
        )
    }

    private func equipmentBonus(for playerID: UUID) -> EquipmentLoadoutBonus {
        PlayerEquipment.loadoutBonus(
            for: playerID,
            equipment: playerEquippedItems,
            catalog: catalogItems
        )
    }

    private var visiblePlayersHaveEquippedGear: Bool {
        var visibleIDs = visiblePlayerIDs
        if visibleIDs.isEmpty { return false }
        if visibleIDs.contains(mainFighter.id) {
            if equipmentBonus(for: mainFighter.id) != .zero { return true }
        }
        for supporter in supporters where visibleIDs.contains(supporter.id) {
            if equipmentBonus(for: supporter.id) != .zero { return true }
        }
        return false
    }

    private func shouldDebounce(_ payload: String, now: TimeInterval) -> Bool {
        let key = payload.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let last = lastScanAt[key], now - last < 0.55 { return true }
        lastScanAt[key] = now
        return false
    }

    // MARK: - Combat

    private func beginCombat() {
        guard let boss = selectedBoss else { return }

        let frozen = partyCombatStats()
        let special = pickBossSpecialAbility()
        var session = BossFightCombatEngine.makeSession(
            boss: boss,
            partyStats: frozen,
            bossSpecial: special
        )
        if !supporters.isEmpty {
            session.combatLog.insert(
                "Drużyna: \(1 + supporters.count) graczy (suma statystyk).",
                at: 0
            )
        }
        combatSession = session
        flowPhase = .combat
        statusMessage = ""
        scheduleRoundTimer()
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.75)
    }

    private func pickBossSpecialAbility() -> GameplaySessionAbility? {
        let candidates = sessionAbilityPool.abilities.filter {
            BossFightCombatEngine.isBossSpecialEligible($0)
        }
        return candidates.randomElement()
    }

    private func playerSelectedMove(_ move: BossClashMove) {
        guard var session = combatSession, session.isReacting else { return }
        BossFightCombatEngine.lockPlayerMove(move, session: &session)
        combatSession = session
        triggerCombatIconPulse(pulseKind(for: move))
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.55)
    }

    private func pulseKind(for move: BossClashMove) -> BossFightCombatIconPulse.Kind {
        switch move {
        case .attack, .strongAttack: .attackStrike
        case .defense: .defense
        case .specialAbility: .bossAttack
        }
    }

    private func scheduleRoundTimer() {
        roundTask?.cancel()
        roundTask = Task { @MainActor in
            while !Task.isCancelled {
                guard var session = combatSession, !session.isFinished else { return }

                if case .reacting(let endsAt) = session.phase {
                    if Date() >= endsAt {
                        await resolveCurrentRound(session: &session)
                        return
                    }
                } else if case .revealing = session.phase {
                    try? await Task.sleep(
                        for: .milliseconds(Int(BossCombatSession.revealDisplayDuration * 1000))
                    )
                    guard !Task.isCancelled else { return }
                    guard var next = combatSession, !next.isFinished else { return }
                    BossFightCombatEngine.beginRound(session: &next)
                    combatSession = next
                    scheduleRoundTimer()
                    return
                }

                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func resolveCurrentRound(session: inout BossCombatSession) async {
        let result = BossFightCombatEngine.resolveRound(session: &session)
        combatSession = session
        triggerCombatIconPulse(pulseKind(for: result.playerMove))
        if result.winner == .boss {
            try? await Task.sleep(for: .milliseconds(200))
            triggerCombatIconPulse(.bossAttack)
        }
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.85)
        settings.playTapSound()

        if session.isFinished {
            roundTask?.cancel()
            return
        }

        try? await Task.sleep(
            for: .milliseconds(Int(BossCombatSession.revealDisplayDuration * 1000))
        )
        guard !Task.isCancelled else { return }
        guard var next = combatSession, !next.isFinished else { return }
        BossFightCombatEngine.beginRound(session: &next)
        combatSession = next
        scheduleRoundTimer()
    }

    private func finishCombat(_ session: BossCombatSession) {
        let outcome = BossFightCombatOutcome(
            victory: session.victory,
            mainPlayerID: mainFighter.id,
            supporterIDs: supporters.map(\.id),
            mainPlayerFinalHealth: max(0, session.playerCurrentHP),
            bossDifficulty: session.boss.difficulty
        )
        roundTask?.cancel()
        onCombatFinished(outcome)
    }
}

// MARK: - Stat circle

private struct BossFightStatCircle: View {
    let label: String
    let value: Int
    let delta: Int
    let color: Color

    @State private var shownValue: Int

    init(label: String, value: Int, delta: Int, color: Color) {
        self.label = label
        self.value = value
        self.delta = delta
        self.color = color
        _shownValue = State(initialValue: value)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 3)
                    .frame(width: 48, height: 48)
                Text("\(shownValue)")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            if delta != 0 {
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.caption2.bold())
                    .foregroundStyle(delta > 0 ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: delta)
        .onAppear { shownValue = value }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                shownValue = newValue
            }
        }
    }
}

// MARK: - Presence trackers

private final class MultiPlayerPresenceTracker {
    private struct Slot {
        var presentSince: TimeInterval?
        var absentSince: TimeInterval?
        var isActive = false
    }

    private var slots: [UUID: Slot] = [:]

    func update(
        allPlayerIDs: [UUID],
        detected: Set<UUID>,
        now: TimeInterval,
        onChange: (Set<UUID>) -> Void
    ) {
        for id in allPlayerIDs {
            if slots[id] == nil { slots[id] = Slot() }
        }

        var visible = Set<UUID>()

        for id in allPlayerIDs {
            guard var slot = slots[id] else { continue }

            if detected.contains(id) {
                slot.absentSince = nil
                if slot.presentSince == nil { slot.presentSince = now }
                if !slot.isActive, let presentSince = slot.presentSince, now - presentSince >= 0.22 {
                    slot.isActive = true
                }
            } else {
                slot.presentSince = nil
                if slot.absentSince == nil { slot.absentSince = now }
                if slot.isActive, let absentSince = slot.absentSince, now - absentSince >= 0.4 {
                    slot.isActive = false
                }
            }

            slots[id] = slot
            if slot.isActive { visible.insert(id) }
        }

        onChange(visible)
    }
}
