//
//  ClientView.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import SwiftUI
import MultipeerConnectivity

struct ClientView: View {
    var multipeer: MultipeerManager
    var audio: AudioSyncManager
    let onBack: () -> Void

    @State private var showInviteModal = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    
                    RadarView(multipeer: multipeer, isHost: false)
                    
                    ReactionBar(multipeer: multipeer, onLeave: onBack)
                    
                    Divider().background(Color.white.opacity(0.1))

                    if audio.isBuffering {
                        bufferingCard
                    } else if audio.isLoaded {
                        nowPlayingCard
                    } else if multipeer.connectedPeers.isEmpty {
                        searchingCard
                    } else {
                        waitingForFileCard
                    }

                    if audio.isLoaded {
                        volumeCard
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            
            if showInviteModal {
                InviteModalView(
                    onDismiss: { withAnimation { showInviteModal = false } },
                    onInvite: { withAnimation { showInviteModal = false } }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            multipeer.startBrowsing()
            multipeer.onCommandReceived = { [weak multipeer, weak audio] cmd, peerID in
                guard let audio = audio, let mp = multipeer else { return }
                if cmd.type == .prepareToPlay {
                    audio.prepareToPlay { _ in
                        mp.sendCommand(SyncCommand(type: .readyToPlay))
                    }
                } else {
                    audio.handleCommand(cmd, clockOffset: mp.clockOffset)
                }
            }
        }
        .onDisappear {
            multipeer.disconnect()
            audio.resetAndClearCache()
        }
    }

    private var bufferingCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00B4D8")))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buffering audio...")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(audio.currentFileName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            Text(topBarTitle)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
            Button {
                withAnimation { showInviteModal = true }
            } label: {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5).frame(width: 40, height: 40)
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.top, 8)
    }

    private var topBarTitle: String {
        if !multipeer.hostRoomName.isEmpty {
            return multipeer.hostRoomName
        } else if let host = multipeer.connectedPeers.first {
            return "\(host.displayName)'s Room"
        }
        return "Waiting Room"
    }

    private var searchingCard: some View {
        GlassCard {
            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3) { i in RippleCircle(delay: Double(i) * 0.5) }
                    Image(systemName: "wifi").font(.title).foregroundStyle(.white.opacity(0.7))
                }.frame(height: 100)
                Text("Searching for a session...").font(.subheadline).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                Text("Ensure the host has the app open\nand is on the same network.").font(.caption).foregroundStyle(.white.opacity(0.35)).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    private var waitingForFileCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00B4D8")))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connected · Waiting for host")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("The host will broadcast the audio shortly.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var nowPlayingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Now Playing", systemImage: "music.note").font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    AudioBarsView(isPlaying: audio.isPlaying, color: Color(hex: "00B4D8"))
                }
                Text(audio.currentFileName).font(.headline).foregroundStyle(.white).lineLimit(2)
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "0077B6"), Color(hex: "00B4D8")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: audio.duration > 0 ? geo.size.width * CGFloat(audio.currentTime / audio.duration) : 0, height: 5)
                        }
                    }.frame(height: 5)
                    HStack {
                        Text(audio.formattedTime(audio.currentTime))
                        Spacer()
                        Text(audio.formattedTime(audio.duration))
                    }.font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }

    private var volumeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.white.opacity(0.8))
                    Text("Volume Control").font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(audio.volume * 100))%").font(.title3.bold()).foregroundStyle(.white)
                }
                HStack(spacing: 14) {
                    Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.white.opacity(0.35))
                    Slider(
                        value: Binding(get: { audio.volume }, set: { v in audio.setVolume(v); multipeer.sendCommand(SyncCommand(type: .setVolume, volume: v)) }),
                        in: 0...1
                    ).tint(Color(hex: "00B4D8"))
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.top, 8)
    }

    private var isConnected: Bool { !multipeer.connectedPeers.isEmpty }
    private var statusColor: Color { isConnected ? .green : Color(hex: "F59E0B") }
    private var statusIcon: String { isConnected ? "checkmark.circle.fill" : "magnifyingglass" }
    private var statusTitle: String { isConnected ? "Connected to Session" : "Searching for Host..." }
    private var statusSubtitle: String { isConnected ? "Ready — Playback will sync automatically." : "Looking for nearby hosts via WiFi or Bluetooth." }
}
struct RippleCircle: View {
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color(hex: "00B4D8").opacity(animate ? 0 : 0.4), lineWidth: 1.5)
            .frame(width: animate ? 100 : 30, height: animate ? 100 : 30)
            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(delay), value: animate)
            .onAppear { animate = true }
    }
}
