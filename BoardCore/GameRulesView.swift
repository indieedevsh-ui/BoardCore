//
//  GameRulesView.swift
//  BoardCore
//

import SwiftUI

private struct GameRuleTile: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let icon: String
    let accent: Color

    var number: Int { id }
}

struct GameRulesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var trikiCoordinator

    @State private var currentIndex = 0
    @State private var cardTransitionEdge: Edge = .trailing

    private let rulesFocusID = UUID()

    private static let tiles: [GameRuleTile] = [
        GameRuleTile(
            id: 1,
            title: "Start",
            detail: """
            Na początek każdy gracz ma: 100 monet (finanse), 100 zdrowia, 20 siły oraz 0 zdolności. \
            Statystyki możesz później zmieniać polami planszy, kartami i nagrodami.
            """,
            icon: "flag.checkered",
            accent: .yellow
        ),
        GameRuleTile(
            id: 2,
            title: "Siła i finanse",
            detail: "Siła to obrażenia, jakie zadajesz przeciwnikom. Finanse to monety, które możesz wydać w Sklepiku Handlowym.",
            icon: "bolt.heart.fill",
            accent: .red
        ),
        GameRuleTile(
            id: 3,
            title: "Sklepik Handlowy",
            detail: "W Sklepiku Handlowym można kupić lub sprzedać przedmioty.",
            icon: "cart.fill",
            accent: Color(red: 1.0, green: 0.72, blue: 0.28)
        ),
        GameRuleTile(
            id: 4,
            title: "Przedmioty",
            detail: """
            Po zakupieniu przedmiotu można go założyć, aby skorzystać z niego podczas walki z bossem, \
            albo sprzedać go z powrotem. Wartość kupionych przedmiotów losowo może rosnąć lub maleć co turę.
            """,
            icon: "bag.fill",
            accent: .orange
        ),
        GameRuleTile(
            id: 5,
            title: "Sklep i boss",
            detail: "Kupując odpowiednie przedmioty (broń, pancerz, pędzel) zwiększasz szansę na pokonanie bossa lub lepszy drop z Artefaktów.",
            icon: "shield.lefthalf.filled",
            accent: Color(red: 0.55, green: 0.75, blue: 1.0)
        ),
        GameRuleTile(
            id: 6,
            title: "Pomiń turę",
            detail: "Gdy gracz nie stoi na żadnym z kluczowych pól, musi kliknąć „Pomiń turę”.",
            icon: "forward.end.fill",
            accent: .orange
        ),
        GameRuleTile(
            id: 7,
            title: "Boss — nagrody",
            detail: "Pokonanie bossa daje odpowiednią ilość monet i XP (łatwy, średni, trudny — różne pule nagród).",
            icon: "trophy.fill",
            accent: .green
        ),
        GameRuleTile(
            id: 8,
            title: "Ścieżki mocy",
            detail: "XP służy do rozwijania ścieżek mocy, a umiejętności ze ścieżek mocy dają przewagę podczas gry.",
            icon: "bolt.circle.fill",
            accent: Color(red: 0.88, green: 0.42, blue: 0.95)
        ),
        GameRuleTile(
            id: 9,
            title: "Wsparcie w walce",
            detail: "Przed rozpoczęciem walki z bossem inni gracze mogą dołączyć się do organizatora walki i zwiększać jego szansę na wygraną.",
            icon: "person.3.fill",
            accent: .cyan
        ),
        GameRuleTile(
            id: 10,
            title: "Porażka z bossem",
            detail: "Gdy przegra się w walce z bossem, wszyscy uczestnicy tej walki kończą rozgrywkę.",
            icon: "xmark.octagon.fill",
            accent: .red
        ),
        GameRuleTile(
            id: 11,
            title: "Eliminacja",
            detail: "Gdy zdrowie spadnie do 0, gracz kończy rozgrywkę.",
            icon: "heart.slash.fill",
            accent: .pink
        ),
        GameRuleTile(
            id: 12,
            title: "Karta specjalna",
            detail: "Karta specjalna daje 50% szans na pozytywną nagrodę i 50% szans na coś negatywnego.",
            icon: "rectangle.on.rectangle.angled",
            accent: .indigo
        ),
        GameRuleTile(
            id: 13,
            title: "Artefakt i pędzel",
            detail: "Artefakt daje 5% szans na zdolność, 85% na bonusy statystyczne oraz 10% na pechowy los. Pędzel zwiększa szanse na znalezienie zdolności.",
            icon: "sparkles",
            accent: .mint
        ),
        GameRuleTile(
            id: 14,
            title: "Zwycięstwo",
            detail: "Kto pierwszy zdobędzie 10 zdolności, wygrywa grę.",
            icon: "crown.fill",
            accent: .yellow
        ),
    ]

    private var currentTile: GameRuleTile {
        Self.tiles[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 12)

            ruleCard
                .padding(.horizontal, 20)
                .gesture(horizontalSwipeGesture)

            Spacer(minLength: 16)

            pageIndicator
                .padding(.bottom, 8)

            navigationControls
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Zasady gry")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .trikiFocusContext(
            id: rulesFocusID,
            buttons: rulesTrikiButtons,
            onActivate: { activateRulesTriki(at: $0) }
        )
        .onChange(of: trikiCoordinator.motionGestureRevision) { _, _ in
            handleTrikiDirectionGesture()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Zasady gry")
                .font(.title2.bold())
            Text("Przesuń w lewo lub w prawo, aby przełączyć zasadę.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(currentTile.accent.opacity(0.22))
                        .frame(width: 52, height: 52)
                    Image(systemName: currentTile.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(currentTile.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zasada \(currentTile.number)")
                        .font(.caption.bold())
                        .foregroundStyle(currentTile.accent)
                    Text(currentTile.title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)
            }

            Text(currentTile.detail)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(
            LiquidGlassBackground(
                accentStroke: currentTile.accent,
                cornerRadius: 20,
                fillOpacity: 0.12
            )
        )
        .id(currentIndex)
        .transition(
            .asymmetric(
                insertion: .move(edge: cardTransitionEdge).combined(with: .opacity),
                removal: .move(edge: cardTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
            )
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.tiles.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? settings.accentColor : Color.white.opacity(0.25))
                    .frame(width: index == currentIndex ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .accessibilityLabel("Zasada \(currentIndex + 1) z \(Self.tiles.count)")
    }

    private var navigationControls: some View {
        HStack(spacing: 16) {
            rulesNavButton(
                title: "Poprzednia",
                icon: "chevron.left",
                isEnabled: currentIndex > 0,
                isTrikiHighlighted: trikiRulesButtonHighlighted(index: 0)
            ) {
                settings.playTapSound()
                showPreviousRule()
            }

            Text("\(currentIndex + 1) / \(Self.tiles.count)")
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 56)

            rulesNavButton(
                title: "Następna",
                icon: "chevron.right",
                isEnabled: currentIndex < Self.tiles.count - 1,
                isTrikiHighlighted: trikiRulesButtonHighlighted(index: 1),
                iconTrailing: true
            ) {
                settings.playTapSound()
                showNextRule()
            }
        }
    }

    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                if dx < -50 {
                    settings.playTapSound()
                    showNextRule()
                } else if dx > 50 {
                    settings.playTapSound()
                    showPreviousRule()
                }
            }
    }

    private var rulesTrikiButtons: [TrikiFocusButton] {
        [
            TrikiFocusButton(id: "prev", title: "Poprzednia zasada"),
            TrikiFocusButton(id: "next", title: "Następna zasada"),
        ]
    }

    private func rulesTrikiButtonsHighlighted() -> Bool {
        settings.trikiControllerEnabled && trikiCoordinator.highlightIndex != nil
    }

    private func trikiRulesButtonHighlighted(index: Int) -> Bool {
        guard rulesTrikiButtonsHighlighted() else { return false }
        return trikiCoordinator.highlightIndex == index
    }

    private func activateRulesTriki(at index: Int) {
        guard rulesTrikiButtons.indices.contains(index) else { return }
        settings.playTapSound()
        if index == 0 {
            showPreviousRule()
        } else {
            showNextRule()
        }
        trikiCoordinator.statusMessage = rulesTrikiButtons[index].title
    }

    private func handleTrikiDirectionGesture() {
        guard settings.trikiControllerEnabled else { return }
        switch trikiCoordinator.lastMotionGesture {
        case .rotateLeft:
            showPreviousRule()
        case .rotateRight:
            showNextRule()
        default:
            break
        }
    }

    private func showNextRule() {
        guard currentIndex < Self.tiles.count - 1 else { return }
        cardTransitionEdge = .trailing
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            currentIndex += 1
        }
    }

    private func showPreviousRule() {
        guard currentIndex > 0 else { return }
        cardTransitionEdge = .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            currentIndex -= 1
        }
    }

    @ViewBuilder
    private func rulesNavButton(
        title: String,
        icon: String,
        isEnabled: Bool,
        isTrikiHighlighted: Bool,
        iconTrailing: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if !iconTrailing {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.subheadline.bold())
                if iconTrailing {
                    Image(systemName: icon)
                }
            }
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LiquidGlassBackground(
                    accentStroke: isEnabled ? settings.accentColor : .gray,
                    cornerRadius: 14,
                    fillOpacity: isEnabled ? 0.14 : 0.06
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .trikiSelectableHighlight(
            isSelected: isTrikiHighlighted,
            chargeProgress: isTrikiHighlighted ? trikiCoordinator.holdChargeProgress : 0
        )
    }
}

#Preview {
    NavigationStack {
        GameRulesView()
    }
    .environment(AppSettings())
    .environment(TrikiNavigationCoordinator())
}
