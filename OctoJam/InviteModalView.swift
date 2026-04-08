//
//  InviteModalView.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import SwiftUI

struct InviteModalView: View {
    let onDismiss: () -> Void
    let onInvite: () -> Void
    
    var body: some View {
        ZStack {
            // Background dim
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack {
                HStack {
                    Text("Invite a Friend")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: onInvite) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(width: 50, height: 50)
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                                .foregroundStyle(Color(hex: "E0B0FF"))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                Spacer()
                
                // Modal Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Invite a Friend")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Invite a friend to listen to music together and create a powerful experience.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(4)
                    
                    Button(action: onInvite) {
                        Text("Invite a Friend")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color(hex: "1F1F24"))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
            }
        }
    }
}
