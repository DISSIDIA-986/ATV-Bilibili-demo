//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit
import UIKit

class BVideoPlayPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let playData: PlayerDetailData

    // 历史进度上报：此前只在 playerDidDismiss 上报一次且 fire-and-forget，Apple TV 用户
    // 常直接后台/杀进程而非优雅退出播放器，弱网下单次上报还会静默失败，导致手机端看不到
    // ATV 观看记录。改为播放中周期性心跳 + 关键生命周期节点各 flush 一次。
    private var historyReportObserver: Any?
    private weak var reportPlayer: AVPlayer?
    private var lastReportedTime = -1

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    deinit {
        stopHistoryReporting()
        NotificationCenter.default.removeObserver(self)
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        playerVC.player = nil
        playerVC.appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
        Task {
            try? await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
        }
    }

    func playerWillStart(player: AVPlayer) {
        if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    /// Current playback position in whole seconds, if meaningful. Used to
    /// preserve position across a quality reload.
    var currentPlaybackTime: Int? {
        guard let t = playerVC?.player?.currentTime().seconds, t.isFinite, t > 0 else { return nil }
        return Int(t)
    }

    /// Host of the CDN node currently serving video, for stall blacklisting.
    var currentVideoHost: String? { playerDelegate?.primaryVideoHost }

    /// Live peak-bitrate cap on the CURRENT item. Proactive low-bandwidth recovery
    /// uses this to make AVPlayer ride a lower DASH rep with no reload.
    func setPeakBitRate(_ bps: Double) {
        playerVC?.player?.currentItem?.preferredPeakBitRate = bps
    }

    // 播放器可用即开始周期心跳；换集/切码率会触发 playerDidCleanUp(旧 player) 再
    // playerDidChange(新 player)，observer 随之重建，所以这里统一在 change 里启动。
    func playerDidChange(player: AVPlayer) {
        startHistoryReporting(player: player)
    }

    func playerDidPause(player: AVPlayer) {
        flushHistory(player: player, reason: "pause")
    }

    func playerDidEnd(player: AVPlayer) {
        flushHistory(player: player, reason: "end")
    }

    // 连续播放切集 / 切清晰度：旧 player 清理前 flush 最终进度，避免上一集漏报。
    // 关键：切集时新插件 playerDidLoad 会把 playerVC.player 置 nil，KVO 的 cleanup 会
    // 发给当前 active plugins（可能是新插件），若不校验就会用新集 playData 上报旧 player
    // 时间，直接污染跨端历史。只处理属于自己的 player。
    func playerDidCleanUp(player: AVPlayer) {
        guard player === reportPlayer else { return }
        flushHistory(player: player, reason: "cleanup")
        stopHistoryReporting()
        lastReportedTime = -1
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        flushHistory(player: playerVC.player, reason: "dismiss")
        stopHistoryReporting()
    }

    @objc private func appDidEnterBackground() {
        // Home / 上划杀进程前的最后一次机会补报，覆盖用户不优雅退出播放器的场景。
        // 只用自己的 reportPlayer，避免回退到 playerVC.player 时误报别的插件的 player。
        flushHistory(player: reportPlayer, reason: "background")
    }

    private func startHistoryReporting(player: AVPlayer) {
        stopHistoryReporting()
        reportPlayer = player
        // 每 15s 上报一次当前进度（对齐 B站官方客户端的周期心跳），保证跨端可靠同步。
        historyReportObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 15, preferredTimescale: 1), queue: .main
        ) { [weak self] _ in
            self?.flushHistory(player: self?.reportPlayer, reason: "heartbeat")
        }
    }

    private func stopHistoryReporting() {
        if let historyReportObserver, let reportPlayer {
            reportPlayer.removeTimeObserver(historyReportObserver)
        }
        historyReportObserver = nil
        reportPlayer = nil
    }

    private func flushHistory(player: AVPlayer?, reason: String) {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite, seconds > 0 else { return }
        let t = Int(seconds)
        if t == lastReportedTime { return } // 同一秒不重复上报
        lastReportedTime = t
        Logger.debug("[History] flush(\(reason)) aid=\(playData.aid) t=\(t)")
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: t, epid: playData.epid, seasonId: playData.seasonId, isBangumi: playData.isBangumi)
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async throws {
        guard let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play) else {
            throw "Invalid play URL"
        }
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)
        if Settings.contentMatchOnlyInHDR {
            if playerDelegate?.isHDR != true {
                playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
            }
        }
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        await prepare(toPlay: asset)
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)
        // Deeper forward buffer so transient CDN throughput dips don't drain the
        // buffer and stall playback (confirmed 卡顿 root cause: buffer underrun).
        playerItem.preferredForwardBufferDuration = 20
        // When weak-network recovery has capped quality, also pin the peak
        // bitrate so AVPlayer actually rides a low-bitrate variant (a 1080p qn
        // can still expose a high-bitrate rep that an already-slow node can't feed).
        // A confirmed low-bandwidth path pins even lower to reach a sub-1080p rep.
        if Settings.runtimeLowBandwidth {
            playerItem.preferredPeakBitRate = 1_500_000
        } else if Settings.runtimeQualityCap != nil {
            playerItem.preferredPeakBitRate = 4_000_000
        }
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        playerVC?.player = player
    }
}
