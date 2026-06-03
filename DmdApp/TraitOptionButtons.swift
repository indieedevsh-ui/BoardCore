//
//  TraitOptionButtons.swift
//  DmdApp
//

import SwiftUI

/// Zalety i wady jako osobne przyciski; sprzeczne opcje są blokowane.
struct CreatorTraitPickerSection: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    let options: [String]
    @Binding var selection: Set<String>
    @Binding var oppositeSelection: Set<String>
    let maxCount: Int
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text("Maks. \(maxCount) — wybrano \(selection.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(options, id: \.self) { option in
                traitButton(option)
            }
        }
    }

    private func traitButton(_ option: String) -> some View {
        let isSelected = selection.contains(option)
        let isBlocked = CharacterOptions.isTraitBlocked(option, bySelected: oppositeSelection)

        return Button {
            guard !isBlocked else { return }
            settings.playTapSound()
            toggle(option)
        } label: {
            HStack {
                Text(option)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isBlocked ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.22) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .opacity(isBlocked ? 0.45 : 1)
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
            return
        }
        guard selection.count < maxCount else { return }
        if let conflict = CharacterOptions.conflictingTrait(for: option) {
            oppositeSelection.remove(conflict)
        }
        selection.insert(option)
    }
}
