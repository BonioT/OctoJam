//
//  HostView.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import SwiftUI
import MultipeerConnectivity

struct HostView: View {
    var multipeer: MultipeerManager
    var audio: AudioSyncManager
    var roomName: String
    let onBack: () -> Void

    @State private var urlString: String = ""
    @State private var showInviteModal = false

    private var displayRoomName: String {
        roomName.isEmpty ? "\(multipeer.myPeerID.displayName)'s Room" : roomName
    }

    var body: some View {
        ZStack {
            AppBackground()

            if audio.isLoaded {
                roomPhase
            } else {
                lobbyPhase
            }

            // Invite modal overlay
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
            multipeer.hostRoomName = displayRoomName
            multipeer.startHosting()

            multipeer.onAllPeersReadyToPlay = {
                let scheduleAt = CACurrentMediaTime() + 0.3
                self.audio.play(scheduleAt: scheduleAt, clockOffset: 0)
                self.multipeer.sendCommand(SyncCommand(type: .play, hostTimestamp: CACurrentMediaTime(), scheduleAt: scheduleAt))
            }

            multipeer.onCommandReceived = { cmd, peerID in
                if cmd.type == .requestState {
                    if let url = self.audio.currentURL {
                        var state = SyncCommand(type: .currentState)
                        state.audioURL = url.absoluteString
                        state.isPlaying = self.audio.isPlaying
                        if self.audio.isPlaying {
                            state.seekSeconds = self.audio.currentTime + 1.2
                            state.scheduleAt = CACurrentMediaTime() + 1.2
                        } else {
                            state.seekSeconds = self.audio.currentTime
                        }
                        self.multipeer.sendCommand(state)
                    }
                }
            }
        }
        .onDisappear {
            multipeer.disconnect()
            audio.resetAndClearCache()
        }
        .alert(
            "Connection Request",
            isPresented: Binding(get: { multipeer.incomingPeer != nil }, set: { if !$0 { multipeer.declineInvitation() } })
        ) {
            Button("Accept") { multipeer.acceptInvitation() }
            Button("Decline", role: .cancel) { multipeer.declineInvitation() }
        } message: {
            if let peer = multipeer.incomingPeer {
                Text("\(peer.displayName) wants to join the session.")
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Phase 1: Lobby (Setup)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var lobbyPhase: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: onBack) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                        Image(systemName: "chevron.left").foregroundStyle(.white)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Host a party")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text(displayRoomName)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }

                vibingNowCard
                songCard

                // Open Youtube
                HStack {
                    Spacer()
                    Button {
                        if let url = URL(string: "https://www.youtube.com") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    } label: {
                        Text("Open Youtube")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(hex: "A855F7"))
                    }
                    Spacer()
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
        }
        .transition(.opacity)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Phase 2: Room (Live Session)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var roomPhase: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Room header
                HStack {
                    Text(displayRoomName)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation { showInviteModal = true }
                    } label: {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5).frame(width: 44, height: 44)
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.top, 8)

                // Radar with avatars
                RadarView(multipeer: multipeer, isHost: true)

                // Reaction bar
                ReactionBar(multipeer: multipeer, onLeave: onBack)

                Divider().background(Color.white.opacity(0.1))

                // Playing now card
                playingNowCard

                // Song URL card (to change song)
                songCard

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Cards
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var vibingNowCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Vibing now")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(multipeer.connectedPeers.count + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(hex: "A855F7"))
                }

                HStack(spacing: 10) {
                    Circle().fill(Color(hex: multipeer.myColor)).frame(width: 10, height: 10)
                    Text("\(multipeer.myPeerID.displayName) (you)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                ForEach(multipeer.connectedPeers, id: \.self) { peer in
                    HStack(spacing: 10) {
                        let info = multipeer.peerAvatars[peer]
                        Circle().fill(Color(hex: info?.color ?? "10B981")).frame(width: 10, height: 10)
                        Text(peer.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                if multipeer.connectedPeers.isEmpty {
                    Text("Waiting other devices...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)
                }
            }
        }
    }

    private var playingNowCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Playing now", systemImage: "music.note")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    AudioBarsView(isPlaying: audio.isPlaying, color: Color(hex: "A855F7"))
                }

                Text(audio.currentFileName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "7B2FBE"), Color(hex: "C850C0")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: audio.duration > 0 ? geo.size.width * CGFloat(audio.currentTime / audio.duration) : 0, height: 5)
                        }
                    }.frame(height: 5)
                    HStack {
                        Text(audio.formattedTime(audio.currentTime))
                        Spacer()
                        Text(audio.formattedTime(audio.duration))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.35))
                }

                // Transport controls
                HStack(spacing: 0) {
                    Button("Stop", systemImage: "stop.fill") {
                        audio.stop()
                        multipeer.sendCommand(SyncCommand(type: .stop))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button("Rewind 10s", systemImage: "gobackward.10") {
                        let t = max(0, audio.currentTime - 10)
                        audio.seek(to: t)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: t))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button(audio.isPlaying ? "Pause" : "Play", systemImage: audio.isPlaying ? "pause.fill" : "play.fill", action: togglePlayPause)
                        .labelStyle(.iconOnly).font(.title2).foregroundStyle(.white).frame(width: 66, height: 66)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: "7B2FBE"), Color(hex: "C850C0")], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: Color(hex: "7B2FBE").opacity(0.5), radius: 12))
                    Spacer()
                    Button("Forward 10s", systemImage: "goforward.10") {
                        let t = min(audio.duration, audio.currentTime + 10)
                        audio.seek(to: t)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: t))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button("Restart", systemImage: "backward.end.fill") {
                        audio.seek(to: 0)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: 0))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                }.padding(.horizontal, 8)
            }
        }
    }

    private var songCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Song (URL)", systemImage: "link")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                TextField("https://example.com/audio.mp3", text: $urlString)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color(hex: "A855F7"))
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                if audio.isBuffering {
                    HStack {
                        ProgressView().tint(Color(hex: "A855F7"))
                        Text("Buffering audio from web...").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    PrimaryButton(title: "Share and vibe", icon: "paperplane.fill", gradient: [Color(hex: "7B2FBE"), Color(hex: "C850C0")]) {
                        if let url = URL(string: urlString) {
                            audio.loadAudio(url: url)
                            multipeer.broadcastURL(url)
                            multipeer.broadcastClockSync()
                        }
                    }
                    .disabled(urlString.isEmpty)
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Actions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func togglePlayPause() {
        if audio.isPlaying {
            audio.pause()
            multipeer.sendCommand(SyncCommand(type: .pause))
        } else {
            if multipeer.connectedPeers.isEmpty {
                // No peers — play immediately on host
                audio.playNow()
            } else {
                // With peers — use handshake for synchronized play
                multipeer.initiatePlayHandshake()
            }
        }
    }
}
