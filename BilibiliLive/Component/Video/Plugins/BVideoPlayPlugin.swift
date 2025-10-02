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
    private var adaptationSeekTime: CMTime?

    init(detailData: PlayerDetailData) {
        playData = detailData
        super.init()
        setupAdaptationListener()
    }

    private func setupAdaptationListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQualityAdaptationRequested(_:)),
            name: .init("QualityAdaptationRequested"),
            object: nil
        )
    }

    @objc private func handleQualityAdaptationRequested(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let currentTime = userInfo["currentTime"] as? CMTime
        {
            adaptationSeekTime = currentTime
        }
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
        // 优先使用画质自适应的seek时间
        if let seekTime = adaptationSeekTime {
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
            adaptationSeekTime = nil // 清除已使用的seek时间
            Logger.info("画质切换后恢复播放位置: \(seekTime.seconds)秒")
        } else if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async throws {
        Logger.info("开始加载视频资源,aid: \(playData.aid), cid: \(playData.cid)")

        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]

        do {
            let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerDelegate = BilibiliVideoResourceLoaderDelegate()

            #if os(tvOS)
                Logger.info("tvOS 平台:字幕功能已禁用")
            #endif

            playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)

            if Settings.contentMatchOnlyInHDR {
                if playerDelegate?.isHDR != true {
                    playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
                }
            }

            asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))

            Logger.info("正在检查资源是否可播放...")
            let playable = try await asset.load(.isPlayable)

            if !playable {
                Logger.error("资源不可播放")
                throw "加载资源失败"
            }

            Logger.info("资源加载成功,准备播放")
            await prepare(toPlay: asset)
        } catch {
            Logger.error("视频播放失败: \(error)")
            throw error
        }
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        playerVC?.player = player
    }
}
