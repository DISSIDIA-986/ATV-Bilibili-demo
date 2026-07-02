//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit

class BVideoPlayPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let playData: PlayerDetailData

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
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

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, isBangumi: playData.isBangumi)
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
