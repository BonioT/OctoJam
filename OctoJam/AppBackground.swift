//
//  AppBackground.swift
//  AudioSync
//
//  Created by Antimo Bucciero on 30/03/2026.
//


import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "4B1D7C"), Color(hex: "05030B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            RadialGradient(
                colors: [Color(hex: "8A2BE2").opacity(0.3), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}

fileprivate var hasSeenSplashInSession = false

struct RoleSelectionView: View {
    let onSelect: (ContentView.AppRole) -> Void
    @State private var showSplash: Bool = !hasSeenSplashInSession
    @State private var showInviteModal = false

    var body: some View {
        ZStack {
            if showSplash {
                splashScreen
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showSplash = false
                                hasSeenSplashInSession = true
                            }
                        }
                    }
            } else {
                VStack(spacing: 0) {
                    // Top bar with invite button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { showInviteModal = true }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    // Logo + Name
                    VStack(spacing: 12) {
                        Image("OctopusLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)

                        Text("OCTOJAM")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(4)
                    }

                    Spacer()

                    // Role buttons
                    VStack(spacing: 14) {
                        Button { onSelect(.host) } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(colors: [Color(hex: "B25EFF"), Color(hex: "8928D9")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "crown.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Host a party")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Choose the music and control the room")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }

                        Button { onSelect(.client) } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(colors: [Color(hex: "A855F7").opacity(0.6), Color(hex: "7B2FBE").opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "link")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Join a party")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Join the room and vibe with your peers")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Connection info
                    Text("Wi-Fi / Bluetooth connection")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 20)

                    Spacer().frame(height: 40)
                }
                .transition(.opacity)
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
    }

    private var splashScreen: some View {
        VStack(spacing: 0) {
            // Silent mode reminder
            Text("Turn off Silent Mode")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 60)

            Spacer()

            // Logo
            Image("OctopusLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .shadow(color: Color(hex: "A855F7").opacity(0.3), radius: 24)

            // Tagline
            VStack(spacing: 8) {
                Text("Music is")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 0) {
                    Text("better with ")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("friends.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(hex: "A855F7"))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, 24)

            Text("Play, sync, and vibe as one.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 20)

            Spacer()
        }
    }
}



struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial.opacity(0.6))
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

struct PulsingDot: View {
    var color: Color = .green
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: pulse ? 22 : 12, height: pulse ? 22 : 12).animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            Circle().fill(color).frame(width: 10, height: 10)
        }
        .onAppear { pulse = true }
    }
}

struct AudioBarsView: View {
    var isPlaying: Bool
    var color: Color = .green
    var barCount: Int = 5
    @State private var heights: [CGFloat] = []

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: isPlaying ? heights[safe: i] ?? 8 : 4)
                    .animation(isPlaying ? .easeInOut(duration: Double.random(in: 0.25...0.45)).repeatForever(autoreverses: true).delay(Double(i) * 0.07) : .easeOut(duration: 0.2), value: isPlaying)
            }
        }
        .onAppear { heights = (0..<barCount).map { _ in CGFloat.random(in: 8...20) } }
        .onChange(of: isPlaying) { _, play in if play { heights = (0..<barCount).map { _ in CGFloat.random(in: 8...20) } } }
    }
}

extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }

struct AmplificationBadge: View {
    let deviceCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.caption)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(deviceCount) active devices · +\( (10 * log10(Double(deviceCount))).formatted(.number.precision(.fractionLength(1))) ) dB")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Text("Estimated perceived amplification")
                    .font(.caption2)
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85) } else { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Group { if isDisabled || isLoading { Color.white.opacity(0.08) } else { LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing) } })
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}

#Preview {
    ContentView()
}
