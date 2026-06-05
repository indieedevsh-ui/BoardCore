//
//  CampaignsHomeView.swift
//  BoardCore
//

import SwiftUI

struct CampaignsHomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CampaignStore.self) private var campaignStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Biblioteka kampanii")
                        .font(.largeTitle.bold())

                    Text("Wybierz aktywną kampanię do gry lub wgraj nową.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        UploadCampaignView()
                    } label: {
                        Label("Wgraj kampanię", systemImage: "square.and.arrow.down.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .liquidGlassButtonBackground(prominent: true, cornerRadius: 14, accent: Color(red: 0.45, green: 0.72, blue: 1.0))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        settings.playTapSound()
                    })

                    if campaignStore.library.isEmpty {
                        ContentUnavailableView(
                            "Brak kampanii",
                            systemImage: "books.vertical",
                            description: Text("Wgraj pierwszą kampanię z ChatGPT.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    } else {
                        ForEach(campaignStore.library) { entry in
                            campaignCard(entry)
                        }
                    }
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("Kampanie")
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func campaignCard(_ entry: SavedCampaignEntry) -> some View {
        let isActive = campaignStore.activeCampaignID == entry.id

        return Button {
            settings.playTapSound()
            campaignStore.activateCampaign(id: entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if isActive {
                        Text("Aktywna")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.22), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                Text("\(entry.sceneCount) scen · \(entry.decisionCount) decyzji")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(entry.climate.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.green.opacity(0.55) : Color.white.opacity(0.12),
                        lineWidth: isActive ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Ustaw jako aktywną") {
                settings.playTapSound()
                campaignStore.activateCampaign(id: entry.id)
            }
            Button("Usuń", role: .destructive) {
                settings.playTapSound()
                campaignStore.removeCampaign(id: entry.id)
            }
        }
    }
}

#Preview {
    CampaignsHomeView()
        .environment(AppSettings())
        .environment(CampaignStore())
}
