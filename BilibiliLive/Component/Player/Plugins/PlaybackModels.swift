//
//  PlaybackModels.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import Foundation

// MARK: - 播放会话

struct PlaybackSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval
    var watchedDuration: TimeInterval
    var bufferingTime: TimeInterval
    var qualityChanges: Int
    var seekCount: Int
    var successful: Bool
    var averageQuality: MediaQualityEnum
    var networkType: NetworkType
    let deviceInfo: String

    var completionRate: Double {
        guard totalDuration > 0 else { return 0 }
        return watchedDuration / totalDuration
    }

    var bufferingRatio: Double {
        guard watchedDuration > 0 else { return 0 }
        return bufferingTime / watchedDuration
    }

    var isOngoing: Bool {
        return endTime == nil
    }
}

// MARK: - 播放事件

struct PlaybackEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: PlaybackEventType
    let position: TimeInterval
    let sessionId: UUID?
}

enum PlaybackEventType: Codable {
    case playbackStarted
    case playbackPaused
    case playbackResumed
    case playbackStopped
    case playbackError(Error)
    case seekPerformed(from: TimeInterval, to: TimeInterval)
    case qualityChanged(from: MediaQualityEnum, to: MediaQualityEnum)
    case bufferingStarted
    case bufferingEnded

    var description: String {
        switch self {
        case .playbackStarted:
            return "播放开始"
        case .playbackPaused:
            return "播放暂停"
        case .playbackResumed:
            return "播放恢复"
        case .playbackStopped:
            return "播放停止"
        case let .playbackError(error):
            return "播放错误: \\(error.localizedDescription)"
        case let .seekPerformed(from, to):
            return "跳转: \\(Int(from))s → \\(Int(to))s"
        case let .qualityChanged(from, to):
            return "画质变化: \\(from) → \\(to)"
        case .bufferingStarted:
            return "缓冲开始"
        case .bufferingEnded:
            return "缓冲结束"
        }
    }

    // Codable support for enum with associated values
    enum CodingKeys: String, CodingKey {
        case type, errorMessage, fromTime, toTime, fromQuality, toQuality
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .playbackStarted:
            try container.encode("playbackStarted", forKey: .type)
        case .playbackPaused:
            try container.encode("playbackPaused", forKey: .type)
        case .playbackResumed:
            try container.encode("playbackResumed", forKey: .type)
        case .playbackStopped:
            try container.encode("playbackStopped", forKey: .type)
        case let .playbackError(error):
            try container.encode("playbackError", forKey: .type)
            try container.encode(error.localizedDescription, forKey: .errorMessage)
        case let .seekPerformed(from, to):
            try container.encode("seekPerformed", forKey: .type)
            try container.encode(from, forKey: .fromTime)
            try container.encode(to, forKey: .toTime)
        case let .qualityChanged(from, to):
            try container.encode("qualityChanged", forKey: .type)
            try container.encode(from, forKey: .fromQuality)
            try container.encode(to, forKey: .toQuality)
        case .bufferingStarted:
            try container.encode("bufferingStarted", forKey: .type)
        case .bufferingEnded:
            try container.encode("bufferingEnded", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "playbackStarted":
            self = .playbackStarted
        case "playbackPaused":
            self = .playbackPaused
        case "playbackResumed":
            self = .playbackResumed
        case "playbackStopped":
            self = .playbackStopped
        case "playbackError":
            let message = try container.decode(String.self, forKey: .errorMessage)
            self = .playbackError(NSError(domain: "PlaybackError", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
        case "seekPerformed":
            let from = try container.decode(TimeInterval.self, forKey: .fromTime)
            let to = try container.decode(TimeInterval.self, forKey: .toTime)
            self = .seekPerformed(from: from, to: to)
        case "qualityChanged":
            let from = try container.decode(MediaQualityEnum.self, forKey: .fromQuality)
            let to = try container.decode(MediaQualityEnum.self, forKey: .toQuality)
            self = .qualityChanged(from: from, to: to)
        case "bufferingStarted":
            self = .bufferingStarted
        case "bufferingEnded":
            self = .bufferingEnded
        default:
            self = .playbackStarted
        }
    }
}

// MARK: - 质量变化事件

struct QualityChangeEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let fromQuality: MediaQualityEnum
    let newQuality: MediaQualityEnum
    let position: TimeInterval
    var duration: TimeInterval
    let sessionId: UUID?
}

// MARK: - 缓冲事件

struct BufferingEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let position: TimeInterval
    let sessionId: UUID?
}

// MARK: - 播放统计

struct PlaybackSessionStats {
    let totalSessions: Int
    let successfulSessions: Int
    let totalPlayTime: TimeInterval
    let averagePlayTime: TimeInterval
    let sessionsToday: Int
    let totalBufferingTime: TimeInterval
    let averageSeekCount: Int
    let qualityDistribution: [MediaQualityEnum: Double]
    let recentSessions: [PlaybackSession]

    var successRate: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(successfulSessions) / Double(totalSessions)
    }

    var averageBufferingRatio: Double {
        guard totalPlayTime > 0 else { return 0 }
        return totalBufferingTime / totalPlayTime
    }
}
