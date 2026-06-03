//
//  GameRulesView.swift
//  DmdApp
//

import SwiftUI

struct GameRulesView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Zasady gry")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)

                RuleRow(
                    number: 1,
                    text: "Wybierz zestaw fiszek i rozpocznij rundę przyciskiem „Graj”."
                )
                RuleRow(
                    number: 2,
                    text: "Na ekranie pojawia się pytanie — odpowiedz na nie w myśl lub na głos."
                )
                RuleRow(
                    number: 3,
                    text: "Odsłoń odpowiedź i oceń, czy znasz materiał. Powtarzaj trudniejsze karty częściej."
                )
                RuleRow(
                    number: 4,
                    text: "Zakończ rundę, gdy przejdziesz cały zestaw. Wynik zapisuje się w aplikacji."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .appScrollSurface()
        .navigationTitle("Zasady gry")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
    }
}

struct RuleRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.body.bold())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        GameRulesView()
    }
    .environment(AppSettings())
    .environment(PlayerSlotStore())
    .environment(CreatorStore())
}
