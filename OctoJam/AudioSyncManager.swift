//
//  AudioSyncManager.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
class AudioSyncManager: NSObject {

    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var volume: Float = 1.0
    var currentFileName: String = ""
    var isLoaded: Bool = false
    var isBuffering: Bool = false
    var currentURL: URL?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            #endif
        } catch {
            print("[AudioSync] AVAudioSession Error: \(error)")
        }
    }

    func loadAudio(url: URL) {
        stop()
        statusObservation?.invalidate()
        statusObservation = nil
        if let to = timeObserver {
            player?.removeTimeObserver(to)
            timeObserver = nil
        }
        isLoaded = false
        isBuffering = true
        currentFileName = url.lastPathComponent
        currentURL = url
        
        var safeURL = url
        if safeURL.scheme == nil {
            safeURL = URL(string: "https://\(url.absoluteString)") ?? url
        }
        let playerItem = AVPlayerItem(url: safeURL)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.volume = volume
        
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isBuffering = false
                    self.isLoaded = true
                    let durationSeconds = item.duration.seconds
                    self.duration = durationSeconds.isNaN ? 0 : durationSeconds
                } else if item.status == .failed {
                    self.isBuffering = false
                    print("[AudioSync] Failed to load audio URL.")
                }
            }
        }
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.player else { return }
                self.currentTime = time.seconds.isNaN ? 0 : time.seconds
                self.isPlaying = player.rate != 0
            }
        }
    }

    func playNow() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
    }

    func play(scheduleAt hostScheduleTime: Double, clockOffset: Double = 0) {
        guard let player = player else { return }

        let localNow = CACurrentMediaTime()
        let localScheduleTime = hostScheduleTime - clockOffset
        let delay = localScheduleTime - localNow

        if delay > 0.005 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                player.play()
                self.isPlaying = true
            }
        } else {
            let overdue = -delay
            if overdue > 0.030 && overdue < duration {
                player.seek(to: CMTime(seconds: overdue, preferredTimescale: 600))
            }
            player.play()
            isPlaying = true
        }
    }

    func prepareToPlay(completion: @escaping @MainActor (Bool) -> Void) {
        guard let player = player, isLoaded else {
            completion(false)
            return
        }
        player.preroll(atRate: 1.0) { finished in
            Task { @MainActor in
                completion(finished)
            }
        }
    }

    func resetAndClearCache() {
        stop()
        statusObservation?.invalidate()
        statusObservation = nil
        if let to = timeObserver {
            player?.removeTimeObserver(to)
            timeObserver = nil
        }
        player = nil
        isLoaded = false
        currentURL = nil
        currentTime = 0
        duration = 0
        
        // Clear system caches if any
        URLCache.shared.removeAllCachedResponses()
    }

    func pause() {
        player?.pause()
        player?.preroll(atRate: 1.0) { _ in }
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        currentTime = 0
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, duration))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    func setVolume(_ vol: Float) {
        volume = max(0, min(vol, 1))
        player?.volume = volume
    }

    func handleCommand(_ cmd: SyncCommand, clockOffset: Double) {
        switch cmd.type {
        case .loadURL, .currentState:
            if let urlString = cmd.audioURL, let url = URL(string: urlString) {
                if currentURL != url {
                    loadAudio(url: url)
                }
                if let isPlaying = cmd.isPlaying, isPlaying {
                    if let sec = cmd.seekSeconds {
                        seek(to: sec)
                    }
                    if let scheduleAt = cmd.scheduleAt {
                        play(scheduleAt: scheduleAt, clockOffset: clockOffset)
                    } else {
                        player?.play()
                    }
                }
            }
        case .play:
            if let scheduleAt = cmd.scheduleAt {
                play(scheduleAt: scheduleAt, clockOffset: clockOffset)
            } else {
                player?.play()
            }
        case .pause: pause()
        case .stop: stop()
        case .setVolume: if let v = cmd.volume { setVolume(v) }
        case .seekTo: if let s = cmd.seekSeconds { seek(to: s) }
        case .syncClock, .syncClockResponse, .requestState, .prepareToPlay, .readyToPlay, .updatePeerInfo: break
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
