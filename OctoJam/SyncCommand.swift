//
//  SyncCommand.swift
//  AudioSync
//
//  Created by Antonio Bonetti on 02/04/2026.
//

import Foundation

struct SyncCommand: Codable, Sendable {
    enum CommandType: String, Codable, Sendable {
        case play
        case pause
        case stop
        case setVolume
        case seekTo
        case syncClock
        case syncClockResponse
        case loadURL
        case requestState
        case currentState
        case prepareToPlay
        case readyToPlay
        case updatePeerInfo
    }

    var type: CommandType
    var peerName: String?
    var peerEmoji: String?
    var peerColor: String?
    var roomName: String?
    var hostTimestamp: Double?
    var scheduleAt: Double?
    var volume: Float?
    var seekSeconds: Double?
    var audioURL: String?
    var isPlaying: Bool?

    var clientT1: Double?
    var hostT2: Double?
    var hostT3: Double?
}
