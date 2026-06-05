//
//  PowerPathFullScreenView.swift
//  BoardCore
//

import SwiftUI

private enum PowerPathTabAnimation {
    /// Przejścia: wybór ścieżki ↔ Mrok/Światło (szybsze niż reszta ekranu).
    static let duration: Double = 0.42
    static var ease: Animation { .easeInOut(duration: duration) }
}

struct PowerPathFullScreenView: View {
    @Environment(AppSettings.self) private var settings

    let playerName: String
    let visitCount: Int
    @Binding var progress: PlayerPowerPathProgress
    var powerPaths: [CreatedPowerPath] = []
    let opponents: [PlayerCharacter]
    let onUnlockPath: (PowerPathSide) -> String?
    let onUnlockSkill: (PowerPathSkillID) -> String?
    var onUnlockCustomPath: ((UUID) -> String?)?
    var onUnlockCustomUpgrade: ((UUID, UUID) -> String?)?
    let onCurseTarget: (UUID) -> String?
    let onExit: () -> Void
    @Binding var trikiCatalog: [PowerPathTrikiRow]
    @Binding var trikiActivationTrigger: Int
    var trikiHighlightIndex: Int? = nil
    var trikiHoldChargeProgress: Double = 0

    @State private var browsingSide: PowerPathSide?
    @State private var browsingCustomPathID: UUID?
    @State private var feedbackMessage = ""
    @State private var showCursePicker = false
    @State private var skillUnlockReveal: PowerPathSkillUnlockReveal?
    @State private var customUpgradeReveal: PowerPathCustomUpgradeReveal?

    private var customPaths: [CreatedPowerPath] {
        powerPaths.filter { !$0.isBuiltIn }
    }

    private var activeCustomPath: CreatedPowerPath? {
        if let id = progress.chosenCustomPathID ?? browsingCustomPathID {
            return powerPaths.first { $0.id == id }
        }
        return nil
    }

    private var auraSide: PowerPathSide? {
        guard activeCustomPath == nil else { return nil }
        return progress.chosenSide ?? browsingSide
    }

    var body: some View {
        ZStack {
            PowerPathAuraBackground(
                side: auraSide,
                customGlow: activeCustomPath?.glowColor
            )

            VStack(spacing: 0) {
                if let customID = progress.chosenCustomPathID,
                   let path = powerPaths.first(where: { $0.id == customID }) {
                    customPathDetail(path: path, showBack: false)
                } else if let browseID = browsingCustomPathID,
                          let path = powerPaths.first(where: { $0.id == browseID }) {
                    customPathDetail(path: path, showBack: true)
                } else if progress.hasChosenPath, let side = progress.chosenSide {
                    pathDetailScreen(side: side, showBack: false)
                } else if let side = browsingSide {
                    pathDetailScreen(side: side, showBack: true)
                } else {
                    pathSelectionScreen
                }
            }

            if let reveal = skillUnlockReveal {
                PowerPathSkillUnlockOverlay(
                    skill: reveal.skill,
                    side: reveal.side,
                    detailMessage: reveal.message,
                    onDismiss: { skillUnlockReveal = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }

            if let reveal = customUpgradeReveal {
                PowerPathCustomUpgradeUnlockOverlay(
                    path: reveal.path,
                    upgrade: reveal.upgrade,
                    detailMessage: reveal.message,
                    onDismiss: { customUpgradeReveal = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: skillUnlockReveal != nil)
        .animation(.easeInOut(duration: 0.4), value: customUpgradeReveal != nil)
        .animation(PowerPathTabAnimation.ease, value: auraSide)
        .animation(PowerPathTabAnimation.ease, value: activeCustomPath?.id)
        .onAppear {
            progress.reconcileChosenSideFromSkills()
            if let chosen = progress.chosenSide {
                browsingSide = chosen
            }
            if let customID = progress.chosenCustomPathID {
                browsingCustomPathID = customID
            }
            rebuildTrikiCatalog()
        }
        .onChange(of: trikiScreenFingerprint) { _, _ in
            rebuildTrikiCatalog()
        }
        .onChange(of: trikiActivationTrigger) { _, _ in
            guard trikiActivationTrigger > 0 else { return }
            let index = min(max(trikiHighlightIndex ?? 0, 0), max(trikiCatalog.count - 1, 0))
            activateTrikiRow(at: index)
        }
        .confirmationDialog(
            "Klątwa — wybierz cel",
            isPresented: $showCursePicker,
            titleVisibility: .visible
        ) {
            ForEach(opponents) { opponent in
                Button(opponent.displayTitle) {
                    if let message = onCurseTarget(opponent.id) {
                        feedbackMessage = message
                    }
                }
            }
            Button("Anuluj", role: .cancel) {}
        }
    }

    // MARK: - Wybór ścieżki (dwa duże kafelki)

    private var pathSelectionScreen: some View {
        VStack(spacing: 0) {
            selectionHeader

            VStack(spacing: 16) {
                ForEach(Array(trikiCatalog.enumerated()), id: \.element.id) { index, row in
                    trikiCatalogRow(row, catalogIndex: index)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 0)

            continueButton
        }
    }

    private var selectionHeader: some View {
        VStack(spacing: 8) {
            Text("Ścieżka Mocy")
                .font(.largeTitle.bold())
            Text(playerName)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Wybierz jedną ścieżkę — nie można zmienić później")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            xpChip
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private func pathChoiceTile(_ side: PowerPathSide, trikiRowIndex: Int?) -> some View {
        let isTrikiSelected = trikiRowIndex.map { trikiHighlightIndex == $0 } ?? false
        return Button {
            settings.playTapSound()
            withAnimation(PowerPathTabAnimation.ease) {
                browsingSide = side
            }
            feedbackMessage = ""
        } label: {
            VStack(spacing: 12) {
                Image(systemName: side.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(side.auraAccent)
                Text(side.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(side.magicKindTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(side == .dark ? Color.purple.opacity(0.22) : Color.yellow.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(side.auraAccent.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: side.auraAccent.opacity(0.35), radius: 16, y: 4)
        }
        .buttonStyle(.plain)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
    }

    // MARK: - Zakładka wybranej ścieżki

    private func trikiCatalogIndex(matching target: PowerPathTrikiTarget) -> Int? {
        trikiCatalog.firstIndex(where: { $0.target == target })
    }

    private func trikiIsHighlighted(catalogIndex: Int?) -> Bool {
        guard let catalogIndex, let trikiHighlightIndex else { return false }
        return catalogIndex == trikiHighlightIndex
    }

    private func pathDetailScreen(side: PowerPathSide, showBack: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                if showBack {
                    let backIndex = trikiCatalogIndex(matching: .back)
                    Button {
                        settings.playTapSound()
                        withAnimation(PowerPathTabAnimation.ease) {
                            browsingSide = nil
                        }
                        feedbackMessage = ""
                    } label: {
                        Label("Wróć", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .trikiSelectableHighlight(
                        isSelected: trikiIsHighlighted(catalogIndex: backIndex),
                        chargeProgress: trikiIsHighlighted(catalogIndex: backIndex) ? trikiHoldChargeProgress : 0
                    )
                }
                Spacer()
                xpChip
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: side.icon)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(side.auraAccent)
                            .shadow(color: side.auraAccent.opacity(0.55), radius: 12)
                        Text(side.magicKindTitle)
                            .font(.title.bold())
                            .foregroundStyle(side.auraAccent)
                        Text(side.title)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    if !progress.hasChosenPath || progress.chosenSide != side {
                        unlockPathButton(for: side)
                    } else {
                        Label("Ścieżka aktywna", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 12) {
                        ForEach(PowerPathSkillID.skills(for: side)) { skill in
                            skillTile(skill, side: side)
                        }
                    }

                    if !feedbackMessage.isEmpty, skillUnlockReveal == nil {
                        Text(feedbackMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            continueButton
        }
    }

    private func unlockPathButton(for side: PowerPathSide) -> some View {
        let unlockIndex = trikiCatalogIndex(matching: .unlockSide(side))
        return Button {
            settings.playTapSound()
            if let message = onUnlockPath(side) {
                feedbackMessage = message
                if progress.chosenSide == side {
                    browsingSide = side
                    HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.7)
                }
            }
        } label: {
            Text("Odblokuj")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.appProminent)
        .tint(side.auraAccent)
        .padding(.horizontal, 4)
        .shadow(color: side.auraAccent.opacity(0.4), radius: 12, y: 4)
        .trikiSelectableHighlight(
            isSelected: trikiIsHighlighted(catalogIndex: unlockIndex),
            chargeProgress: trikiIsHighlighted(catalogIndex: unlockIndex) ? trikiHoldChargeProgress : 0
        )
    }

    private func skillTile(_ skill: PowerPathSkillID, side: PowerPathSide) -> some View {
        let pathActive = progress.chosenSide == side
        let unlocked = progress.hasUnlocked(skill)
        let canBuy = pathActive && progress.canUnlock(skill)
        let skillIndex = trikiCatalogIndex(matching: .unlockSkill(skill, side))
        let curseIndex = trikiCatalogIndex(matching: .applyCurse)
        let rowHighlighted = trikiIsHighlighted(catalogIndex: skillIndex)
            || (skill == .curse && trikiIsHighlighted(catalogIndex: curseIndex))
        let charge = rowHighlighted ? trikiHoldChargeProgress : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(skill.title)
                    .font(.title3.bold())
                Spacer()
                Text("\(skill.xpCost) XP")
                    .font(.headline.bold())
                    .foregroundStyle(canBuy ? side.auraAccent : .secondary)
            }

            Text(skill.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let qr = skill.qrPayload, unlocked {
                Text("QR: \(qr)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
            }

            if unlocked {
                Label("Odblokowano", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                if skill == .curse, pathActive {
                    Button("Nałóż klątwę") {
                        showCursePicker = true
                    }
                    .font(.subheadline.bold())
                }
            } else if pathActive {
                Button {
                    attemptUnlockSkill(skill, side: side)
                } label: {
                    Text(canBuy ? "Odblokuj umiejętność" : "Wymaga wcześniejszej umiejętności lub XP")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(canBuy ? side.auraAccent : .gray)
                .disabled(!canBuy)
            } else {
                Text("Najpierw odblokuj ścieżkę powyżej")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(pathActive ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    unlocked ? side.auraAccent.opacity(0.45) : Color.white.opacity(0.12),
                    lineWidth: unlocked ? 1.5 : 1
                )
        )
        .shadow(color: unlocked ? side.auraAccent.opacity(0.2) : .clear, radius: 8)
        .opacity(pathActive ? 1 : 0.55)
        .trikiSelectableHighlight(isSelected: rowHighlighted, chargeProgress: charge)
    }

    private func attemptUnlockSkill(_ skill: PowerPathSkillID, side: PowerPathSide) {
        guard !progress.hasUnlocked(skill) else { return }
        settings.playTapSound()
        guard let message = onUnlockSkill(skill) else { return }

        if progress.hasUnlocked(skill) {
            feedbackMessage = ""
            skillUnlockReveal = PowerPathSkillUnlockReveal(skill: skill, side: side, message: message)
        } else {
            feedbackMessage = message
        }
    }

    private var xpChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.circle.fill")
                .foregroundStyle(settings.accentColor)
            Text("\(progress.experiencePoints) XP")
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func customPathChoiceTile(_ path: CreatedPowerPath, trikiRowIndex: Int?) -> some View {
        let accent = path.glowColor.swiftUIColor
        let isTrikiSelected = trikiRowIndex.map { trikiHighlightIndex == $0 } ?? false
        return Button {
            settings.playTapSound()
            withAnimation(PowerPathTabAnimation.ease) {
                browsingCustomPathID = path.id
            }
            feedbackMessage = ""
        } label: {
            VStack(spacing: 12) {
                Image(systemName: path.iconSymbol)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(accent)
                Text(path.name)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("\(path.upgrades.count) ulepszeń")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(accent.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accent.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: accent.opacity(0.35), radius: 16, y: 4)
        }
        .buttonStyle(.plain)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
    }

    private func customPathDetail(path: CreatedPowerPath, showBack: Bool) -> some View {
        let accent = path.glowColor.swiftUIColor
        let pathActive = progress.chosenCustomPathID == path.id

        return VStack(spacing: 0) {
            HStack {
                if showBack {
                    Button {
                        settings.playTapSound()
                        withAnimation(PowerPathTabAnimation.ease) {
                            browsingCustomPathID = nil
                        }
                        feedbackMessage = ""
                    } label: {
                        Label("Wróć", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                xpChip
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: path.iconSymbol)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.55), radius: 12)
                        Text("Ścieżka Mocy")
                            .font(.title.bold())
                            .foregroundStyle(accent)
                        Text(path.name)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    if !pathActive {
                        unlockCustomPathButton(for: path, accent: accent)
                    } else {
                        Label("Ścieżka aktywna", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 12) {
                        ForEach(path.upgrades) { upgrade in
                            customUpgradeTile(
                                path: path,
                                upgrade: upgrade,
                                accent: accent,
                                pathActive: pathActive
                            )
                        }
                    }

                    if !feedbackMessage.isEmpty, customUpgradeReveal == nil {
                        Text(feedbackMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            continueButton
        }
    }

    private func unlockCustomPathButton(for path: CreatedPowerPath, accent: Color) -> some View {
        Button {
            settings.playTapSound()
            if let message = onUnlockCustomPath?(path.id) {
                feedbackMessage = message
                if progress.chosenCustomPathID == path.id {
                    browsingCustomPathID = path.id
                    HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.7)
                }
            }
        } label: {
            Text("Odblokuj")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.appProminent)
        .tint(accent)
        .padding(.horizontal, 4)
        .shadow(color: accent.opacity(0.4), radius: 12, y: 4)
    }

    private func customUpgradeTile(
        path: CreatedPowerPath,
        upgrade: CreatedPowerUpgrade,
        accent: Color,
        pathActive: Bool
    ) -> some View {
        let unlocked = progress.unlockedCustomUpgradeIDs.contains(upgrade.id)
        let prerequisites = path.upgrades.filter { $0.tier < upgrade.tier }.map(\.id)
        let canBuy = pathActive
            && !unlocked
            && progress.experiencePoints >= upgrade.xpCost
            && prerequisites.allSatisfy { progress.unlockedCustomUpgradeIDs.contains($0) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(upgrade.name)
                    .font(.title3.bold())
                Spacer()
                Text("\(upgrade.xpCost) XP")
                    .font(.headline.bold())
                    .foregroundStyle(canBuy ? accent : .secondary)
            }

            Text(upgrade.summary.isEmpty ? upgrade.effectSummary : upgrade.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if unlocked {
                Label("Odblokowano", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else if pathActive {
                Button {
                    attemptUnlockCustomUpgrade(path: path, upgrade: upgrade, accent: accent)
                } label: {
                    Text(canBuy ? "Odblokuj umiejętność" : "Wymaga wcześniejszej umiejętności lub XP")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(canBuy ? accent : .gray)
                .disabled(!canBuy)
            } else {
                Text("Najpierw odblokuj ścieżkę powyżej")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(pathActive ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    unlocked ? accent.opacity(0.45) : Color.white.opacity(0.12),
                    lineWidth: unlocked ? 1.5 : 1
                )
        )
        .shadow(color: unlocked ? accent.opacity(0.2) : .clear, radius: 8)
        .opacity(pathActive ? 1 : 0.55)
    }

    private func attemptUnlockCustomUpgrade(
        path: CreatedPowerPath,
        upgrade: CreatedPowerUpgrade,
        accent: Color
    ) {
        guard !progress.unlockedCustomUpgradeIDs.contains(upgrade.id) else { return }
        settings.playTapSound()
        guard let message = onUnlockCustomUpgrade?(path.id, upgrade.id) else { return }

        if progress.unlockedCustomUpgradeIDs.contains(upgrade.id) {
            feedbackMessage = ""
            customUpgradeReveal = PowerPathCustomUpgradeReveal(
                path: path,
                upgrade: upgrade,
                message: message
            )
        } else {
            feedbackMessage = message
        }
    }

    private var continueButton: some View {
        let exitIndex = trikiCatalog.firstIndex(where: { $0.target == .exitGame })
        let isTrikiSelected = exitIndex.map { trikiHighlightIndex == $0 } ?? false
        return Button {
            settings.playTapSound()
            onExit()
        } label: {
            Text("Kontynuuj grę")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.appProminent)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
    }
}

// MARK: - Triki (katalog opcji w aktywnym ekranie)

extension PowerPathFullScreenView {
    private var trikiScreenFingerprint: String {
        let reveal = skillUnlockReveal != nil || customUpgradeReveal != nil
        return [
            browsingSide?.rawValue ?? "",
            browsingCustomPathID?.uuidString ?? "",
            progress.chosenSide?.rawValue ?? "",
            progress.chosenCustomPathID?.uuidString ?? "",
            String(progress.experiencePoints),
            progress.unlockedSkills.map(\.rawValue).sorted().joined(separator: ","),
            progress.unlockedCustomUpgradeIDs.map(\.uuidString).sorted().joined(separator: ","),
            reveal ? "reveal" : ""
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func trikiCatalogRow(_ row: PowerPathTrikiRow, catalogIndex: Int) -> some View {
        switch row.target {
        case .openSide(let side):
            pathChoiceTile(side, trikiRowIndex: catalogIndex)
        case .openCustomPath(let pathID):
            if let path = customPaths.first(where: { $0.id == pathID }) {
                customPathChoiceTile(path, trikiRowIndex: catalogIndex)
            }
        case .exitGame:
            EmptyView()
        default:
            EmptyView()
        }
    }

    fileprivate func rebuildTrikiCatalog() {
        if skillUnlockReveal != nil {
            trikiCatalog = [PowerPathTrikiRow(target: .dismissReveal, title: "Kontynuuj")]
            return
        }
        if customUpgradeReveal != nil {
            trikiCatalog = [PowerPathTrikiRow(target: .dismissReveal, title: "Kontynuuj")]
            return
        }

        var rows: [PowerPathTrikiRow] = []

        if let customID = progress.chosenCustomPathID,
           let path = powerPaths.first(where: { $0.id == customID }) {
            appendCustomPathDetail(into: &rows, path: path, showBack: false)
        } else if let browseID = browsingCustomPathID,
                  let path = powerPaths.first(where: { $0.id == browseID }) {
            appendCustomPathDetail(into: &rows, path: path, showBack: true)
        } else if progress.hasChosenPath, let side = progress.chosenSide {
            appendPathDetail(into: &rows, side: side, showBack: false)
        } else if let side = browsingSide {
            appendPathDetail(into: &rows, side: side, showBack: true)
        } else {
            appendPathSelection(into: &rows)
        }

        trikiCatalog = rows
    }

    private func appendPathSelection(into rows: inout [PowerPathTrikiRow]) {
        rows.append(PowerPathTrikiRow(target: .openSide(.dark), title: PowerPathSide.dark.title))
        rows.append(PowerPathTrikiRow(target: .openSide(.light), title: PowerPathSide.light.title))
        for path in customPaths {
            rows.append(PowerPathTrikiRow(target: .openCustomPath(path.id), title: path.name))
        }
        rows.append(PowerPathTrikiRow(target: .exitGame, title: "Kontynuuj grę"))
    }

    private func appendPathDetail(into rows: inout [PowerPathTrikiRow], side: PowerPathSide, showBack: Bool) {
        if showBack {
            rows.append(PowerPathTrikiRow(target: .back, title: "Wróć"))
        }
        if !progress.hasChosenPath || progress.chosenSide != side {
            rows.append(PowerPathTrikiRow(target: .unlockSide(side), title: "Odblokuj \(side.title)"))
        }
        appendSkillRows(into: &rows, side: side)
        rows.append(PowerPathTrikiRow(target: .exitGame, title: "Kontynuuj grę"))
    }

    private func appendCustomPathDetail(
        into rows: inout [PowerPathTrikiRow],
        path: CreatedPowerPath,
        showBack: Bool
    ) {
        if showBack {
            rows.append(PowerPathTrikiRow(target: .back, title: "Wróć"))
        }
        let pathActive = progress.chosenCustomPathID == path.id
        if !pathActive {
            rows.append(PowerPathTrikiRow(target: .unlockCustomPath(path.id), title: "Odblokuj \(path.name)"))
        }
        for upgrade in path.upgrades {
            let unlocked = progress.unlockedCustomUpgradeIDs.contains(upgrade.id)
            let prerequisites = path.upgrades.filter { $0.tier < upgrade.tier }.map(\.id)
            let canBuy = pathActive
                && !unlocked
                && progress.experiencePoints >= upgrade.xpCost
                && prerequisites.allSatisfy { progress.unlockedCustomUpgradeIDs.contains($0) }
            if !unlocked, pathActive, canBuy {
                rows.append(
                    PowerPathTrikiRow(
                        target: .unlockCustomUpgrade(pathID: path.id, upgradeID: upgrade.id),
                        title: upgrade.name
                    )
                )
            }
        }
        rows.append(PowerPathTrikiRow(target: .exitGame, title: "Kontynuuj grę"))
    }

    private func appendSkillRows(into rows: inout [PowerPathTrikiRow], side: PowerPathSide) {
        let pathActive = progress.chosenSide == side
        for skill in PowerPathSkillID.skills(for: side) {
            let unlocked = progress.hasUnlocked(skill)
            let canBuy = pathActive && progress.canUnlock(skill)
            if unlocked, skill == .curse, pathActive {
                rows.append(PowerPathTrikiRow(target: .applyCurse, title: "Nałóż klątwę"))
            } else if !unlocked, pathActive, canBuy {
                rows.append(
                    PowerPathTrikiRow(
                        target: .unlockSkill(skill, side),
                        title: skill.title
                    )
                )
            }
        }
    }

    fileprivate func activateTrikiRow(at index: Int) {
        guard trikiCatalog.indices.contains(index) else { return }
        let row = trikiCatalog[index]
        settings.playTapSound()

        switch row.target {
        case .exitGame:
            onExit()
        case .dismissReveal:
            if skillUnlockReveal != nil {
                skillUnlockReveal = nil
            } else if customUpgradeReveal != nil {
                customUpgradeReveal = nil
            }
            rebuildTrikiCatalog()
            return
        case .back:
            withAnimation(PowerPathTabAnimation.ease) {
                browsingSide = nil
                browsingCustomPathID = nil
            }
            feedbackMessage = ""
        case .openSide(let side):
            withAnimation(PowerPathTabAnimation.ease) {
                browsingSide = side
            }
            feedbackMessage = ""
        case .openCustomPath(let pathID):
            withAnimation(PowerPathTabAnimation.ease) {
                browsingCustomPathID = pathID
            }
            feedbackMessage = ""
        case .unlockSide(let side):
            if let message = onUnlockPath(side) {
                feedbackMessage = message
                if progress.chosenSide == side {
                    browsingSide = side
                    HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.7)
                }
            }
        case .unlockSkill(let skill, let side):
            attemptUnlockSkill(skill, side: side)
        case .applyCurse:
            showCursePicker = true
        case .unlockCustomPath(let pathID):
            if let message = onUnlockCustomPath?(pathID) {
                feedbackMessage = message
                if progress.chosenCustomPathID == pathID {
                    browsingCustomPathID = pathID
                    HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.7)
                }
            }
        case .unlockCustomUpgrade(let pathID, let upgradeID):
            if let path = powerPaths.first(where: { $0.id == pathID }) {
                attemptUnlockCustomUpgrade(path: path, upgrade: path.upgrades.first(where: { $0.id == upgradeID })!, accent: path.glowColor.swiftUIColor)
            }
        }
        rebuildTrikiCatalog()
    }
}

struct PowerPathSkillUnlockReveal: Equatable {
    let skill: PowerPathSkillID
    let side: PowerPathSide
    let message: String
}

struct PowerPathCustomUpgradeReveal: Equatable {
    let path: CreatedPowerPath
    let upgrade: CreatedPowerUpgrade
    let message: String
}

struct PowerPathCustomUpgradeUnlockOverlay: View {
    @Environment(AppSettings.self) private var settings

    let path: CreatedPowerPath
    let upgrade: CreatedPowerUpgrade
    let detailMessage: String
    let onDismiss: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.72
    @State private var cardOpacity: Double = 0

    private var accent: Color { path.glowColor.swiftUIColor }

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity * 0.72)
                .ignoresSafeArea()

            PowerPathAuraBackground(side: nil, customGlow: path.glowColor)
                .opacity(backdropOpacity * 0.85)
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Image(systemName: path.iconSymbol)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.65), radius: 24)

                Text("Odblokowano")
                    .font(.title.bold())

                Text(upgrade.name)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(detailMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Kontynuuj") {
                    settings.playTapSound()
                    onDismiss()
                }
                .buttonStyle(.appProminent)
                .tint(accent)
                .padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(LiquidGlassBackground(accentStroke: accent, cornerRadius: 24))
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                backdropOpacity = 1
                cardScale = 1
                cardOpacity = 1
            }
            HapticManager.playStatReveal(intensity: settings.hapticIntensity)
        }
    }
}
