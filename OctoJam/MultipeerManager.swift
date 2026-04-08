//
//  MultipeerManager.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import MultipeerConnectivity
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Observation

typealias MCInvitationHandler = @Sendable (Bool, MCSession?) -> Void

@Observable
@MainActor
class MultipeerManager: NSObject {
    static let serviceType = "audiosync-v1"

    var connectedPeers: [MCPeerID] = []
    var isHost: Bool = false
    var incomingPeer: MCPeerID? = nil

    private(set) var isWaitingForPeersToPlay: Bool = false
    private var peersReady: Set<MCPeerID> = []
    
    // Peer Avatar Info: [ID: (Emoji, HexColor)]
    var peerAvatars: [MCPeerID: (emoji: String, color: String)] = [:]
    var myEmoji: String = ["🧑🏻‍🦱", "👩🏽‍🦰", "🧔🏻‍♂️", "👱🏻‍♀️", "👽", "🐙"].randomElement()!
    var myColor: String = ["A855F7", "00B4D8", "EC4899", "7B2FBE"].randomElement()!
    var hostRoomName: String = ""

    @ObservationIgnored var onAllPeersReadyToPlay: (() -> Void)?

    @ObservationIgnored var onCommandReceived: ((SyncCommand, MCPeerID) -> Void)?

    let myPeerID: MCPeerID
    private(set) var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitationHandler: MCInvitationHandler?

    private(set) var clockOffset: Double = 0
    private(set) var lastRTT: Double = 0
    private var clockSamples: [Double] = []

    override init() {
        #if canImport(UIKit)
        let deviceName = UIKit.UIDevice.current.name
        #elseif canImport(AppKit)
        let deviceName = Host.current().localizedName ?? "Mac"
        #else
        let deviceName = "Unknown Device"
        #endif
        myPeerID = MCPeerID(displayName: deviceName)
        super.init()
        resetSession()
    }

    private func resetSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    func startHosting() {
        isHost = true
        resetSession()
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["role": "host"], serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func acceptInvitation() {
        pendingInvitationHandler?(true, session)
        pendingInvitationHandler = nil
        incomingPeer = nil
    }

    func declineInvitation() {
        pendingInvitationHandler?(false, nil)
        pendingInvitationHandler = nil
        incomingPeer = nil
    }

    func startBrowsing() {
        isHost = false
        resetSession()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        // Start periodic sync if not host
        startPeriodicSync()
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        advertiser = nil
        browser = nil
        syncTimer?.invalidate()
        syncTimer = nil
        
        connectedPeers = []
        isHost = false
        incomingPeer = nil
        clockOffset = 0
        clockSamples = []
    }
    
    private var syncTimer: Timer?
    private func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestClockSync()
            }
        }
    }

    func sendCommand(_ command: SyncCommand, toPeer peerID: MCPeerID? = nil) {
        let peers = peerID != nil ? [peerID!] : session.connectedPeers
        guard !peers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(command)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("[Multipeer] Command send error (\(command.type)): \(error)")
        }
    }

    func requestClockSync() {
        guard !isHost && !session.connectedPeers.isEmpty else { return }
        let t1 = CACurrentMediaTime()
        sendCommand(SyncCommand(type: .syncClock, clientT1: t1))
    }

    func broadcastClockSync() {
        guard isHost else { return }
        // Simple host-initiated sync (fallback)
        sendCommand(SyncCommand(type: .syncClock, hostTimestamp: CACurrentMediaTime()))
    }
    
    func broadcastPeerInfo() {
        var cmd = SyncCommand(type: .updatePeerInfo)
        cmd.peerEmoji = myEmoji
        cmd.peerColor = myColor
        if isHost && !hostRoomName.isEmpty {
            cmd.roomName = hostRoomName
        }
        sendCommand(cmd)
    }

    func broadcastURL(_ url: URL) {
        guard isHost else { return }
        sendCommand(SyncCommand(type: .loadURL, audioURL: url.absoluteString))
    }

    private func updateClockOffset(hostT2: Double, hostT3: Double, clientT1: Double, clientT4: Double) {
        // NTP Formula
        // RTT = (T4 - T1) - (T3 - T2)
        // Offset = ((T2 - T1) + (T3 - T4)) / 2
        
        let rtt = (clientT4 - clientT1) - (hostT3 - hostT2)
        
        // Quality Filter: Ignore invalid RTTs (negative or too high)
        // A negative RTT means clocks are drifting or packet order was swapped.
        // A very high RTT (> 2s) means the network context is too noisy for sync.
        guard rtt > 0 && rtt < 2.0 else {
            print("[Sync] DISCARDED invalid sample! RTT: \(String(format: "%.2f", rtt*1000))ms")
            return
        }
        
        lastRTT = rtt
        let offsetSample = ((hostT2 - clientT1) + (hostT3 - clientT4)) / 2
        
        clockSamples.append(offsetSample)
        if clockSamples.count > 10 { clockSamples.removeFirst() }
        clockOffset = clockSamples.reduce(0, +) / Double(clockSamples.count)
        
        print("[Sync] RTT: \(String(format: "%.2f", rtt*1000))ms | Offset: \(String(format: "%.4f", clockOffset))s")
    }
    
    private func updateClockOffsetLegacy(hostTime: Double, receivedAt: Double) {
        let sample = hostTime - receivedAt
        clockSamples.append(sample)
        if clockSamples.count > 10 { clockSamples.removeFirst() }
        clockOffset = clockSamples.reduce(0, +) / Double(clockSamples.count)
    }
}

extension MultipeerManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            if state == .connected {
                if self.isHost {
                    try? await Task.sleep(for: .seconds(0.5))
                    self.broadcastClockSync()
                    self.broadcastPeerInfo()
                } else {
                    try? await Task.sleep(for: .seconds(0.5))
                    self.sendCommand(SyncCommand(type: .requestState))
                    self.broadcastPeerInfo()
                }
            } else if state == .notConnected {
                self.peerAvatars.removeValue(forKey: peerID)
                if self.isHost && self.incomingPeer == peerID {
                    self.incomingPeer = nil
                    self.pendingInvitationHandler = nil
                }
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let receiveTime = CACurrentMediaTime()
        Task { @MainActor in
            guard let cmd = try? JSONDecoder().decode(SyncCommand.self, from: data) else { return }
            
            switch cmd.type {
            case .syncClock:
                if self.isHost {
                    // Host receives sync request from client, responds with timing data
                    var response = SyncCommand(type: .syncClockResponse)
                    response.clientT1 = cmd.clientT1
                    response.hostT2 = receiveTime // Arrival at host
                    response.hostT3 = CACurrentMediaTime() // Departure from host
                    
                    // TARGETED SEND: Respond only to the peer that requested the sync!
                    self.sendCommand(response, toPeer: peerID)
                } else if let ht = cmd.hostTimestamp {
                    // Legacy host-initiated sync
                    self.updateClockOffsetLegacy(hostTime: ht, receivedAt: receiveTime)
                }
                return
                
            case .syncClockResponse:
                if !self.isHost, let t1 = cmd.clientT1, let t2 = cmd.hostT2, let t3 = cmd.hostT3 {
                    // Client receives response from host, calculates RTT/Offset
                    self.updateClockOffset(hostT2: t2, hostT3: t3, clientT1: t1, clientT4: receiveTime)
                }
                return
                
            case .readyToPlay:
                if self.isHost && self.isWaitingForPeersToPlay {
                    self.peersReady.insert(peerID)
                    print("[Handshake] Peer ready: \(peerID.displayName) (\(self.peersReady.count)/\(self.connectedPeers.count))")
                    if self.peersReady.count >= self.connectedPeers.count {
                        self.isWaitingForPeersToPlay = false
                        self.onAllPeersReadyToPlay?()
                    }
                }
                return
                
            case .updatePeerInfo:
                if let em = cmd.peerEmoji, let co = cmd.peerColor {
                    self.peerAvatars[peerID] = (em, co)
                }
                if let name = cmd.roomName, !name.isEmpty {
                    self.hostRoomName = name
                }
                return
                
            default:
                self.onCommandReceived?(cmd, peerID)
            }
        }
    }

    func initiatePlayHandshake() {
        peersReady.removeAll()

        // If no peers connected, play immediately
        if connectedPeers.isEmpty {
            onAllPeersReadyToPlay?()
            return
        }

        isWaitingForPeersToPlay = true
        sendCommand(SyncCommand(type: .prepareToPlay))

        // Timeout: 5 seconds. If some peers fail to respond, play anyway.
        Task {
            try? await Task.sleep(for: .seconds(5))
            if self.isWaitingForPeersToPlay {
                self.isWaitingForPeersToPlay = false
                self.onAllPeersReadyToPlay?()
            }
        }
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            self.incomingPeer = peerID
            self.pendingInvitationHandler = invitationHandler
        }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
