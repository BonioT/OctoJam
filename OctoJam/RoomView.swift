//
//  RoomView.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import SwiftUI
import MultipeerConnectivity

struct RadarView: View {
    var multipeer: MultipeerManager
    var isHost: Bool
    
    // Static positions for the layout
    let avatarOffsets: [CGSize] = [
        CGSize(width: -60, height: -80),
        CGSize(width: 80, height: -120),
        CGSize(width: -100, height: 40),
        CGSize(width: 70, height: 90),
        CGSize(width: -40, height: 110),
        CGSize(width: 110, height: 20),
        CGSize(width: -90, height: -130),
        CGSize(width: 50, height: -60)
    ]
    
    var body: some View {
        ZStack {
            // Concentric circles
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: CGFloat(i) * 90, height: CGFloat(i) * 90)
            }
            
            // Center Avatar (Me)
            AvatarCircle(color: Color(hex: multipeer.myColor), size: 60, emoji: multipeer.myEmoji)
            
            // Orbital Avatars (Peers)
            let peers = multipeer.connectedPeers
            ForEach(Array(peers.enumerated()), id: \.element) { index, peer in
                let offset = avatarOffsets[index % avatarOffsets.count]
                let info = multipeer.peerAvatars[peer] ?? (emoji: "👤", color: "E0B0FF")
                AvatarCircle(color: Color(hex: info.color), size: 50, emoji: info.emoji)
                    .offset(offset)
            }
            
            // Decorative nodes
            Circle().fill(Color(hex: "A855F7").opacity(0.5)).frame(width: 10, height: 10).offset(x: -70, y: -100)
            Circle().fill(Color(hex: "A855F7").opacity(0.4)).frame(width: 20, height: 20).offset(x: -90, y: -40)
            Circle().fill(Color(hex: "A855F7").opacity(0.6)).frame(width: 30, height: 30).offset(x: -120, y: 20)
            Circle().fill(Color(hex: "A855F7").opacity(0.5)).frame(width: 15, height: 15).offset(x: 80, y: 110)
        }
        .frame(height: 320)
    }
}

struct ReactionBar: View {
    var multipeer: MultipeerManager
    let onLeave: () -> Void
    @State private var showAvatarPicker = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Edit Avatar Button
                Button {
                    showAvatarPicker = true
                } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 48, height: 48)
                        Text(multipeer.myEmoji).font(.title3)
                    }
                }
                
                HStack(spacing: 16) {
                    ReactionButton(emoji: "👍")
                    ReactionButton(emoji: "👎")
                    ReactionButton(emoji: "❤️")
                    ReactionButton(emoji: "🥺")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
            
            Button(action: onLeave) {
                Text("Leave this room")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 32)
                    .background(Color(hex: "A855F7").opacity(0.7))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "A855F7").opacity(0.4), radius: 10, y: 4)
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView(multipeer: multipeer)
                .presentationDetents([.height(300)])
        }
    }
}

struct AvatarPickerView: View {
    var multipeer: MultipeerManager
    @Environment(\.dismiss) var dismiss
    
    let emojis = ["🧑🏻‍🦱", "👩🏽‍🦰", "🧔🏻‍♂️", "👱🏻‍♀️", "👽", "🐙", "🦁", "🐭", "🐼", "🦊"]
    let colors = ["A855F7", "00B4D8", "EC4899", "7B2FBE", "EF4444", "10B981"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Customize Avatar")
                .font(.headline)
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            multipeer.myEmoji = emoji
                            multipeer.broadcastPeerInfo()
                        } label: {
                            Text(emoji).font(.system(size: 40))
                                .padding(10)
                                .background(multipeer.myEmoji == emoji ? Color.white.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                    }
                }.padding(.horizontal)
            }
            
            HStack(spacing: 15) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        multipeer.myColor = color
                        multipeer.broadcastPeerInfo()
                    } label: {
                        Circle().fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: multipeer.myColor == color ? 3 : 0)
                            )
                    }
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(hex: "1A1A1A"))
        .ignoresSafeArea()
    }
}

struct AvatarCircle: View {
    var color: Color
    var size: CGFloat
    var emoji: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.4), radius: 8)
            Text(emoji)
                .font(.system(size: size * 0.5))
        }
    }
}

struct ReactionButton: View {
    var emoji: String
    @State private var pressed = false
    
    var body: some View {
        Button {
            // Trigger reaction
        } label: {
            Text(emoji)
                .font(.system(size: 24))
        }
        .scaleEffect(pressed ? 0.8 : 1.0)
        .animation(.spring(response: 0.2), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}
