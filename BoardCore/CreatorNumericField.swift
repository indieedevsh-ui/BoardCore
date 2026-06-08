//
//  CreatorNumericField.swift
//  BoardCore
//

import SwiftUI

struct CreatorPillNumericField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...9999
    var accentColor: Color
    var onCommit: (() -> Void)? = nil

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(value)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(accentColor)
            }

            TextField("Wpisz liczbę", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accentColor.opacity(isFocused ? 0.55 : 0.32), lineWidth: 1)
                }
                .onChange(of: text) { _, newValue in
                    commitText(newValue)
                }
                .onSubmit { commitText(text) }
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                text = String(newValue)
            }
        }
    }

    private func commitText(_ raw: String) {
        let filtered = raw.filter { $0.isNumber || $0 == "-" }
        guard !filtered.isEmpty, let parsed = Int(filtered) else { return }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
        if filtered != String(clamped) {
            text = String(clamped)
        }
        onCommit?()
    }
}

typealias CreatorPillStepperField = CreatorPillNumericField

struct FieldCategoryOddsEditor: View {
    let title: String
    @Binding var odds: FieldCategoryOdds
    var accentColor: Color
    var onCommit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            CreatorPillNumericField(label: "Szansa: Zdolność (%)", value: $odds.abilityPercent, range: 0...100, accentColor: accentColor, onCommit: onCommit)
            CreatorPillNumericField(label: "Szansa: Fundusze (%)", value: $odds.financesPercent, range: 0...100, accentColor: accentColor, onCommit: onCommit)
            CreatorPillNumericField(label: "Szansa: Statystyka (%)", value: $odds.statisticsPercent, range: 0...100, accentColor: accentColor, onCommit: onCommit)
            CreatorPillNumericField(label: "Szansa: Pechowy los (%)", value: $odds.misfortunePercent, range: 0...100, accentColor: accentColor, onCommit: onCommit)
            Text("Suma: \(odds.abilityPercent + odds.financesPercent + odds.statisticsPercent + odds.misfortunePercent)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
