//
//  ContentView.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var multipeer = MultipeerManager()
    @State private var audio = AudioSyncManager()
    @State private var role: AppRole? = nil
    @State private var roomName: String = ""
    @State private var showRoomNameModal = false

    enum AppRole { case host, client }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let role = role {
                    if role == .host {
                        HostView(multipeer: multipeer, audio: audio, roomName: roomName) {
                            withAnimation(.spring(response: 0.4)) {
                                self.role = nil
                                self.roomName = ""
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else {
                        ClientView(multipeer: multipeer, audio: audio) {
                            withAnimation(.spring(response: 0.4)) {
                                self.role = nil
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                } else {
                    RoleSelectionView { selected in
                        if selected == .host {
                            showRoomNameModal = true
                        } else {
                            withAnimation(.spring(response: 0.4)) {
                                role = selected
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRoomNameModal) {
            RoomNameModal(
                roomName: $roomName,
                onConfirm: {
                    showRoomNameModal = false
                    withAnimation(.spring(response: 0.4)) {
                        role = .host
                    }
                },
                onDiscard: {
                    showRoomNameModal = false
                    roomName = ""
                }
            )
            .presentationDetents([.height(280)])
            .presentationBackground(Color(hex: "1A1A1E"))
        }
    }
}

// MARK: - Room Name Modal

struct RoomNameModal: View {
    @Binding var roomName: String
    let onConfirm: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name your Room")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Give a name to your room and start vibing with your friends")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))

            TextField("Room name...", text: $roomName)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            HStack(spacing: 14) {
                Button(action: onDiscard) {
                    Text("Discard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onConfirm) {
                    Text("Confirm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(roomName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(roomName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
            }
            .padding(.top, 4)
        }
        .padding(24)
    }
}

#Preview {
    ContentView()
}
