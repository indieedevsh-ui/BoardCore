//
//  ArenaPvPARView.swift
//  BoardCore
//

import SwiftUI

struct ArenaPvPARView: View {
    @Environment(AppSettings.self) private var settings

    let players: [PlayerCharacter]
    let playerStats: [UUID: PlayerRuntimeStats]
    let playerExperiencePoints: [UUID: Int]
    let playerEquippedItems: PlayerEquipmentMap
    let catalogItems: [CreatedItem]
    @Binding var sessionAbilityPool: GameplaySessionAbilityPoolState
    let onAbilityConsumed: (UUID, UUID) -> Void
    let onSettled: (ArenaPvPOutcome) -> Void
    let onExit: () -> Void

    @State private var flowPhase: ArenaPvPFlowPhase = .scanning
    @State private var registeredFighters: [ArenaPvPFighter] = []
    @State private var combatState: ArenaPvPCombatState?
    @State private var statusMessage = "Skanuj QR pierwszego gracza (4001–4004)."
    @State private var fighterReveal: ArenaPvPFighterReveal?
    @State private var lastScanAt: [String: TimeInterval] = [:]
    @State private var loopTask: Task<Void, Never>?
    @State private var settlementOutcome: ArenaPvPOutcome?
    @State private var victoryPresentation: BossFightVictoryPresentation?
    @State private var showStrikeAbilityPicker = false

    private var cameraAvailable: Bool {
        settings.qrScanCameraPosition.supportsARKitPreview
            || QRScanCameraDevice.captureDevice(for: settings.qrScanCameraPosition) != nil
    }

    private var canStartFight: Bool {
        flowPhase == .scanning && registeredFighters.count >= 2
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                if flowPhase == .scanning {
                    ScrollView {
                        VStack(spacing: 12) {
                            if registeredFighters.isEmpty {
                                Text("Wskaż QR gracza w kamerze — pojawi się kafelek ze statystykami.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            } else {
                                ForEach(Array(registeredFighters.enumerated()), id: \.element.id) { index, fighter in
                                    ArenaPvPFighterCard(
                                        fighter: fighter,
                                        slotNumber: index + 1,
                                        finances: playerStats[fighter.id]?.finances ?? 0,
                                        accent: settings.accentColor
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: 280)
                }

                Spacer()

                if flowPhase == .combat, let combatState {
                    ArenaPvPCombatOverlay(
                        state: combatState,
                        settings: settings,
                        arenaAbilities: ArenaPvPCombatEngine.arenaAbilities(
                            for: combatState.activeFighter.id,
                            in: sessionAbilityPool
                        ),
                        onTapBall: { id in
                            var updated = combatState
                            ArenaPvPCombatEngine.tapBall(state: &updated, ballID: id)
                            self.combatState = updated
                            settings.playTapSound()
                        },
                        onUseStrikeAbility: {
                            settings.playTapSound()
                            showStrikeAbilityPicker = true
                        },
                        onSkipStrikeAbility: {
                            settings.playTapSound()
                            skipStrikeAbilityUse()
                        }
                    )
                } else if flowPhase == .scanning {
                    statusBanner
                }

                bottomBar
            }
            .padding()

            if let fighterReveal {
                ArenaPvPFighterRevealOverlay(presentation: fighterReveal) {
                    self.fighterReveal = nil
                }
            }

            if showStrikeAbilityPicker, let state = combatState {
                ArenaPvPStrikeAbilityPickerOverlay(
                    abilities: ArenaPvPCombatEngine.arenaAbilities(
                        for: state.activeFighter.id,
                        in: sessionAbilityPool
                    ),
                    accent: settings.accentColor,
                    onConfirm: { ability in
                        confirmStrikeAbility(ability)
                    },
                    onBack: {
                        settings.playTapSound()
                        showStrikeAbilityPicker = false
                    }
                )
            }

            if let victoryPresentation {
                BossFightVictoryRewardOverlay(presentation: victoryPresentation) {
                    if let outcome = settlementOutcome {
                        onSettled(outcome)
                    }
                    onExit()
                }
            }
        }
        .appThemedScreen()
        .onAppear {
            startLoop()
        }
        .onDisappear {
            loopTask?.cancel()
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if flowPhase == .scanning, cameraAvailable {
            GameplayARQRScanner(
                cameraPosition: settings.qrScanCameraPosition,
                onPayloads: handleScannedPayloads
            )
            .ignoresSafeArea()
        } else {
            ZStack {
                AppGradientBackground()
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        settings.accentColor.opacity(0.12),
                        Color.black.opacity(0.7),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                Image(systemName: "figure.boxing")
                    .font(.system(size: 160, weight: .bold))
                    .foregroundStyle(.white.opacity(0.04))
                    .offset(y: 40)
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Arena PvP")
                    .font(.headline)
                Text(topBarSubtitle)
                    .font(.caption)
                    .foregroundStyle(settings.accentColor)
            }
            Spacer()
            if flowPhase != .settlement {
                Button {
                    settings.playTapSound()
                    loopTask?.cancel()
                    onExit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var topBarSubtitle: String {
        switch flowPhase {
        case .scanning:
            "Skan AR · \(registeredFighters.count)/2"
        case .combat:
            "Walka"
        case .settlement:
            "Podsumowanie"
        }
    }

    private var statusBanner: some View {
        Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if canStartFight {
                Button("Walcz") {
                    settings.playTapSound()
                    beginFight()
                }
                .buttonStyle(.appProminent)
            }

            if flowPhase == .combat, let combatState, combatState.isFinished {
                Button("Zakończ") {
                    settings.playTapSound()
                    beginSettlement()
                }
                .buttonStyle(.appProminent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Scan

    private func handleScannedPayloads(_ payloads: [String]) {
        guard flowPhase == .scanning else { return }
        let now = CACurrentMediaTime()

        for payload in payloads {
            if shouldDebounce(payload, now: now) { continue }
            guard let player = ARPlayerScanMatcher.player(for: payload, in: players) else { continue }
            registerPlayerIfNeeded(player)
        }
    }

    private func registerPlayerIfNeeded(_ player: PlayerCharacter) {
        guard registeredFighters.count < 2 else { return }
        guard !registeredFighters.contains(where: { $0.id == player.id }) else { return }
        guard let base = playerStats[player.id] else { return }

        let fighter = ArenaPvPFighter.make(
            player: player,
            baseStats: base,
            equipment: playerEquippedItems,
            catalog: catalogItems
        )

        withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
            registeredFighters.append(fighter)
        }

        let slot = registeredFighters.count
        fighterReveal = ArenaPvPFighterReveal(
            fighter: fighter,
            slotLabel: slot == 1 ? "Pierwszy zawodnik" : "Drugi zawodnik"
        )

        settings.playTapSound()
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.75)

        if registeredFighters.count == 1 {
            statusMessage = "Gracz 1 zarejestrowany. Zeskanuj drugiego — kafelek pojawi się niżej."
        } else {
            statusMessage = "Obaj gotowi. Naciśnij „Walcz”."
        }
    }

    private func shouldDebounce(_ payload: String, now: TimeInterval) -> Bool {
        let key = payload.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let last = lastScanAt[key], now - last < 0.55 { return true }
        lastScanAt[key] = now
        return false
    }

    // MARK: - Combat

    private func beginFight() {
        guard registeredFighters.count >= 2 else { return }
        flowPhase = .combat
        combatState = ArenaPvPCombatEngine.makeCombat(fighters: registeredFighters)
        statusMessage = "\(combatState!.activeFighter.player.displayTitle) zaczyna — tapaj kuleczki!"
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.8)
    }

    private func beginSettlement() {
        guard let state = combatState,
              let winnerID = state.winnerID,
              let loser = state.fighters.first(where: { $0.id != winnerID }),
              let winnerStats = playerStats[winnerID],
              let loserStats = playerStats[loser.id] else { return }

        let loserFinances = loserStats.finances
        let loserXP = playerExperiencePoints[loser.id] ?? 0
        let transfer = max(0, loserFinances / 2)
        let xpTransfer = max(0, loserXP / 2)

        settlementOutcome = ArenaPvPOutcome(
            winnerID: winnerID,
            loserID: loser.id,
            transferAmount: transfer,
            xpTransfer: xpTransfer
        )

        let winnerPlayer = state.fighters.first { $0.id == winnerID }?.player
        let loserPlayer = loser.player

        var steps: [BossFightVictoryRewardStep] = [
            BossFightVictoryRewardStep(
                id: UUID(),
                playerID: winnerID,
                playerName: winnerPlayer?.displayTitle ?? "Gracz",
                roleLabel: "Zwycięzca areny",
                lobbySlotNumber: winnerPlayer?.lobbySlotNumber,
                characterQRCode: winnerPlayer?.qrCode,
                financesBefore: winnerStats.finances,
                rewardAmount: transfer,
                rewardPercentLabel: "50% funduszy przegranego",
                xpBefore: playerExperiencePoints[winnerID] ?? 0,
                rewardXP: xpTransfer,
                headline: "Arena PvP",
                isPenalty: false
            ),
            BossFightVictoryRewardStep(
                id: UUID(),
                playerID: loser.id,
                playerName: loserPlayer.displayTitle,
                roleLabel: "Przegrany",
                lobbySlotNumber: loserPlayer.lobbySlotNumber,
                characterQRCode: loserPlayer.qrCode,
                financesBefore: loserStats.finances,
                rewardAmount: transfer,
                rewardPercentLabel: "50% funduszy",
                xpBefore: loserXP,
                rewardXP: xpTransfer,
                headline: "Arena PvP",
                isPenalty: true
            ),
        ]

        victoryPresentation = BossFightVictoryPresentation(arenaSteps: steps)
        flowPhase = .settlement
        loopTask?.cancel()
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            let step: TimeInterval = 1.0 / 30.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(step))
                guard !Task.isCancelled else { break }
                tickCombat()
            }
        }
    }

    private func tickCombat() {
        guard var state = combatState, flowPhase == .combat else { return }
        let now = Date()

        let arenaAbilityCount = ArenaPvPCombatEngine.arenaAbilities(
            for: state.activeFighter.id,
            in: sessionAbilityPool
        ).count
        ArenaPvPCombatEngine.advanceStepIfNeeded(
            state: &state,
            now: now,
            arenaAbilityCountForActiveFighter: arenaAbilityCount
        )

        switch state.step {
        case .ballTapping:
            statusMessage = "\(state.activeFighter.player.displayTitle): zielone +5%, czerwone −10% — \(remainingSeconds(state)) s"
        case .strikePowerReveal:
            statusMessage = "Twoja moc uderzenia: \(state.punchPowerPercent)%"
        case .damageReveal:
            statusMessage = "Siła uderzenia…"
        case .energyDrain:
            statusMessage = "Odejmowanie energii…"
        }

        combatState = state
    }

    private func remainingSeconds(_ state: ArenaPvPCombatState) -> Int {
        let end: Date
        switch state.step {
        case .ballTapping(let endsAt): end = endsAt
        case .strikePowerReveal(let endsAt, _): end = endsAt
        case .damageReveal(let endsAt, _, _): end = endsAt
        case .energyDrain(let endsAt, _, _, _): end = endsAt
        }
        return max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    private func skipStrikeAbilityUse() {
        guard var state = combatState else { return }
        ArenaPvPCombatEngine.skipStrikeAbilityUse(state: &state, now: Date())
        showStrikeAbilityPicker = false
        combatState = state
    }

    private func confirmStrikeAbility(_ ability: GameplaySessionAbility) {
        guard var state = combatState else { return }
        let playerID = state.activeFighter.id
        ArenaPvPCombatEngine.confirmStrikeAbility(state: &state, ability: ability, now: Date())
        sessionAbilityPool.consume(abilityID: ability.id, from: playerID)
        onAbilityConsumed(playerID, ability.id)
        showStrikeAbilityPicker = false
        combatState = state
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.8)
    }
}

// MARK: - Fighter card (scanning)

private struct ArenaPvPFighterCard: View {
    let fighter: ArenaPvPFighter
    let slotNumber: Int
    let finances: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 40, height: 40)
                    Text("\(slotNumber)")
                        .font(.headline.bold())
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fighter.player.displayTitle)
                        .font(.subheadline.bold())
                    Text(fighter.player.factionName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(finances)", systemImage: "dollarsign.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                    Text("monety")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statTile("Zdrowie", value: fighter.displayStats.health, icon: "heart.fill", color: .green)
                statTile("Siła", value: fighter.displayStats.strength, icon: "bolt.fill", color: .red)
                statTile("Zdolności", value: fighter.displayStats.abilities, icon: "sparkles", color: .blue)
                statTile("Pancerz", value: fighter.displayStats.armor, icon: "shield.lefthalf.filled", color: .orange)
            }

            HStack(spacing: 6) {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(accent)
                Text("Energia w walce: \(fighter.maxEnergy)")
                    .font(.caption.bold())
                Text("(HP × 2,5)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: accent.opacity(0.15), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.7), accent.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func statTile(_ label: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Energy bar

private struct ArenaPvPEnergyBar: View {
    let current: Int
    let maxEnergy: Int
    let isActive: Bool
    let isDraining: Bool
    let accent: Color

    private var progress: CGFloat {
        guard maxEnergy > 0 else { return 0 }
        return CGFloat(min(maxEnergy, Swift.max(0, current))) / CGFloat(maxEnergy)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: barColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, width * progress))
                    .shadow(color: glowColor.opacity(isActive || isDraining ? 0.55 : 0.2), radius: isDraining ? 8 : 4)

                if isActive || isDraining {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                        .frame(width: max(4, width * progress))
                }
            }
        }
        .frame(height: 14)
        .animation(.easeInOut(duration: 0.12), value: current)
    }

    private var barColors: [Color] {
        if isDraining {
            return [Color.orange, Color.red.opacity(0.85)]
        }
        if isActive {
            return [accent, accent.opacity(0.55), Color.cyan.opacity(0.75)]
        }
        return [Color.gray.opacity(0.55), Color.gray.opacity(0.35)]
    }

    private var glowColor: Color {
        isDraining ? .orange : (isActive ? accent : .gray)
    }
}

// MARK: - Strike animations

private struct ArenaPvPDamageRevealPanel: View {
    let attackerName: String
    let defenderName: String
    let damage: Int
    let strikePowerPercent: Int
    var usedAbilityName: String? = nil
    let accent: Color

    @State private var shownDamage = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.orange)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .symbolEffect(.pulse, isActive: pulse)

            Text(attackerName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("\(shownDamage)")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("obrażeń")
                .font(.title3.bold())

            VStack(spacing: 4) {
                Text("Moc uderzenia: \(strikePowerPercent)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                if let usedAbilityName {
                    Text("Zdolność: \(usedAbilityName)")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                Text("cel: \(defenderName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
        .onAppear {
            pulse = true
            animateDamage()
        }
        .onDisappear { pulse = false }
    }

    private func animateDamage() {
        guard damage > 0 else { return }
        let ticks = min(damage, 40)
        let step = max(1, damage / ticks)
        shownDamage = 0
        Task { @MainActor in
            var value = 0
            while value < damage {
                try? await Task.sleep(for: .milliseconds(32))
                value = min(damage, value + step)
                shownDamage = value
            }
            shownDamage = damage
        }
    }
}

private struct ArenaPvPEnergyDrainPanel: View {
    let defenderName: String
    let damage: Int
    let energyBefore: Int
    let energyAfter: Int
    let accent: Color

    @State private var floatOffset: CGFloat = 12
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(defenderName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("−\(damage)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.red)
                Text("energii")
                    .font(.headline.bold())
                    .foregroundStyle(.red.opacity(0.9))
            }
            .offset(y: floatOffset)
            .opacity(opacity)

            HStack(spacing: 6) {
                Text("\(energyBefore)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(energyAfter)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                floatOffset = 0
                opacity = 1
            }
        }
    }
}

// MARK: - Combat overlay

private struct ArenaPvPCombatOverlay: View {
    let state: ArenaPvPCombatState
    let settings: AppSettings
    let arenaAbilities: [GameplaySessionAbility]
    let onTapBall: (UUID) -> Void
    let onUseStrikeAbility: () -> Void
    let onSkipStrikeAbility: () -> Void

    private var strikeAbilityWindowOpen: Bool {
        if case .strikePowerReveal(_, let open) = state.step {
            return open
        }
        return false
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date
            VStack(spacing: 12) {
                energyRow(
                    fighter: state.fighters[0],
                    index: 0,
                    active: state.activeFighterIndex == 0,
                    now: now
                )
                energyRow(
                    fighter: state.fighters[1],
                    index: 1,
                    active: state.activeFighterIndex == 1,
                    now: now
                )

                switch state.step {
                case .ballTapping:
                    ballField
                    HStack {
                        Label("Moc uderzenia: \(state.ballPowerPercent)%", systemImage: "circle.fill")
                        Spacer()
                        Text("🟢 +5%   🔴 −10%")
                            .font(.caption2.bold())
                    }
                    .font(.caption.bold())
                case .strikePowerReveal:
                    strikePowerRevealSection
                case .damageReveal(_, let damage, _):
                    ArenaPvPDamageRevealPanel(
                        attackerName: state.activeFighter.player.displayTitle,
                        defenderName: state.defender.player.displayTitle,
                        damage: damage,
                        strikePowerPercent: state.punchPowerPercent,
                        usedAbilityName: state.strikeAbilityBonus?.abilityName,
                        accent: settings.accentColor
                    )
                case .energyDrain(_, let defenderIndex, let before, let after):
                    ArenaPvPEnergyDrainPanel(
                        defenderName: state.fighters[defenderIndex].player.displayTitle,
                        damage: state.lastDamage,
                        energyBefore: before,
                        energyAfter: after,
                        accent: settings.accentColor
                    )
                }

                if state.winnerID != nil {
                    Text("Koniec walki")
                        .font(.headline)
                        .foregroundStyle(settings.accentColor)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func energyRow(
        fighter: ArenaPvPFighter,
        index: Int,
        active: Bool,
        now: Date
    ) -> some View {
        let displayed = ArenaPvPCombatEngine.displayedEnergy(
            for: index,
            fighter: fighter,
            step: state.step,
            now: now
        )
        let isDrainTarget: Bool = {
            if case .energyDrain(_, let defenderIndex, _, _) = state.step {
                return index == defenderIndex
            }
            return false
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(fighter.player.displayTitle)
                    .font(.caption.bold())
                if active {
                    Text("TURA")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(settings.accentColor.opacity(0.35), in: Capsule())
                }
                Spacer()
                Text("\(displayed)/\(fighter.maxEnergy)")
                    .font(.caption.monospacedDigit())
                    .contentTransition(.numericText())
            }

            ArenaPvPEnergyBar(
                current: displayed,
                maxEnergy: fighter.maxEnergy,
                isActive: active,
                isDraining: isDrainTarget,
                accent: settings.accentColor
            )
        }
    }

    private var ballField: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.35))
                ForEach(state.activeBalls) { ball in
                    Button {
                        onTapBall(ball.id)
                    } label: {
                        ballView(ball)
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: CGFloat(ball.normalizedX) * geo.size.width,
                        y: CGFloat(ball.normalizedY) * geo.size.height
                    )
                }
            }
        }
        .frame(height: 220)
    }

    @ViewBuilder
    private func ballView(_ ball: ArenaPvPTapBall) -> some View {
        let isPenalty = ball.kind == .penalty
        Circle()
            .fill(
                RadialGradient(
                    colors: isPenalty
                        ? [Color.red, Color.red.opacity(0.45)]
                        : [settings.accentColor, settings.accentColor.opacity(0.45)],
                    center: .center,
                    startRadius: 2,
                    endRadius: 22
                )
            )
            .frame(width: 44, height: 44)
            .overlay {
                if isPenalty {
                    Image(systemName: "minus")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: (isPenalty ? Color.red : settings.accentColor).opacity(0.55), radius: 6)
    }

    private var strikePowerRevealSection: some View {
        VStack(spacing: 10) {
            if strikeAbilityWindowOpen, !arenaAbilities.isEmpty {
                Button(action: onUseStrikeAbility) {
                    Label("Użyj Zdolności", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.appProminent)
            }

            strikePowerRevealPanel

            if strikeAbilityWindowOpen, !arenaAbilities.isEmpty {
                Button("Anuluj", action: onSkipStrikeAbility)
                    .buttonStyle(.appSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var strikePowerRevealPanel: some View {
        VStack(spacing: 12) {
            Text("Twoja Moc Uderzenia")
                .font(.headline.bold())
            Text("\(state.punchPowerPercent)%")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.orange)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.orange.opacity(0.35), lineWidth: 1.5)
        )
    }
}

// MARK: - Strike ability picker

private struct ArenaPvPStrikeAbilityPickerOverlay: View {
    @Environment(AppSettings.self) private var settings

    let abilities: [GameplaySessionAbility]
    let accent: Color
    let onConfirm: (GameplaySessionAbility) -> Void
    let onBack: () -> Void

    @State private var previewAbility: GameplaySessionAbility?
    @State private var selectedAbilityID: UUID?

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Użyj Zdolności")
                    .font(.title2.bold())
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                Text("Przytrzymaj, aby wybrać · jedna na turę")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 88), spacing: 12)],
                        spacing: 14
                    ) {
                        ForEach(abilities) { ability in
                            abilityCell(ability)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    guard let selectedAbilityID,
                          let ability = abilities.first(where: { $0.id == selectedAbilityID }) else { return }
                    settings.playTapSound()
                    onConfirm(ability)
                } label: {
                    Text("Potwierdź")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.appProminent)
                .disabled(selectedAbilityID == nil)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Button("Wróć", action: onBack)
                    .buttonStyle(.appSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)

            if let previewAbility {
                abilityDetailCard(previewAbility)
            }
        }
    }

    private func abilityCell(_ ability: GameplaySessionAbility) -> some View {
        let isSelected = selectedAbilityID == ability.id

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isSelected
                                ? [Color.green.opacity(0.75), Color.green.opacity(0.35)]
                                : [accent.opacity(0.6), accent.opacity(0.22)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 34
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? Color.green : .white.opacity(0.25), lineWidth: isSelected ? 3 : 1.5)
                    }

                Image(systemName: abilityIcon(for: ability))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(ability.name)
                .font(.caption2.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.green.opacity(0.14) : Color.white.opacity(0.04))
        )
        .onTapGesture {
            settings.playTapSound()
            previewAbility = ability
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            settings.playTapSound()
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.7)
            selectedAbilityID = ability.id
            previewAbility = ability
        }
    }

    private func abilityDetailCard(_ ability: GameplaySessionAbility) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    settings.playTapSound()
                    previewAbility = nil
                }

            VStack(spacing: 14) {
                Text(ability.name)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Super umiejętność")
                    .font(.caption.bold())
                    .foregroundStyle(accent)

                Text(ability.effectDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Zamknij") {
                    settings.playTapSound()
                    previewAbility = nil
                }
                .buttonStyle(.appSecondary)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24)
        }
    }

    private func abilityIcon(for ability: GameplaySessionAbility) -> String {
        switch ability.kind {
        case .turnDamage: "bolt.fill"
        case .temporaryStatBoost: "heart.fill"
        case .boardMove: "sparkles"
        }
    }
}

// MARK: - Scan reveal

private struct ArenaPvPFighterRevealOverlay: View {
    @Environment(AppSettings.self) private var settings

    let presentation: ArenaPvPFighterReveal
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.opacity(0.38 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "figure.boxing")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(settings.accentColor)

                Text(presentation.slotLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(presentation.fighter.player.displayTitle)
                    .font(.title2.bold())

                HStack(spacing: 10) {
                    statPill("❤️ \(presentation.fighter.displayStats.health)", .green)
                    statPill("⚔️ \(presentation.fighter.displayStats.strength)", .red)
                    statPill("⚡ \(presentation.fighter.maxEnergy)", settings.accentColor)
                }
            }
            .padding(24)
            .opacity(contentOpacity)
        }
        .allowsHitTesting(false)
        .onAppear { runAnimation() }
        .onDisappear { dismissTask?.cancel() }
    }

    private func statPill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.2), in: Capsule())
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: 0.25)) { backdropOpacity = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.8)
            SoundManager.playStatsRevealStep(volume: settings.volume)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                contentOpacity = 1
            }
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(1.6))
                onComplete()
            }
        }
    }
}
