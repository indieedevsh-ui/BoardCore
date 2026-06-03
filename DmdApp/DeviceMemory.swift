//
//  DeviceMemory.swift
//  DmdApp
//

import Foundation
import os

enum DeviceMemory {
    /// Fizyczna pamięć urządzenia (nie wolna RAM w danym momencie).
    static var physicalMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Urządzenia z ≤ 5 GB RAM nie mogą włączyć kampanii fabularnych.
    static let campaignsMaximumPhysicalMemoryBytes: UInt64 = 5_368_709_120

    static var blocksCampaignsDueToLowRAM: Bool {
        physicalMemoryBytes <= campaignsMaximumPhysicalMemoryBytes
    }

    static var physicalMemoryLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(physicalMemoryBytes), countStyle: .memory)
    }

    static var availableBytes: UInt64 {
        UInt64(os_proc_available_memory())
    }

    static var availableLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableBytes), countStyle: .memory)
    }

    /// Szacowany budżet RAM na kontekst (wagi modelu są głównie mmap — nie rezerwujemy całego pliku).
    static var llamaContextMemoryBudgetBytes: UInt64 {
        let available = availableBytes
        let cap: UInt64 = 2_200_000_000
        let floor: UInt64 = 700_000_000
        let scaled = available / 3
        return min(cap, max(floor, scaled))
    }

    static func ensureEnoughForModelLoad() throws {
        let available = availableBytes
        guard available >= LocalLLMConfig.minimumFreeMemoryBytes else {
            throw LlamaEngineError.loadFailed(
                "Za mało wolnej pamięci (\(availableLabel)). Zamknij inne aplikacje i spróbuj ponownie."
            )
        }
    }
}
