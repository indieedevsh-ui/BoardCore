//
//  BackgroundMusicPlayer.swift
//  DmdApp
//

import AVFAudio
import Foundation

enum BackgroundMusicPlayer {
    private static var player: AVAudioPlayer?
    private static let musicVolumeScale = 0.42

    static func startLoopingIfNeeded(appVolume: Double) {
        guard player == nil else {
            updateVolume(appVolume)
            return
        }

        guard let url = Bundle.main.url(forResource: "music", withExtension: "mp3") else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = Float(appVolume * musicVolumeScale)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
        } catch {
            player = nil
        }
    }

    static func updateVolume(_ appVolume: Double) {
        player?.volume = Float(appVolume * musicVolumeScale)
    }

    static func pause() {
        player?.pause()
    }

    static func resume(appVolume: Double) {
        guard let player else {
            startLoopingIfNeeded(appVolume: appVolume)
            return
        }
        updateVolume(appVolume)
        if !player.isPlaying {
            player.play()
        }
    }
}
